-- Prompt conversion for MistralAI


local generic = require("facilellm.provider.model.generic")
local message = require("facilellm.session.message")


---@param msg FacileLLM.Message
---@return string
local convert_msg_to_mixtral = function (msg)
  local content = table.concat(msg.lines, "\n")

  local prompt = ""

  if msg.role == "LLM" then
    prompt = prompt .. " [/INST] "
  end

  prompt = prompt .. generic.convert_msg_minimal_roles(msg)

  prompt = prompt .. content
  if msg.role == "Instruction" or
     msg.role == "Context" or
     msg.role == "Example" then
    prompt = prompt .. "\"\"\"\n"
  end

  if msg.role == "LLM" then
    prompt = prompt .. "</s> "
    prompt = prompt .. "[INST] "
  end

  return prompt
end

---@param conversation FacileLLM.Conversation
---@param opts table?
---@return table
local convert_conv_to_mixtral = function (conversation, opts)
  opts = opts or {}
  local params = opts.params or {}

  local prompt = "<s> [INST] "
  for _,msg in ipairs(conversation) do
    if not message.isempty(msg) and not message.ispruned(msg) then
      prompt = prompt .. convert_msg_to_mixtral(msg)
    end
  end
  prompt = prompt .. " [/INST] "

  return {
    temperature = params.temperature or 0.6,
    top_p = params.top_p or 0.9,
    top_k = params.top_k or 50,

    presence_penalty = params.presence_penalty or 0,
    frequency_penalty = params.frequency_penalty or 0,

    max_new_tokens = params.max_new_tokens or 1024,
    prompt_template = "{prompt}",
    prompt = prompt,
  }
end


---@type FacileLLM.Provider.PromptConversion
return {
  convert_msg_to_prompt  = convert_msg_to_mixtral,
  convert_conv_to_prompt = convert_conv_to_mixtral,
}
