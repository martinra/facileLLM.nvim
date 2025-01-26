local message = require("facilellm.session.message")


---@alias FacileLLM.API.OpenAI.MsgRole ("system"| "assistant"| "user")

---@class FacileLLM.API.OpenAI.Message
---@field role FacileLLM.API.OpenAI.MsgRole
---@field content string

---@alias OpenAIConversation FacileLLM.API.OpenAI.Message[]


---@param role FacileLLM.MsgRole
---@return FacileLLM.API.OpenAI.MsgRole
local convert_role_to_oai = function (role)
  if role == "Instruction" then
    return "system"
  elseif role == "Context" then
    return "system"
  elseif role == "Example" then
    return "system"
  elseif role == "LLM" then
    return "assistant"
  elseif role == "Input" then
    return "user"
  else
    error("unknown role " .. role)
  end
end

---@param msg FacileLLM.Message
---@return FacileLLM.API.OpenAI.Message
local convert_msg_to_oai = function (msg)
  local msg_oai = {
    role = convert_role_to_oai(msg.role),
    content = table.concat(msg.lines, "\n"),
  }
  if msg.role == "Context" then
    msg_oai.content =
      "The conversation will be based on the following context:\n" ..
      '"""\n' ..
      msg_oai.content .. "\n" ..
      '"""'
    elseif msg.role == "Example" then
    msg_oai.content =
      "This is an example of how you should respond:\n" ..
      '"""\n' ..
      msg_oai.content .. "\n" ..
      '"""'
  end
  return msg_oai
end

---@param conversation FacileLLM.Conversation
---@return FacileLLM.API.OpenAI.Message[]
local convert_conv_to_oai = function (conversation)
  local oai_messages = {}
  for _,msg in ipairs(conversation) do
    if not message.isempty(msg) and not message.ispruned(msg) then
      table.insert(oai_messages, convert_msg_to_oai(msg))
    end
  end
  return oai_messages
end


---@type FacileLLM.Provider.OAIConversion
return {
  convert_role_to_oai = convert_role_to_oai,
  convert_msg_to_oai  = convert_msg_to_oai,
  convert_conv_to_oai = convert_conv_to_oai,
}
