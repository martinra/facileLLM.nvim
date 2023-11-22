local message = require("facilellm.session.message")


---@alias FacileLLM.Conversation FacileLLM.Message[]
---@alias FacileLLM.MsgIndex integer


---@param initial FacileLLM.Conversation?
---@return FacileLLM.Conversation
local create = function (initial)
  return initial or {}
end

---@param conversation FacileLLM.Conversation
---@param role FacileLLM.MsgRole
---@param content string | string[]
---@return nil
local add_message = function (conversation, role, content)
  local last_msg = conversation[#conversation]
  if role == nil or last_msg and role == last_msg.role then
    if type(content) == "string" then
      message.append(last_msg, content)
    else
      message.append_lines(last_msg, content)
    end
  else
    table.insert(conversation, message.create(role, content))
  end
end

---@param conv FacileLLM.Conversation
---@return FacileLLM.MsgIndex?
---@return FacileLLM.Message?
local get_last_message_with_index = function (conv)
  for mx = #conv,1,-1 do
    if not message.ispurged(conv[mx]) then
      return mx, conv[mx]
    end
  end
end

---@param conv FacileLLM.Conversation
---@return string[]?
local get_last_llm_message_lines = function (conv)
  for mx = #conv,1,-1 do
    if not message.ispurged(conv[mx]) and conv[mx].role == "LLM" then
      return conv[mx].lines
    end
  end
end


return {
  create = create,
  add_message = add_message,
  get_last_message_with_index = get_last_message_with_index,
  get_last_llm_message_lines = get_last_llm_message_lines,
}
