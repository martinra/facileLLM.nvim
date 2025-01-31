-- local config = require("facilellm.config")
local callback = require("facilellm.ui.blink_cmp.callback")
local session = require("facilellm.session")
local ui_session = require("facilellm.ui.session")
local ui_recent = require("facilellm.ui.recent_session")
local template = require("facilellm.session.template")


local src = {}

function src.new()
  return setmetatable({}, { __index = src })
end

---@return boolean
function src:enabled ()
  local sessionid = ui_recent.get_most_recent_completion()
  return sessionid ~= nil
end

---@param ctx any
---@param cb function
---@return nil
function src:get_completions (ctx, cb)
  local sessionid = ui_recent.get_most_recent()
  if sessionid == nil then
    cb()
    return
  end
  ---@cast sessionid FacileLLM.SessionId

  local completion_tags = session.get_provider_config(sessionid).completion_tags
  if completion_tags == nil then
    cb()
    return
  end
  ---@cast completion_tags FacileLLM.Config.CompletionTags
  local context_tags = completion_tags.context_tags

  ui_session.clear_interaction(sessionid)
  ui_session.append_conversation(sessionid,
    template.template_filetype_and_context(0, context_tags)
  )

  callback.activate(sessionid, cb)
  ui_session.query(sessionid)
end


return src
