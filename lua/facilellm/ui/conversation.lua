local config = require("facilellm.config")
local ui_common = require("facilellm.ui.common")
local util = require("facilellm.util")


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
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  ui_common.buf_set_session(bufnr, sessionid)
  ui_common.buf_set_is_conversation(bufnr)

  return bufnr
end

---@param sessionid FacileLLM.SessionId
---@param bufnr BufNr
---@param direction string Will be parsed by util.win_vsplit_modifier.
---@return WinId
local create_window = function (sessionid, bufnr, direction)
  direction = direction or "right"
  local split_modifier = util.win_vsplit_modifier(
                           config.opts.layout.relative, direction)
  vim.cmd(string.format("noau %s vsplit", split_modifier))
  local winid = vim.api.nvim_get_current_win()

  vim.wo.foldenable = true
  vim.wo.foldmethod = "manual"

  vim.api.nvim_win_set_buf(winid, bufnr)

  return winid
end

---@param bufnr BufNr
---@param winid WinId
---@return nil
local follow = function (bufnr, winid)
  local nlines = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_win_set_cursor(winid, {nlines, 0})
end

---@param bufnr BufNr
---@return nil
local on_complete_query = function (bufnr)
end


return {
  create_buffer = create_buffer,
  create_window = create_window,
  follow = follow,
  on_complete_query = on_complete_query,
}
