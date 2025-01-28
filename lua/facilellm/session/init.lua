local config = require("facilellm.config")
local conversation = require("facilellm.session.conversation")
local provider = require("facilellm.provider")
local message = require("facilellm.session.message")
local util = require("facilellm.util")


---@alias FacileLLM.SessionId integer

---@class FacileLLM.Session
---@field name string
---@field provider FacileLLM.Provider
---@field conversation FacileLLM.Conversation
---@field conversation_locked boolean
---@field cancel_query function?
---@field config FacileLLM.Config.Provider


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
  local fork = config.opts.naming.fork_suffix
  if string.find(orig_name, fork .. "$") then
    return orig_name
  else
    local fork_nmb_find = string.find(orig_name, fork .. " %d+$")
    if fork_nmb_find then
      return string.sub(orig_name, 1, fork_nmb_find + 3)
    else
      return orig_name .. " " .. fork
    end
  end
end

local get_provider_config = function (sessionid)
  return sessions[sessionid].config
end

---@param provider_config FacileLLM.Config.Provider
---@return FacileLLM.SessionId
local create = function (provider_config)
  local sessionid = new_sessionid()

  local provider_instance = provider.create(provider_config.implementation, provider_config.opts)
  local name = provider_config.name or provider_instance.name
  name = unique_name_variant(name)

  ---@type FacileLLM.Session
  local sess = {
    name = name,
    provider = provider_instance,
    conversation = conversation.create(provider_config.conversation),
    conversation_locked = false,
    cancel_query = nil,
    config = util.deep_copy_values(provider_config),
  }
  sessions[sessionid] = sess

  return sessionid
end

---@param sessionid FacileLLM.SessionId
---@return nil
local delete = function (sessionid)
  if sessions[sessionid].cancel_query ~= nil then
    sessions[sessionid].cancel_query()
  end
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
    local id, _ = next(sessions)
    return id
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
---@param name string
---@return string
local set_name = function (sessionid, name)
  name = unique_name_variant(name)
  sessions[sessionid].name = name
  return name
end

---@param sessionid FacileLLM.SessionId
---@return FacileLLM.Provider
local get_provider = function (sessionid)
  return sessions[sessionid].provider
end

---@param sessionid FacileLLM.SessionId
---@param provider_config FacileLLM.Config.Provider
local set_provider = function (sessionid, provider_config)
  local sess = sessions[sessionid]
  sess.provider = provider.create(provider_config.implementation, provider_config.opts)
  sess.config = vim.tbl_deep_extend("force", {}, provider_config)
end

---@param sessionid FacileLLM.SessionId
---@return FacileLLM.Conversation
local get_conversation = function (sessionid)
  return sessions[sessionid].conversation
end

---@param sessionid FacileLLM.SessionId
---@return FacileLLM.MsgIndex?
---@return FacileLLM.Message?
local get_last_message_with_index = function (sessionid)
  local conv = sessions[sessionid].conversation
  return conversation.get_last_message_with_index(conv)
end

---@param sessionid FacileLLM.SessionId
---@return FacileLLM.Message?
local get_last_llm_message = function (sessionid)
  local conv = sessions[sessionid].conversation
  return conversation.get_last_llm_message(conv)
end

---@param sessionid FacileLLM.SessionId
---@param role FacileLLM.MsgRole
---@param content string | string[]
---@return nil
local add_message = function (sessionid, role, content)
  conversation.add_message(get_conversation(sessionid), role, content)
end

---@param sessionid FacileLLM.SessionId
---@param conv FacileLLM.Conversation
---@return nil
local append_conversation = function (sessionid, conv)
  conversation.append(get_conversation(sessionid), conv)
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
---@param instruction ("delete"| "preserve"| "combine")
---@param context ("delete"| "preserve"| "combine")
---@param example ("delete"| "preserve"| "combine")
---@return boolean
local clear = function (sessionid, instruction, context, example)
  if is_conversation_locked(sessionid) and config.opts.feedback.conversation_lock.warn_on_clear then
    vim.notify("clearing conversation despite lock", vim.log.levels.WARN)
    return false
  end

  if instruction == "delete" and context == "delete" and example == "delete" then
    sessions[sessionid].conversation = {}
    return true
  end

  if instruction == "preserve" and context == "preserve" and example == "preserve" then
    local conv = {}
    for _,msg in ipairs(sessions[sessionid].conversation) do
      if msg.role == "Instruction" or msg.role == "Context" or msg.role == "Example" then
        table.insert(conv, msg)
      end
    end
    sessions[sessionid].conversation = conversation.create(conv)
    return true
  end

  local instruction_msgs = {}
  if instruction == "combine" then
    instruction_msgs[1] = message.create("Context")
  end
  local context_msgs = {}
  if context == "combine" then
    context_msgs[1] = message.create("Instruction")
  end
  local example_msgs = {}
  if context == "combine" then
    example_msgs[1] = message.create("Example")
  end

  for _,msg in ipairs(sessions[sessionid].conversation) do
    if msg.role == "Instruction" then
      if instruction == "preserve" then
        table.insert(context_msgs, msg)
      elseif instruction == "combine" then
        message.append_lines(instruction_msgs[1], msg.lines)
      end
    elseif msg.role == "Context" then
      if context == "preserve" then
        table.insert(context_msgs, msg)
      elseif context == "combine" then
        message.append_lines(context_msgs[1], msg.lines)
      end
    elseif msg.role == "Example" then
      if context == "preserve" then
        table.insert(example_msgs, msg)
      elseif context == "combine" then
        message.append_lines(example_msgs[1], msg.lines)
      end
    end
  end

  if instruction == "combine" and message.isempty(instruction_msgs[1]) then
    instruction_msgs[1] = nil
  end
  if context == "combine" and message.isempty(context_msgs[1]) then
    context_msgs[1] = nil
  end
  if example == "combine" and message.isempty(example_msgs[1]) then
    example_msgs[1] = nil
  end

  local conv = {}
  for _,msg in ipairs(instruction_msgs) do
    table.insert(conv, msg)
  end
  for _,msg in ipairs(context_msgs) do
    table.insert(conv, msg)
  end
  for _,msg in ipairs(example_msgs) do
    table.insert(conv, msg)
  end
  sessions[sessionid].conversation = conversation.create(conv)

  return true
end

---@param sessionid FacileLLM.SessionId
---@param render_conversation function(FacileLLM.SessionId): nil
---@param on_complete function(FacileLLM.SessionId): nil
---@return nil
local query_provider = function (sessionid, render_conversation, on_complete)
  if is_conversation_locked(sessionid) and config.opts.feedback.conversation_lock.warn_on_query then
    vim.notify("querying provider despite lock", vim.log.levels.WARN)
    return
  end

  if sessions[sessionid].cancel_query ~= nil then
    vim.notify("querying provider despite ongoing query", vim.log.levels.WARN)
    return
  end

  -- The provider may use asynchronous calls, so we wrap this function.
  local add_message_and_render = vim.schedule_wrap(
    ---@param content string | string[]
    ---@return nil
    function (content)
      add_message(sessionid, "LLM", content)
      render_conversation(sessionid)
    end)

  -- The provider may use asynchronous calls, so we wrap this function.
  ---@return nil
  local on_complete__loc = vim.schedule_wrap(
    function ()
      sessions[sessionid].cancel_query = nil
      unlock_conversation(sessionid)
      on_complete(sessionid)
      render_conversation(sessionid)
    end)

  lock_conversation(sessionid)
  local provider_instance = get_provider(sessionid)
  sessions[sessionid].cancel_query = provider_instance.response_to(
    get_conversation(sessionid),
    add_message_and_render, on_complete__loc
  )
end


return {
  create                 = create,
  delete                 = delete,
  get_session_names      = get_session_names,
  get_by_name            = get_by_name,
  get_some_session       = get_some_session,
  get_name               = get_name,
  set_name               = set_name,
  fork_name_variant      = fork_name_variant,
  get_provider           = get_provider,
  set_provider           = set_provider,
  get_provider_config    = get_provider_config,
  get_conversation       = get_conversation,
  get_last_message_with_index = get_last_message_with_index,
  get_last_llm_message   = get_last_llm_message,
  add_message            = add_message,
  append_conversation    = append_conversation,
  is_conversation_locked = is_conversation_locked,
  lock_conversation      = lock_conversation,
  unlock_conversation    = unlock_conversation,
  clear                  = clear,
  query_provider         = query_provider,
}
