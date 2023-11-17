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
local get_conversation_buffer = function (sessionid)
  return session_uis[sessionid].conv_bufnr
end

---@param sessionid FacileLLM.SessionId
---@return BufNr
local get_input_buffer = function (sessionid)
  return session_uis[sessionid].input_bufnr
end

---@param sessionid FacileLLM.SessionId
---@return WinId?
local get_some_conversation_window = function (sessionid)
  local bufnr = get_conversation_buffer(sessionid)
  for _,winid in pairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(winid) == bufnr then
      return winid
    end
  end
end

---@param sessionid FacileLLM.SessionId
---@return WinId?
local get_some_input_window = function (sessionid)
  local bufnr = get_input_buffer(sessionid)
  for _,winid in pairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(winid) == bufnr then
      return winid
    end
  end
end

---@param sessionid FacileLLM.SessionId
---@return FacileLLM.RenderState
local get_render_state = function (sessionid)
  return session_uis[sessionid].render_state
end

---@param name string
---@return string
local conversation_buffer_name = function (name)
  return "facileLLM " .. name
end

---@param name string
---@return string
local input_buffer_name = function (name)
  return "facileLLM Input " .. name
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
---@param instruction ("delete"| "preserve"| "combine")
---@param context ("delete"| "preserve"| "combine")
---@return nil
local clear_conversation = function (sessionid, instruction, context)
  if not session.clear_conversation(sessionid, instruction, context) then
    return
  end
  local conv = session.get_conversation(sessionid)
  local conv_bufnr = get_conversation_buffer(sessionid)
  local render_state = get_render_state(sessionid)
  ui_render.clear_conversation(conv_bufnr, render_state)
  ui_render.render_conversation(conv, conv_bufnr, render_state)
end

---@param sessionid FacileLLM.SessionId
---@return nil
local render_conversation = function (sessionid)
  local conv = session.get_conversation(sessionid)
  local bufnr = get_conversation_buffer(sessionid)
  local render_state = get_render_state(sessionid)
  ui_render.render_conversation(conv, bufnr, render_state)
  for _,winid in pairs(vim.api.nvim_list_wins()) do
    if does_follow_conversation(sessionid, winid) then
      ui_conversation.follow(bufnr, winid)
    end
  end
end

---@param sessionid FacileLLM.SessionId
---@param name string
---@return nil
local set_name = function (sessionid, name)
  name = session.set_name(sessionid, name)
  vim.api.nvim_buf_set_name(get_conversation_buffer(sessionid), conversation_buffer_name(name))
  vim.api.nvim_buf_set_name(get_input_buffer(sessionid), input_buffer_name(name))
end

---@param sessionid FacileLLM.SessionId
---@return nil
local delete = function (sessionid)
  ui_select.delete(sessionid)
  for _,winid in pairs(vim.api.nvim_list_wins()) do
    if ui_common.win_get_session(winid) == sessionid then
      vim.api.nvim_win_close(winid, true)
    end
  end
  vim.api.nvim_buf_delete(session_uis[sessionid].conv_bufnr, {force = true})
  vim.api.nvim_buf_delete(session_uis[sessionid].input_bufnr, {force = true})
  session.delete(sessionid)
end

---@param sessionid FacileLLM.SessionId
---@return nil
local rename = function (sessionid)
  local cur_name = session.get_name(sessionid)
  vim.ui.input({prompt = "Rename session " .. cur_name .. ": "},
    function (name)
      set_name(sessionid, name)
    end
  )
end

---@param sessionid FacileLLM.SessionId
---@return nil
local set_keymaps = function (sessionid)
  local ui_session = require("facilellm.ui.session")

  local conv_bufnr = get_conversation_buffer(sessionid)
  local input_bufnr = get_input_buffer(sessionid)

  -- mnemonic: delete interaction
  vim.api.nvim_buf_set_keymap(conv_bufnr, "n", "<C-d>i", "",
    { callback = function ()
        ui_session.clear_conversation(sessionid, "preserve", "preserve")
      end,
    })
  vim.api.nvim_buf_set_keymap(input_bufnr, "n", "<C-d>i", "",
    { callback = function ()
        ui_session.clear_conversation(sessionid, "preserve", "preserve")
      end,
    })

  -- mnemonic: delete conversation
  vim.api.nvim_buf_set_keymap(conv_bufnr, "n", "<C-d>c", "",
    { callback = function ()
        ui_session.clear_conversation(sessionid, "delete", "delete")
      end,
    })
  vim.api.nvim_buf_set_keymap(input_bufnr, "n", "<C-d>c", "",
    { callback = function ()
        ui_session.clear_conversation(sessionid, "delete", "delete")
      end,
    })

  -- mnemonic: delete session
  vim.api.nvim_buf_set_keymap(conv_bufnr, "n", "<C-d>s", "",
    { callback = function ()
        ui_session.delete(sessionid)
      end,
    })
  vim.api.nvim_buf_set_keymap(input_bufnr, "n", "<C-d>s", "",
    { callback = function ()
        ui_session.delete(sessionid)
      end,
    })

  vim.api.nvim_buf_set_keymap(conv_bufnr, "n", "<C-f>", "",
    { callback = function ()
        ui_session.fork(sessionid)
      end,
    })
  vim.api.nvim_buf_set_keymap(input_bufnr, "n", "<C-f>", "",
    { callback = function ()
        ui_session.fork(sessionid)
      end,
    })

  vim.api.nvim_buf_set_keymap(conv_bufnr, "n", "<C-r>", "",
    { callback = function ()
        ui_session.rename(sessionid)
      end,
    })
  vim.api.nvim_buf_set_keymap(input_bufnr, "n", "<C-r>", "",
    { callback = function ()
        ui_session.rename(sessionid)
      end,
    })

  ui_input.set_confirm_keymap(input_bufnr, "n", "<Enter>", function (lines)
    ui_session.add_input_message_and_query(sessionid, lines)
  end)
  ui_input.set_instruction_keymap(input_bufnr, "n", "<C-i>", function (lines)
    ui_session.add_message(sessionid, "Instruction", lines)
  end)
  ui_input.set_context_keymap(input_bufnr, "n", "<C-c>", function (lines)
    ui_session.add_message(sessionid, "Context", lines)
  end)
end

---@param sessionid FacileLLM.SessionId
---@param role FacileLLM.MsgRole
---@param lines string[]
---@return nil
local add_message = function (sessionid, role, lines)
  ui_select.touch(sessionid)
  session.add_message(sessionid, role, lines)
  vim.schedule(
    function ()
      render_conversation(sessionid)
    end)
end

---@param sessionid FacileLLM.SessionId
---@param response_callback function?(): nil
---@return nil
local on_complete_query = function (sessionid, response_callback)
  local bufnr = get_conversation_buffer(sessionid)
  ui_render.end_highlight_msg_receiving(bufnr, get_render_state(sessionid))
  ui_conversation.on_complete_query(bufnr)
  ui_input.on_complete_query(get_input_buffer(sessionid))

  local lines = session.get_last_llm_message(sessionid)
  if lines then
    vim.fn.setreg("a", lines, "l")
    if response_callback then
      response_callback(lines)
    end
  end
end

---@param sessionid FacileLLM.SessionId
---@param lines string[]
---@param response_callback function?(): nil
---@return nil
local add_input_message_and_query = function (sessionid, lines, response_callback)
  ui_select.touch(sessionid)
  session.add_message(sessionid, "Input", lines)
  ui_render.start_highlight_msg_receiving(
    session.get_conversation(sessionid), get_render_state(sessionid))
  session.query_model(sessionid, render_conversation,
    function (sessionid__loc)
      on_complete_query(sessionid__loc, response_callback)
    end)
  vim.schedule(
    function ()
      render_conversation(sessionid)
    end)
end

---@param model_config FacileLLM.Config.LLM
---@return FacileLLM.SessionId
local create = function (model_config)
  local sessionid = session.create(model_config)
  local name = session.get_name(sessionid)

  local sess = {
    conv_bufnr = ui_conversation.create_buffer(sessionid, conversation_buffer_name(name)),
    input_bufnr = ui_input.create_buffer(sessionid, input_buffer_name(name)),
    render_state = ui_render.create_state(),
    conversation_winids = {},
    follow_conversation_flags = {},
    input_winid = nil,
    input_conv_winid = nil,
  }
  session_uis[sessionid] = sess

  set_keymaps(sessionid)

  vim.api.nvim_create_autocmd("WinClosed", {
    buffer = sess.conv_bufnr,
    callback = function()
      local nmb_conv_wins = 0
      for _,winid in pairs(vim.api.nvim_list_wins()) do
        if ui_common.win_get_session(winid) == sessionid
          and ui_common.win_is_conversation(winid) then
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

  -- HACK: We delay rendering so that foldexpr is applied to the initial
  -- conversation in all cases Without this on 0.9.4 when creating from
  -- selection, they are seemingly never applied. This might not be neccessary
  -- once #18479 of github/neovim is applied (v0.10?).
  vim.schedule( function ()
    ui_render.render_conversation(session.get_conversation(sessionid),
      sess.conv_bufnr, sess.render_state)
  end)

  return sessionid
end

---@param sessionid FacileLLM.SessionId
---@return FacileLLM.SessionId
local fork = function (sessionid)
  local model_config = {
    name = session.fork_name_variant(session.get_name(sessionid)),
    initial_conversation =
      vim.tbl_deep_extend("force", {}, session.get_conversation(sessionid)),
  }
  model_config =
    vim.tbl_deep_extend("keep", model_config, session.get_model_config(sessionid))
  return create(model_config)
end

---@param sessionid FacileLLM.SessionId
---@return WinId
local create_conversation_win = function (sessionid)
  local bufnr = get_conversation_buffer(sessionid)
  local conv_winid = ui_conversation.create_window(bufnr, "right")
  follow_conversation(sessionid, conv_winid)
  return conv_winid
end

---@param sessionid FacileLLM.SessionId
---@param conv_winid WinId?
---@return WinId
local create_input_win = function (sessionid, conv_winid)
  local bufnr = get_input_buffer(sessionid)
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
  fork                               = fork,
  rename                             = rename,
  get_conversation_buffer            = get_conversation_buffer,
  get_input_buffer                   = get_input_buffer,
  get_some_conversation_window       = get_some_conversation_window,
  get_some_input_window              = get_some_input_window,
  follow_conversation                = follow_conversation,
  unfollow_conversation              = unfollow_conversation,
  set_current_win_conversation       = set_current_win_conversation,
  set_current_win_input              = set_current_win_input,
  set_current_win_conversation_input = set_current_win_conversation_input,
  clear_conversation                 = clear_conversation,
  render_conversation                = render_conversation,
  fold_context_messages              = fold_context_messages,
  win_fold_context_messages          = win_fold_context_messages,
  add_message                        = add_message,
  add_input_message_and_query        = add_input_message_and_query,
}
