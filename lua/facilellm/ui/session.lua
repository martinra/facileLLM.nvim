local llm = require("facilellm.llm")
local session = require("facilellm.session")
local ui_common = require("facilellm.ui.common")
local ui_conversation = require("facilellm.ui.conversation")
local ui_input = require("facilellm.ui.input")
local ui_render = require("facilellm.ui.render")


---@class SessionUI
---@field conv_bufnr number
---@field input_bufnr number
---@field render_state RenderState
---@field follow_conversation_flags table<number,boolean>


---@type SessionUI[]
local session_uis = {}
---@type nil | number
local recent_sessionid = nil


---@param sessionid number
---@return nil
local touch = function (sessionid)
  recent_sessionid = sessionid
end

-- By most recent we mean the session that most recently was interacted with
-- as indicated by the touch command.
---@return nil | number sessionid
local get_most_recent = function ()
  return recent_sessionid
end

---@return nil | number sessionid
local select = function ()
  if #session_uis == 0 then
    return nil
  else
    for id,_ in pairs(session_uis) do
      return id
    end
  end
end

---@param sessionid number
---@return number bufnr
local get_conv_bufnr = function (sessionid)
  return session_uis[sessionid].conv_bufnr
end

---@param sessionid number
---@return number bufnr
local get_input_bufnr = function (sessionid)
  return session_uis[sessionid].input_bufnr
end

---@param sessionid number
---@return RenderState
local get_render_state = function (sessionid)
  return session_uis[sessionid].render_state
end

---@param sessionid number
---@param winid number
---@return boolean
local does_follow_conversation = function (sessionid, winid)
  return session_uis[sessionid].follow_conversation_flags[winid]
end

---@param sessionid number
---@return nil
local render_conversation = function (sessionid)
  local conv = session.get_conversation(sessionid)
  local bufnr = get_conv_bufnr(sessionid)
  local render_state = get_render_state(sessionid)
  ui_render.conversation(conv, bufnr, render_state)
  for _,winid in pairs(vim.api.nvim_list_wins()) do
    if does_follow_conversation(sessionid, winid) then
      ui_conversation.follow(bufnr, winid)
    end
  end
end

---@param sessionid number
---@param name string
---@return nil
local create = function (sessionid, name)
  local on_confirm = function (lines)
      session.add_message(sessionid, "Input", lines)
      session.query_model(sessionid, render_conversation)
      vim.schedule(
        function ()
          render_conversation(sessionid)
        end)
    end

  local sess = {
    conv_bufnr = ui_conversation.create_buffer("facileLLM " .. name),
    input_bufnr = ui_input.create_buffer("facileLLM Input " .. name, on_confirm),
    render_state = { msg = 0, line = 0, char = 0,},
    conversation_winids = {},
    follow_conversation_flags = {},
    recent_winid = nil,
    input_winid = nil,
    input_conv_winid = nil,
  }
  session_uis[sessionid] = sess

  vim.api.nvim_buf_set_var(sess.conv_bufnr, "facilellm_sessionid", sessionid)
  vim.api.nvim_buf_set_var(sess.input_bufnr, "facilellm_sessionid", sessionid)

  vim.api.nvim_create_autocmd("WinClosed", {
    buffer = sess.conv_bufnr,
    callback = function()
      local nmb_conv_wins = 0
      for _,winid in pairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(winid) == sess.conv_bufnr then
          if nmb_conv_wins == 0 then
            nmb_conv_wins = 1
          else
            return
          end
        end
      end
      for _,winid in pairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(winid) == sess.input_bufnr then
          vim.api.nvim_win_close(winid, true)
        end
      end
    end
  })

  ui_render.conversation(session.get_conversation(sessionid),
    sess.conv_bufnr, sess.render_state)
end

---@param sessionid number
---@return nil
local delete = function (sessionid)
  vim.api.nvim_buf_delete(session_uis[sessionid].conv_bufnr, {force = true})
  vim.api.nvim_buf_delete(session_uis[sessionid].input_bufnr, {force = true})
  if recent_sessionid == sessionid then
    recent_sessionid = nil
  end
end


---@param winid number
---@return nil
local touch_conversation_window = function (winid)
  local sessionid = ui_common.get_session(winid)
  touch(sessionid)
  session_uis[sessionid].recent_winid = winid
end

---@param sessionid number
---@return nil | number winid
local get_some_conversation_window = function (sessionid)
  local bufnr = get_conv_bufnr(sessionid)
  for _,winid in pairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(winid) == bufnr then
      return winid
    end
  end
end

---@param sessionid number
---@return nil | number winid
local get_some_input_window = function (sessionid)
  local bufnr = get_input_bufnr(sessionid)
  for _,winid in pairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(winid) == bufnr then
      return winid
    end
  end
end

---@param sessionid number
---@return nil
local show = function (sessionid)
  sessionid = sessionid or get_most_recent() or select()
  if not sessionid then
    -- TOOD: allow for model selection
    local model = llm.default_model_config()
    sessionid = session.create(model)
    create(sessionid, session.get_name(sessionid))
    touch(sessionid)
  end

  local conv_winid = get_some_conversation_window(sessionid)
  if not conv_winid then
    local bufnr = get_conv_bufnr(sessionid)
    conv_winid = ui_conversation.create_window(sessionid, bufnr, "right")
  end
  local input_winid = get_some_input_window(sessionid)
  if not input_winid then
    local bufnr = get_input_bufnr(sessionid)
    ui_input.create_window(sessionid, bufnr, conv_winid)
  else
    vim.api.nvim_win_set_current_win(input_winid)
  end
end


return {
  create                                          = create,
  delete                                          = delete,
  touch                                           = touch,
  get_most_recent                                 = get_most_recent,
  select                                          = select,
  get_conv_bufnr                                  = get_conv_bufnr,
  get_input_bufnr                                 = get_input_bufnr,
  touch_conversation_window                       = touch_conversation_window,
  show                                            = show,
}
