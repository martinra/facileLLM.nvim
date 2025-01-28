local ui_common = require("facilellm.ui.common")


---@type FacileLLM.SessionId?
local recent_sessionid = nil


---@param sessionid FacileLLM.SessionId
---@return nil
local delete = function (sessionid)
  if recent_sessionid == sessionid then
    recent_sessionid = nil
  end
end

---@param sessionid FacileLLM.SessionId
---@return nil
local touch = function (sessionid)
  recent_sessionid = sessionid
end

---@param winid WinId
---@return nil
local touch_window = function (winid)
  local sessionid = ui_common.win_get_session(winid)
  if sessionid then
    touch(sessionid)
  end
end

-- By most recent we mean the session that most recently was interacted with
-- as indicated by the touch command.
---@return FacileLLM.SessionId?
local get_most_recent = function ()
  return recent_sessionid
end


return {
  delete = delete,
  touch = touch,
  touch_window = touch_window,
  get_most_recent = get_most_recent,
}
