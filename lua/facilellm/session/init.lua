local conversation = require("facilellm.session.conversation")
local llm = require("facilellm.llm")
local message = require("facilellm.session.message")
local util = require("facilellm.util")


---@alias FacileLLM.SessionId number

---@class FacileLLM.Session
---@field name string
---@field model FacileLLM.LLM
---@field conversation FacileLLM.Conversation
---@field conversation_locked boolean
---@field config FacileLLM.LLMConfig


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

---@param name string
---@return string
local unique_name_variant = function (name)
  local suffices = {}

  local name_suffix_find = string.find(name, "%s*%d+%s*$")
  local name_stem, name_suffix
  if name_suffix_find then
    name_stem = string.sub(name, 1, name_suffix_find-1)
    name_suffix = string.sub(name, name_suffix_find, string.len(name))
    name_suffix = string.match(name_suffix, "^()%s*$") and "" or string.match(name_suffix, "^%s*(.*%S)")
    suffices[name_suffix] = true
  else
    name_stem = name
    name_suffix = nil
    suffices["1"] = true
  end

  local nmb_sess_suffices = 0
  for _,sess in pairs(sessions) do
    if string.sub(sess.name, 1, string.len(name_stem)) == name_stem then
      local suffix = string.sub(sess.name, string.len(name_stem)+1, string.len(sess.name))
      suffix = string.match(suffix, "^()%s*$") and "" or string.match(suffix, "^%s*(.*%S)")
      suffices[suffix] = true
      nmb_sess_suffices = nmb_sess_suffices + 1
    end
  end

  if nmb_sess_suffices ~= 0 then
    local new_suffix = name_suffix and tonumber(name_suffix) or 1
    while suffices[tostring(new_suffix)] do
      new_suffix = new_suffix + 1
    end
    name = name .. " " .. new_suffix
  end

  return name
end

---@param orig_name string
---@return string
local fork_name_variant = function (orig_name)
  if string.find(orig_name, "Fork$") then
    return orig_name
  else
    local fork_nmb_find = string.find(orig_name, "Fork %d+$")
    if fork_nmb_find then
      return string.sub(orig_name, 1, fork_nmb_find + 3)
    else
      return orig_name .. " Fork"
    end
  end
end

local get_model_config = function (sessionid)
  return sessions[sessionid].config
end

---@param model_config FacileLLM.LLMConfig
---@return FacileLLM.SessionId
local create = function (model_config)
  local sessionid = new_sessionid()
  local model = llm.dispatch(model_config.implementation)(model_config.opts)
  local name = model_config.name or model.name
  name = unique_name_variant(name)

  ---@type FacileLLM.Session
  local sess = {
    name = name,
    model = model,
    conversation = conversation.create(model.initial_conversation),
    conversation_locked = false,
    config = model_config,
  }
  sessions[sessionid] = sess

  return sessionid
end

---@param sessionid FacileLLM.SessionId
---@return nil
local delete = function (sessionid)
  sessions[sessionid] = nil
end

---@param sessionid FacileLLM.SessionId
---@param name string
---@return string
local set_name = function (sessionid, name)
  name = unique_name_variant(name)
  sessions[sessionid].name = name
  return name
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
---@return boolean
local clear_conversation = function (sessionid, preserve_context)
  if is_conversation_locked(sessionid) then
    vim.notify("clearing conversation despite lock", vim.log.levels.WARN)
    return false
  end

  if not preserve_context then
    sessions[sessionid].conversation = {}
    return true
  else
    local context_lines = {}
    for _,msg in ipairs(sessions[sessionid].conversation) do
      if msg.role == "Context" then
        for _,line in ipairs(msg.lines) do
          table.insert(context_lines, line)
        end
      end
    end
    if #context_lines == 0 then
      sessions[sessionid].conversation = conversation.create()
    else
      local context_msg = message.create("Context", context_lines)
      sessions[sessionid].conversation = conversation.create({ context_msg })
    end
    return true
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
  set_name               = set_name,
  get_name               = get_name,
  fork_name_variant      = fork_name_variant,
  get_model              = get_model,
  get_model_config       = get_model_config,
  get_conversation       = get_conversation,
  add_message            = add_message,
  add_message_selection  = add_message_selection,
  is_conversation_locked = is_conversation_locked,
  lock_conversation      = lock_conversation,
  unlock_conversation    = unlock_conversation,
  clear_conversation = clear_conversation,
  query_model            = query_model,
}
