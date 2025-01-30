local session = require("facilellm.session")
local ui_common = require("facilellm.ui.common")


---@type FacileLLM.SessionId?
local recent_sessionid = nil

---@type FacileLLM.SessionId?
local recent_completion_sessionid = nil


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

  local provider_config = session.get_provider_config(sessionid)
  if provider_config and provider_config.completion_tags then
    recent_completion_sessionid = sessionid
  end
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

---@return FacileLLM.SessionId?
local get_most_recent_completion = function ()
  return recent_completion_sessionid
end

return {
  delete = delete,
  touch = touch,
  touch_window = touch_window,
  get_most_recent = get_most_recent,
  get_most_recent_completion = get_most_recent_completion,
}
