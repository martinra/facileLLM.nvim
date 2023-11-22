local config = require("facilellm.config")
local conversation = require("facilellm.session.conversation")
local llm = require("facilellm.llm")
local message = require("facilellm.session.message")


---@alias FacileLLM.SessionId integer

---@class FacileLLM.Session
---@field name string
---@field model FacileLLM.LLM
---@field conversation FacileLLM.Conversation
---@field conversation_locked boolean
---@field config FacileLLM.Config.LLM


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

local get_model_config = function (sessionid)
  return sessions[sessionid].config
end

---@param model_config FacileLLM.Config.LLM
---@return FacileLLM.SessionId
local create = function (model_config)
  local sessionid = new_sessionid()

  local model = llm.create(model_config.implementation, model_config.opts)
  local name = model_config.name or model.name
  name = unique_name_variant(name)

  ---@type FacileLLM.Session
  local sess = {
    name = name,
    model = model,
    conversation = conversation.create(model_config.initial_conversation),
    conversation_locked = false,
    config = vim.tbl_deep_extend("force", {}, model_config),
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
---@param name string
---@return string
local set_name = function (sessionid, name)
  name = unique_name_variant(name)
  sessions[sessionid].name = name
  return name
end

---@param sessionid FacileLLM.SessionId
---@return FacileLLM.LLM
local get_model = function (sessionid)
  return sessions[sessionid].model
end

---@param sessionid FacileLLM.SessionId
---@param model_config FacileLLM.Config.LLM
local set_model = function (sessionid, model_config)
  local sess = sessions[sessionid]
  sess.model = llm.create(model_config.implementation, model_config.opts)
  sess.config = vim.tbl_deep_extend("force", {}, model_config)
end

---@param sessionid FacileLLM.SessionId
---@return FacileLLM.Conversation
local get_conversation = function (sessionid)
  return sessions[sessionid].conversation
end

---@param sessionid FacileLLM.SessionId
---@return string[]?
local get_last_llm_message = function (sessionid)
  local conv = sessions[sessionid].conversation
  for mx = #conv,1,-1 do
    if conv[mx].role == "LLM" then
      return conv[mx].lines
    end
  end
end

---@param sessionid FacileLLM.SessionId
---@param role FacileLLM.MsgRole
---@param content string | string[]
---@return nil
local add_message = function (sessionid, role, content)
  conversation.add_message(get_conversation(sessionid), role, content)
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
---@return boolean
local clear_conversation = function (sessionid, instruction, context)
  if is_conversation_locked(sessionid) and config.opts.feedback.conversation_lock.warn_on_clear then
    vim.notify("clearing conversation despite lock", vim.log.levels.WARN)
    return false
  end

  if context == "delete" and instruction == "delete" then
    sessions[sessionid].conversation = {}
    return true
  end

  if instruction == "preserve" and context == "preserve" then
    local conv = {}
    for _,msg in ipairs(sessions[sessionid].conversation) do
      if msg.role == "Instruction" or msg.role == "Context" then
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
    end
  end

  if instruction == "combine" and message.isempty(instruction_msgs[1]) then
    instruction_msgs[1] = nil
  end
  if context == "combine" and message.isempty(context_msgs[1]) then
    context_msgs[1] = nil
  end

  local conv = {}
  for _,msg in ipairs(instruction_msgs) do
    table.insert(conv, msg)
  end
  for _,msg in ipairs(context_msgs) do
    table.insert(conv, msg)
  end
  sessions[sessionid].conversation = conversation.create(conv)

  return true
end

---@param sessionid FacileLLM.SessionId
---@param render_conversation function(FacileLLM.SessionId): nil
---@param on_complete function(FacileLLM.SessionId): nil
---@return nil
local query_model = function (sessionid, render_conversation, on_complete)
  if is_conversation_locked(sessionid) and config.opts.feedback.conversation_lock.warn_on_query then
    vim.notify("querying model despite lock", vim.log.levels.WARN)
    return
  end

  ---@param role FacileLLM.MsgRole
  ---@param content string | string[]
  ---@return nil
  local add_message_and_render = function (role, content)
    add_message(sessionid, role, content)
    vim.schedule(function ()
      render_conversation(sessionid)
    end)
  end

  ---@return nil
  local on_complete__loc = function ()
    unlock_conversation(sessionid)
    vim.schedule(function ()
      on_complete(sessionid)
      render_conversation(sessionid)
    end)
  end

  lock_conversation(sessionid)
  local model = get_model(sessionid)
  model.response_to(get_conversation(sessionid),
    add_message_and_render, on_complete__loc)
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
  get_model              = get_model,
  set_model              = set_model,
  get_model_config       = get_model_config,
  get_conversation       = get_conversation,
  get_last_llm_message   = get_last_llm_message,
  add_message            = add_message,
  is_conversation_locked = is_conversation_locked,
  lock_conversation      = lock_conversation,
  unlock_conversation    = unlock_conversation,
  clear_conversation = clear_conversation,
  query_model            = query_model,
}
