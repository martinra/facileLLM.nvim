local session = require("facilellm.session")
local ui_common = require("facilellm.ui.common")


---@param bufnr number
---@return number
local buf_get_namespace_confirm_feedback = function (bufnr)
  return vim.api.nvim_create_namespace("facilellm-confirm-feedback-" .. bufnr)
end

---@param bufnr number
---@param on_confirm function(string[]): nil
---@return nil
local set_confirm_hook = function (bufnr, on_confirm)
  local feedback_extmark = nil
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<Enter>", "",
    { callback = function ()
        local sessionid = ui_common.buf_get_session(bufnr)
        if session.is_conversation_locked(sessionid) then
          local nspc_confirm_feedback = buf_get_namespace_confirm_feedback(bufnr)
          if feedback_extmark == nil then
            feedback_extmark = vim.api.nvim_buf_set_extmark(bufnr, nspc_confirm_feedback, 0, 0,
              {
                virt_text = { {"Response not yet completed", "WarningMsg"} },
                virt_text_pos = "eol"
              })
          end
          return
        end

        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        vim.api.nvim_buf_set_lines(bufnr, 0,-1, true, {})
        if on_confirm then
          on_confirm(lines)
        end
      end,
    })
end

---@param sessionid number
---@param name string
---@param on_confirm function(string):nil
---@return number bufnr number of the newly created buffer
local create_buffer = function (sessionid, name, on_confirm)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, name)

  vim.api.nvim_buf_set_option(bufnr, "buftype",    "nofile")
  vim.api.nvim_buf_set_option(bufnr, "swapfile",   false)
  vim.api.nvim_buf_set_option(bufnr, "buflisted",  false)
  vim.api.nvim_buf_set_option(bufnr, "bufhidden",  "hide")
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)

  ui_common.buf_set_session(bufnr, sessionid)

  set_confirm_hook(bufnr, on_confirm)

  return bufnr
end

---@param sessionid number
---@param bufnr number
---@param conv_winid number
---@return number input_winid
local create_window = function (sessionid, bufnr, conv_winid)
  vim.api.nvim_set_current_win(conv_winid)
  vim.cmd("noau rightbelow split")
  local input_winid = vim.api.nvim_get_current_win()

  local conv_height = vim.api.nvim_win_get_height(conv_winid)
  vim.api.nvim_win_set_height(input_winid, math.ceil(0.2*conv_height))

  ui_common.win_set_session(input_winid, sessionid)
  vim.api.nvim_win_set_buf(input_winid, bufnr)

  return input_winid
end

---@param bufnr number
---@return nil
local on_complete_query = function (bufnr)
  local nspc_confirm_feedback = buf_get_namespace_confirm_feedback(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, nspc_confirm_feedback, 0, -1)
end


return {
  create_buffer = create_buffer,
  create_window = create_window,
  buf_get_namespace_confirm_feedback = buf_get_namespace_confirm_feedback,
  on_complete_query = on_complete_query,
}
