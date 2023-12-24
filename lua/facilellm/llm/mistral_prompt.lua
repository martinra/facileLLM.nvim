-- Prompt conversion for MistralAI

local message = require("facilellm.session.message")


---@param msg FacileLLM.Message
---@return string
local convert_msg_to_mistral = function (msg)
  local content = table.concat(msg.lines, "\n")

  if msg.role == "Context" then
    return
    "The conversation will be based on the following context:\n" ..
    '"""\n' ..
    content .. "\n" ..
    '"""'
  elseif msg.role == "Example" then
    return
    "This is an example of how you should respond:\n" ..
    '"""\n' ..
    content .. "\n" ..
    '"""'
  end

  return content
end

---@param conversation FacileLLM.Conversation
---@param params table?
---@return table
local conversation_to_input = function (conversation, params)
  params = params or {}

  local prompt = "<s>"
  local inst = nil
  for _,msg in ipairs(conversation) do
    if not message.isempty(msg) and not message.ispruned(msg) then
      if inst then
        if msg.role == "LLM" then
          prompt = prompt .. " [/INST]"
          inst = false
        else
          prompt = prompt .. "\n\n"
        end
      elseif not inst then
        if msg.role == "LLM" then
          prompt = prompt .. "\n\n"
        else
          if inst ~= nil then
            prompt = prompt .. "</s>"
          end
          prompt = prompt .. " [INST]"
          inst = true
        end
      end
      prompt = prompt .. " " .. convert_msg_to_mistral(msg)
    end
  end
  if inst then
    prompt = prompt .. " [/INST] "
  else
    prompt = prompt .. "</s>"
  end

  return {
    top_k = params.top_k or 50,
    top_p = params.top_p or 0.9,
    temperature = params.temperature or 0.6,

    presence_penalty = params.presence_penalty or 0,
    frequency_penalty = params.frequency_penalty or 0,

    max_new_tokens = params.max_new_tokens or 1024,
    prompt_template = "{prompt}",
    prompt = prompt,
  }
end

---@param output string[]
---@return FacileLLM.Conversation
local output_to_conversation = function (output)
  return {
    {
      role = "LLM",
      lines = vim.split(table.concat(output, ""), "\n"),
    }
  }
end

---@type FacileLLM.LLM.PromptConversion
return {
  conversation_to_input = conversation_to_input,
  output_to_conversation = output_to_conversation,
}
