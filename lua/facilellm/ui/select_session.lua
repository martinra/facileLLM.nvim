---@type nil | number
local recent_sessionid = nil


---@param sessionid number
---@return nil
local delete = function (sessionid)
  if recent_sessionid == sessionid then
    recent_sessionid = nil
  end
end

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

return {
  delete = delete,
  touch = touch,
  get_most_recent = get_most_recent,
}
