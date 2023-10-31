local conversation = require("facilellm.session.conversation")
local llm = require("facilellm.llm")
local util = require("facilellm.util")

---@class Session
---@field name string
---@field model LLM
---@field conversation Conversation
---@field conversation_locked boolean


---@type table<number,Session> Table of sessions by their id
local sessions = {}

---@return number
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

---@param model_config LLMConfig
---@param name? string
---@return number sessionid of the newly created session
local create = function (model_config, name)
  local sessionid = new_sessionid()
  local model = llm.dispatch(model_config.implementation)(model_config.opts)
  name = name or model_config.name or model.name

  ---@type Session
  local sess = {
    name = name,
    model = model,
    conversation = conversation.create(model.initial_conversation),
    conversation_locked = false,
  }
  sessions[sessionid] = sess

  return sessionid
end

---@param sessionid number
---@return nil
local delete = function (sessionid)
  sessions[sessionid] = nil
end

---@param name string
---@return nil | number sessionid
local get_by_name = function (name)
  for id,session in ipairs(sessions) do
    if session.name == name then
      return id
    end
  end
end

---@param sessionid number
---@return string
local get_name = function (sessionid)
  return sessions[sessionid].name
end

---@param sessionid number
---@return LLM
local get_model = function (sessionid)
  return sessions[sessionid].model
end

---@param sessionid number
---@return Conversation
local get_conversation = function (sessionid)
  return sessions[sessionid].conversation
end

---@param sessionid number
---@param role string
---@param content string | string[]
---@return nil
local add_message = function (sessionid, role, content)
  conversation.add_message(get_conversation(sessionid), role, content)
end

---@param sessionid number
---@param role string
---@return nil
local add_message_selection = function (sessionid, role)
  local lines = util.get_visual_selection()
  if lines then
    add_message(sessionid, role, lines)
  end
end

---@param sessionid number
---@return boolean
local is_conversation_locked = function (sessionid)
  return sessions[sessionid].conversation_locked
end

---@param sessionid number
---@return nil
local lock_conversation = function (sessionid)
  sessions[sessionid].conversation_locked = true
end

---@param sessionid number
---@return nil
local unlock_conversation = function (sessionid)
  sessions[sessionid].conversation_locked = false
end

---@param sessionid number
---@param render_conversation function(number): nil
---@param on_complete function(): nil
---@return nil
local query_model = function (sessionid, render_conversation, on_complete)
  if is_conversation_locked(sessionid) then
    vim.notify("querying model despite lock", vim.log.levels.WARN)
    return
  end

  ---@param role string
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
  get_by_name            = get_by_name,
  get_name               = get_name,
  get_model              = get_model,
  get_conversation       = get_conversation,
  add_message            = add_message,
  add_message_selection  = add_message_selection,
  is_conversation_locked = is_conversation_locked,
  lock_conversation      = lock_conversation,
  unlock_conversation    = unlock_conversation,
  query_model            = query_model,
}
