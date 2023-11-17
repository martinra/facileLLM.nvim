local config = require("facilellm.config")
local session = require("facilellm.session")
local ui_common = require("facilellm.ui.common")


---@return number
local buf_get_namespace_confirm_feedback = function ()
  return vim.api.nvim_create_namespace("facilellm-confirm-feedback")
end

---@type number?
local signal_response_not_yet_complete_extmark = nil

---@param bufnr BufNr
---@return nil
local signal_response_not_yet_complete = function (bufnr)
  local nspc_confirm_feedback = buf_get_namespace_confirm_feedback()
  if signal_response_not_yet_complete_extmark == nil then
    signal_response_not_yet_complete_extmark =
      vim.api.nvim_buf_set_extmark(bufnr, nspc_confirm_feedback, 0, 0,
      {
        virt_text = { {"Response not yet completed", "WarningMsg"} },
        virt_text_pos = "eol"
      })
  end
end

---@param bufnr BufNr
---@return string[]
local clear_input_buffer = function (bufnr)
  signal_response_not_yet_complete_extmark = nil
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  vim.api.nvim_buf_set_lines(bufnr, 0,-1, true, {})
  return lines
end

---@param bufnr BufNr
---@param mode string
---@param lhs string
---@param on_confirm function(string[]): nil
---@return nil
local set_confirm_keymap = function (bufnr, mode, lhs, on_confirm)
  vim.api.nvim_buf_set_keymap(bufnr, mode, lhs, "",
    { callback = function ()
        local sessionid = ui_common.buf_get_session(bufnr)
        ---@cast sessionid FacileLLM.SessionId

        if session.is_conversation_locked(sessionid) and config.opts.feedback.conversation_lock.input_confirm then
          signal_response_not_yet_complete(bufnr)
          return
        end

        local lines = clear_input_buffer(bufnr)
        if #lines ~= 0 and on_confirm then
          on_confirm(lines)
        end
      end,
    })
end

---@param bufnr BufNr
---@param mode string
---@param lhs string
---@param on_instruction function(string[]): nil
---@return nil
local set_instruction_keymap = function (bufnr, mode, lhs, on_instruction)
  vim.api.nvim_buf_set_keymap(bufnr, mode, lhs, "",
    { callback = function ()
        local sessionid = ui_common.buf_get_session(bufnr)
        ---@cast sessionid FacileLLM.SessionId

        if session.is_conversation_locked(sessionid) and config.opts.feedback.conversation_lock.input_instruction then
          signal_response_not_yet_complete(bufnr)
          return
        end

        local lines = clear_input_buffer(bufnr)
        if #lines ~= 0 and on_instruction then
          on_instruction(lines)
        end
      end,
    })
end

---@param bufnr BufNr
---@param mode string
---@param lhs string
---@param on_context function(string[]): nil
---@return nil
local set_context_keymap = function (bufnr, mode, lhs, on_context)
  vim.api.nvim_buf_set_keymap(bufnr, mode, lhs, "",
    { callback = function ()
        local sessionid = ui_common.buf_get_session(bufnr)
        ---@cast sessionid FacileLLM.SessionId

        if session.is_conversation_locked(sessionid) and config.opts.feedback.conversation_lock.input_context then
          signal_response_not_yet_complete(bufnr)
          return
        end

        local lines = clear_input_buffer(bufnr)
        if #lines ~= 0 and on_context then
          on_context(lines)
        end
      end,
    })
end

---@param sessionid FacileLLM.SessionId
---@param name string
---@return BufNr
local create_buffer = function (sessionid, name)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, name)

  vim.api.nvim_buf_set_option(bufnr, "buftype",    "nofile")
  vim.api.nvim_buf_set_option(bufnr, "swapfile",   false)
  vim.api.nvim_buf_set_option(bufnr, "buflisted",  false)
  vim.api.nvim_buf_set_option(bufnr, "bufhidden",  "hide")
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)

  ui_common.buf_set_session(bufnr, sessionid)

  return bufnr
end

---@param bufnr BufNr
---@param conv_winid WinId?
---@return WinId
local create_window = function (bufnr, conv_winid)
  if conv_winid then
    vim.api.nvim_set_current_win(conv_winid)
  end

  local conv_height = vim.api.nvim_win_get_height(conv_winid)
  local input_height = math.ceil(config.opts.interface.input_relative_height*conv_height)

  vim.cmd("noau rightbelow split")
  local input_winid = vim.api.nvim_get_current_win()

  vim.api.nvim_win_set_height(input_winid, input_height)

  vim.api.nvim_win_set_buf(input_winid, bufnr)

  return input_winid
end

---@param bufnr BufNr
---@return nil
local on_complete_query = function (bufnr)
  local nspc_confirm_feedback = buf_get_namespace_confirm_feedback()
  vim.api.nvim_buf_clear_namespace(bufnr, nspc_confirm_feedback, 0, -1)
end


return {
  create_buffer = create_buffer,
  create_window = create_window,
  on_complete_query = on_complete_query,
  set_confirm_keymap = set_confirm_keymap,
  set_instruction_keymap = set_instruction_keymap,
  set_context_keymap = set_context_keymap,
}
