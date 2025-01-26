local generic_oai = require("facilellm.provider.model.generic_oai")
local message = require("facilellm.session.message")


---@param msg FacileLLM.Message
---@return FacileLLM.API.OpenAI.Message
local convert_msg_to_claude = function (msg)
  local msg_oai = generic_oai.convert_msg_to_oai(msg)
  if msg.cache then
    msg_oai["cache_control"] = {type = "ephemeral"}
  end
  return msg_oai
end


---@param conversation FacileLLM.Conversation
---@return FacileLLM.API.OpenAI.Message[]
local convert_conv_to_claude = function (conversation)
  local oai_messages = {}
  for _,msg in ipairs(conversation) do
    if not message.isempty(msg) and not message.ispruned(msg) then
      table.insert(oai_messages, convert_msg_to_claude(msg))
    end
  end
  return oai_messages
end


---@type FacileLLM.Provider.OAIConversion
return {
  convert_conv_to_oai = convert_conv_to_claude
}
