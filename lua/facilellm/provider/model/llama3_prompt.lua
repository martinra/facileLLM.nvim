-- Prompt conversion for LLama3


local generic = require("facilellm.provider.model.generic")
local message = require("facilellm.session.message")


---@param msg FacileLLM.Message
---@return string
local convert_msg_to_llama = function (msg)
  local content = table.concat(msg.lines, "\n")

  local prompt = "<|start_header_id|>"

  if msg.role == "Instruction" then
    prompt = prompt .. "system"
  elseif msg.role == "Context" then
    prompt = prompt .. "system"
  elseif msg.role == "Example" then
    prompt = prompt .. "system"
  elseif msg.role == "Input" then
    prompt = prompt .. "user"
  elseif msg.role == "LLM" then
    prompt = prompt .. "assistant"
  end
  prompt = prompt .. "<|end_header_id|>\n\n"

  prompt = prompt .. generic.convert_msg_minimal_roles(msg)
  if msg.role == "Context" then
    prompt = prompt .. "The conversation will be based on the following context:\n"
  elseif msg.role == "Example" then
    prompt = prompt .. "This is an example of how you should respond:\n"
  end

  prompt = prompt .. content .. "<|eot_id|>"
  return prompt
end

---@param conversation FacileLLM.Conversation
---@param opts table?
---@return table
local convert_conv_to_llama = function (conversation, opts)
  opts = opts or {}
  local params = opts.params or {}

  local prompt = "<|begin_of_text|>"
  for _,msg in ipairs(conversation) do
    if not message.isempty(msg) and not message.ispruned(msg) then
      prompt = prompt .. convert_msg_to_llama(msg)
    end
  end
  prompt = prompt .. "<|start_header_id|>assistant<|end_header_id|>\n\n"

  return {
    temperature = params.temperature or 0.6,
    top_p = params.top_p or 0.9,
    top_k = params.top_k or 50,

    presence_penalty = params.presence_penalty or 0,
    -- frequency_penalty = params.frequency_penalty or 0,

    stop_sequences = "<|end_of_text|>,<|eot_id|>",

    max_new_tokens = params.max_new_tokens or 1024,
    prompt = prompt,
  }
end


---@type FacileLLM.Provider.PromptConversion
return {
  convert_msg_to_prompt  = convert_msg_to_llama,
  convert_conv_to_prompt = convert_conv_to_llama,
}
