local session = require("facilellm.session")
local ui_common = require("facilellm.ui.common")
local ui_conversation = require("facilellm.ui.conversation")
local ui_input = require("facilellm.ui.input")
local ui_render = require("facilellm.ui.render")
local ui_select = require("facilellm.ui.select_session")


---@class FacileLLM.SessionUI
---@field conv_bufnr BufNr
---@field input_bufnr BufNr
---@field render_state FacileLLM.RenderState
---@field follow_conversation_flags table<WinId,boolean>


---@type FacileLLM.SessionUI[]
local session_uis = {}


---@param sessionid FacileLLM.SessionId
---@return BufNr
local get_conv_bufnr = function (sessionid)
  return session_uis[sessionid].conv_bufnr
end

---@param sessionid FacileLLM.SessionId
---@return BufNr
local get_input_bufnr = function (sessionid)
  return session_uis[sessionid].input_bufnr
end

---@param sessionid FacileLLM.SessionId
---@return FacileLLM.RenderState
local get_render_state = function (sessionid)
  return session_uis[sessionid].render_state
end

---@param sessionid FacileLLM.SessionId
---@param winid WinId
---@return nil
local follow_conversation = function (sessionid, winid)
  session_uis[sessionid].follow_conversation_flags[winid] = true
end

---@param sessionid FacileLLM.SessionId
---@param winid WinId
---@return nil
local unfollow_conversation = function (sessionid, winid)
  session_uis[sessionid].follow_conversation_flags[winid] = false
end

---@param sessionid FacileLLM.SessionId
---@param winid WinId
---@return boolean
local does_follow_conversation = function (sessionid, winid)
  return session_uis[sessionid].follow_conversation_flags[winid]
end

---@param sessionid FacileLLM.SessionId
---@param preserve_context boolean
---@return nil
local clear_conversation = function (sessionid, preserve_context)
  if not session.clear_conversation(sessionid, preserve_context) then
    return
  end
  local conv = session.get_conversation(sessionid)
  local conv_bufnr = get_conv_bufnr(sessionid)
  local render_state = get_render_state(sessionid)
  ui_render.clear_conversation(conv_bufnr, render_state)
  ui_render.render_conversation(conv, conv_bufnr, render_state)
end

---@param sessionid FacileLLM.SessionId
---@return nil
local render_conversation = function (sessionid)
  local conv = session.get_conversation(sessionid)
  local bufnr = get_conv_bufnr(sessionid)
  local render_state = get_render_state(sessionid)
  ui_render.render_conversation(conv, bufnr, render_state)
  for _,winid in pairs(vim.api.nvim_list_wins()) do
    if does_follow_conversation(sessionid, winid) then
      ui_conversation.follow(bufnr, winid)
    end
  end
end

---@param model_config FacileLLM.LLMConfig
---@return FacileLLM.SessionId
local create = function (model_config)
  local sessionid = session.create(model_config)
  local name = session.get_name(sessionid)

  ---@return nil
  local on_complete_query = function ()
    local bufnr = get_conv_bufnr(sessionid)
    ui_render.end_highlight_msg_receiving(bufnr, get_render_state(sessionid))
    ui_conversation.on_complete_query(bufnr)
    ui_input.on_complete_query(get_input_bufnr(sessionid))
  end

  ---@param lines string[]
  ---@return nil
  local on_confirm_input = function (lines)
    ui_select.touch(sessionid)
    session.add_message(sessionid, "Input", lines)
    ui_render.start_highlight_msg_receiving(
      session.get_conversation(sessionid), get_render_state(sessionid))
    session.query_model(sessionid, render_conversation, on_complete_query)
    vim.schedule(
      function ()
        render_conversation(sessionid)
      end)
  end

  local sess = {
    conv_bufnr = ui_conversation.create_buffer(sessionid, "facileLLM " .. name),
    input_bufnr = ui_input.create_buffer(sessionid, "facileLLM Input " .. name, on_confirm_input),
    render_state = ui_render.create_state(),
    conversation_winids = {},
    follow_conversation_flags = {},
    input_winid = nil,
    input_conv_winid = nil,
  }
  session_uis[sessionid] = sess

  vim.api.nvim_buf_set_keymap(sess.conv_bufnr, "n", "<C-c>", "",
    { callback = function ()
        clear_conversation(sessionid, true)
      end,
    })
  vim.api.nvim_buf_set_keymap(sess.input_bufnr, "n", "<C-c>", "",
    { callback = function ()
        clear_conversation(sessionid, true)
      end,
    })
  vim.api.nvim_create_autocmd("WinClosed", {
    buffer = sess.conv_bufnr,
    callback = function()
      local nmb_conv_wins = 0
      for _,winid in pairs(vim.api.nvim_list_wins()) do
        if ui_common.win_get_session(winid) == sessionid then
          if nmb_conv_wins == 0 then
            nmb_conv_wins = 1
          else
            return
          end
        end
      end
      for _,winid in pairs(vim.api.nvim_list_wins()) do
        if ui_common.win_get_session(winid) == sessionid then
          vim.api.nvim_win_close(winid, true)
        end
      end
    end
  })

  ui_render.render_conversation(session.get_conversation(sessionid),
    sess.conv_bufnr, sess.render_state)

  return sessionid
end

---@param sessionid FacileLLM.SessionId
---@return nil
local delete = function (sessionid)
  vim.api.nvim_buf_delete(session_uis[sessionid].conv_bufnr, {force = true})
  vim.api.nvim_buf_delete(session_uis[sessionid].input_bufnr, {force = true})
  ui_select.delete(sessionid)
end

---@param sessionid FacileLLM.SessionId
---@return WinId?
local get_some_conversation_window = function (sessionid)
  local bufnr = get_conv_bufnr(sessionid)
  for _,winid in pairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(winid) == bufnr then
      return winid
    end
  end
end

---@param sessionid FacileLLM.SessionId
---@return WinId?
local get_some_input_window = function (sessionid)
  local bufnr = get_input_bufnr(sessionid)
  for _,winid in pairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(winid) == bufnr then
      return winid
    end
  end
end

---@param sessionid FacileLLM.SessionId
---@return WinId
local create_conversation_win = function (sessionid)
  local bufnr = get_conv_bufnr(sessionid)
  local conv_winid = ui_conversation.create_window(bufnr, "right")
  follow_conversation(sessionid, conv_winid)
  return conv_winid
end

---@param sessionid FacileLLM.SessionId
---@param conv_winid WinId?
---@return WinId
local create_input_win = function (sessionid, conv_winid)
  local bufnr = get_input_bufnr(sessionid)
  return ui_input.create_window(bufnr, conv_winid)
end

---@param sessionid FacileLLM.SessionId
---@return WinId
local set_current_win_conversation = function (sessionid)
  local conv_winid = get_some_conversation_window(sessionid)
  if conv_winid then
    vim.api.nvim_set_current_win(conv_winid)
    return conv_winid
  else
    return create_conversation_win(sessionid)
  end
end

---@param sessionid FacileLLM.SessionId
---@return WinId
local set_current_win_input = function (sessionid)
  local input_winid = get_some_input_window(sessionid)
  if input_winid then
    vim.api.nvim_set_current_win(input_winid)
    return input_winid
  else
    return create_input_win(sessionid)
  end
end

---@param sessionid FacileLLM.SessionId
---@return WinId
local set_current_win_conversation_input = function (sessionid)
  local input_winid = get_some_input_window(sessionid)
  if input_winid then
    vim.api.nvim_set_current_win(input_winid)
    return input_winid
  else
    local conv_winid = get_some_conversation_window(sessionid)
    if not conv_winid then
      conv_winid = create_conversation_win(sessionid)
    end
    return create_input_win(sessionid, conv_winid)
  end
end

---@param sessionid FacileLLM.SessionId
---@return nil
local fold_context_messages = function (sessionid)
  for _,winid in pairs(vim.api.nvim_list_wins()) do
    if ui_common.win_get_session(winid) == sessionid and ui_common.win_is_conversation(winid) then
      ui_conversation.fold_context_messages(winid)
    end
  end
end

---@param winid WinId
---@return nil
local win_fold_context_messages = function (winid)
  local sessionid = ui_common.win_get_session(winid)
  if sessionid and ui_common.win_is_conversation(winid) then
    ui_conversation.fold_context_messages(winid)
  end
end


return {
  create                             = create,
  delete                             = delete,
  get_conv_bufnr                     = get_conv_bufnr,
  get_input_bufnr                    = get_input_bufnr,
  follow_conversation                = follow_conversation,
  unfollow_conversation              = unfollow_conversation,
  set_current_win_conversation       = set_current_win_conversation,
  set_current_win_input              = set_current_win_input,
  set_current_win_conversation_input = set_current_win_conversation_input,
  clear_conversation                 = clear_conversation,
  render_conversation                = render_conversation,
  fold_context_messages              = fold_context_messages,
  win_fold_context_messages          = win_fold_context_messages,
}
