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

---@param output table
---@return string
local output_to_string = function (output)
  local lines = vim.split(table.concat(output, ""), "\n")
  for _,line in ipairs(lines) do
    if string.match(line, "^%s*$") then
      table.remove(lines)
    else
      lines[1] = string.gsub(line, "^%s*(.-)$", "%1")
      break
    end
  end
  return table.concat(lines, "\n")
end

---@type FacileLLM.LLM.PromptConversion
return {
  conversation_to_input = conversation_to_input,
  output_to_string = output_to_string,
}
