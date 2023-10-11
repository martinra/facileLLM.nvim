local ui_common = require("facilellm.ui.common")


---@param bufnr number
---@param on_confirm function(string[]): nil
---@return nil
local confirm_input = function (bufnr, on_confirm)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  vim.api.nvim_buf_set_lines(bufnr, 0,-1, true, {})
  if on_confirm then
    on_confirm(lines)
  end
end

---@param bufnr number
---@param on_confirm function(string[]): nil
---@return nil
local set_confirm_hook = function (bufnr, on_confirm)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<Enter>", "",
    { callback = function ()
        confirm_input(bufnr, on_confirm)
      end,
    })
end

---@param name string
---@param on_confirm function(string):nil
---@return number bufnr number of the newly created buffer
local create_buffer = function (name, on_confirm)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, name)

  vim.api.nvim_buf_set_option(bufnr, "buftype",    "nofile")
  vim.api.nvim_buf_set_option(bufnr, "swapfile",   false)
  vim.api.nvim_buf_set_option(bufnr, "buflisted",  false)
  vim.api.nvim_buf_set_option(bufnr, "bufhidden",  "hide")
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)

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


return {
  create_buffer = create_buffer,
  create_window = create_window,
}
