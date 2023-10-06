---@param winid number
---@param sessionid number
---@return nil
local set_session = function (winid, sessionid)
  vim.api.nvim_win_set_var(winid, "facilellm-sessionid", sessionid)
end

---@param winid number
---@return number sessionid
local get_session = function (winid)
  return vim.api.nvim_win_get_var(winid, "facilellm-sessionid")
end


return {
  set_session    = set_session,
  get_session    = get_session,
}
