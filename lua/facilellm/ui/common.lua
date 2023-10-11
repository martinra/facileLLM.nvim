---@param bufnr number
---@param sessionid number
---@return nil
local buf_set_session = function (bufnr, sessionid)
  vim.api.nvim_buf_set_var(bufnr, "facilellm-sessionid", sessionid)
end

---@param bufnr number
---@return number sessionid
local buf_get_session = function (bufnr)
  return vim.api.nvim_buf_get_var(bufnr, "facilellm-sessionid")
end

---@param winid number
---@param sessionid number
---@return nil
local win_set_session = function (winid, sessionid)
  vim.api.nvim_win_set_var(winid, "facilellm-sessionid", sessionid)
end

---@param winid number
---@return number sessionid
local win_get_session = function (winid)
  return vim.api.nvim_win_get_var(winid, "facilellm-sessionid")
end


return {
  buf_set_session    = buf_set_session,
  buf_get_session    = buf_get_session,
  win_set_session    = win_set_session,
  win_get_session    = win_get_session,
}
