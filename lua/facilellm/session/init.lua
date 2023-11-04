local conversation = require("facilellm.session.conversation")
local llm = require("facilellm.llm")
local util = require("facilellm.util")


---@alias FacileLLM.SessionId number

---@class FacileLLM.Session
---@field name string
---@field model FacileLLM.LLM
---@field conversation FacileLLM.Conversation
---@field conversation_locked boolean


---@type table<FacileLLM.SessionId,FacileLLM.Session> Table of sessions by their id
local sessions = {}

---@return FacileLLM.SessionId
local new_sessionid = function ()
 while true do
    local newid = math.random(10000)
    local existsid = false
    for id, _ in pairs(sessions) do
      if newid == id then
        existsid = true
        break
      end
    end
    if not existsid then
      return newid
    end
  end
end

---@param model_config FacileLLM.LLMConfig
---@param name string?
---@return FacileLLM.SessionId
local create = function (model_config, name)
  local sessionid = new_sessionid()
  local model = llm.dispatch(model_config.implementation)(model_config.opts)
  name = name or model_config.name or model.name

  local suffices = {}
  local nsuffices = 0
  for _,sess in pairs(sessions) do
    if string.sub(sess.name, 1, string.len(name)) == name then
      local suffix = string.sub(sess.name, string.len(name)+1, string.len(sess.name))
      suffix = string.match(suffix, "^()%s*$") and "" or string.match(suffix, "^%s*(.*%S)")
      suffices[suffix] = true
      nsuffices = nsuffices + 1
    end
  end
  if nsuffices ~= 0 then
    local new_suffix = 2
    while suffices[tostring(new_suffix)] do
      new_suffix = new_suffix + 1
    end
    name = name .. " " .. new_suffix
  end

  ---@type FacileLLM.Session
  local sess = {
    name = name,
    model = model,
    conversation = conversation.create(model.initial_conversation),
    conversation_locked = false,
  }
  sessions[sessionid] = sess

  return sessionid
end

---@param sessionid FacileLLM.SessionId
---@return nil
local delete = function (sessionid)
  sessions[sessionid] = nil
end

---@return table<FacileLLM.SessionId,string>
local get_session_names = function ()
  local names = {}
  for id,sess in pairs(sessions) do
    names[id] = sess.name
  end
  return names
end

---@return FacileLLM.SessionId?
local get_some_session = function ()
  if #sessions == 0 then
    return nil
  else
    for id,_ in pairs(sessions) do
      return id
    end
  end
end

---@param name string
---@return FacileLLM.SessionId?
local get_by_name = function (name)
  for id,session in ipairs(sessions) do
    if session.name == name then
      return id
    end
  end
end

---@param sessionid FacileLLM.SessionId
---@return string
local get_name = function (sessionid)
  return sessions[sessionid].name
end

---@param sessionid FacileLLM.SessionId
---@return FacileLLM.LLM
local get_model = function (sessionid)
  return sessions[sessionid].model
end

---@param sessionid FacileLLM.SessionId
---@return FacileLLM.Conversation
local get_conversation = function (sessionid)
  return sessions[sessionid].conversation
end

---@param sessionid FacileLLM.SessionId
---@param role FacileLLM.MsgRole
---@param content string | string[]
---@return nil
local add_message = function (sessionid, role, content)
  conversation.add_message(get_conversation(sessionid), role, content)
end

---@param sessionid FacileLLM.SessionId
---@param role FacileLLM.MsgRole
---@return nil
local add_message_selection = function (sessionid, role)
  local lines = util.get_visual_selection()
  if lines then
    add_message(sessionid, role, lines)
  end
end

---@param sessionid FacileLLM.SessionId
---@return boolean
local is_conversation_locked = function (sessionid)
  return sessions[sessionid].conversation_locked
end

---@param sessionid FacileLLM.SessionId
---@return nil
local lock_conversation = function (sessionid)
  sessions[sessionid].conversation_locked = true
end

---@param sessionid FacileLLM.SessionId
---@return nil
local unlock_conversation = function (sessionid)
  sessions[sessionid].conversation_locked = false
end

---@param sessionid FacileLLM.SessionId
---@param preserve_context boolean
---@return table<FacileLLM.MsgIndex,FacileLLM.MsgIndex>?
local clear_conversation = function (sessionid, preserve_context)
  if is_conversation_locked(sessionid) then
    vim.notify("clearing conversation despite lock", vim.log.levels.WARN)
    return
  end

  if not preserve_context then
    sessions[sessionid].conversation = {}
    return {}
  else
    local msg_map = {}
    local new_conv = {}
    local new_mx = 1
    for mx,msg in ipairs(sessions[sessionid].conversation) do
      if msg.role == "Context" then
        new_conv[new_mx] = msg
        msg_map[mx] = new_mx
        new_mx = new_mx + 1
      end
    end
    sessions[sessionid].conversation = new_conv
    return msg_map
  end
end

---@param sessionid FacileLLM.SessionId
---@param render_conversation function(FacileLLM.SessionId): nil
---@param on_complete function(): nil
---@return nil
local query_model = function (sessionid, render_conversation, on_complete)
  if is_conversation_locked(sessionid) then
    vim.notify("querying model despite lock", vim.log.levels.WARN)
    return
  end

  ---@param role FacileLLM.MsgRole
  ---@param content string | string[]
  ---@return nil
  local add_message_wrapped = function (role, content)
    add_message(sessionid, role, content)
    vim.schedule(function ()
      render_conversation(sessionid)
    end)
  end

  ---@return nil
  local on_complete__loc = function ()
    unlock_conversation(sessionid)
    vim.schedule(function ()
      on_complete()
      render_conversation(sessionid)
    end)
  end

  lock_conversation(sessionid)
  local model = get_model(sessionid)
  model.response_to(get_conversation(sessionid),
    add_message_wrapped, on_complete__loc)
end


return {
  create                 = create,
  delete                 = delete,
  get_session_names      = get_session_names,
  get_by_name            = get_by_name,
  get_some_session       = get_some_session,
  get_name               = get_name,
  get_model              = get_model,
  get_conversation       = get_conversation,
  add_message            = add_message,
  add_message_selection  = add_message_selection,
  is_conversation_locked = is_conversation_locked,
  lock_conversation      = lock_conversation,
  unlock_conversation    = unlock_conversation,
  clear_conversation = clear_conversation,
  query_model            = query_model,
}
