---@param bufnr number
---@param sessionid number
---@return nil
local buf_set_session = function (bufnr, sessionid)
  vim.api.nvim_buf_set_var(bufnr, "facilellm-sessionid", sessionid)
end

---@param bufnr number
---@return number? sessionid
local buf_get_session = function (bufnr)
  local flag, sessionid = pcall(vim.api.nvim_buf_get_var, bufnr, "facilellm-sessionid")
  if flag then
    return sessionid
  end
end

---@param winid number
---@return number? sessionid
local win_get_session = function (winid)
  local bufnr = vim.api.nvim_win_get_buf(winid)
  return buf_get_session(bufnr)
end


return {
  buf_set_session = buf_set_session,
  buf_get_session = buf_get_session,
  win_get_session = win_get_session,
}
