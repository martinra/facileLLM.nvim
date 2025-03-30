---@alias FacileLLM.Conversation FacileLLM.Message[]
---@alias FacileLLM.MsgIndex integer
---@alias FacileLLM.ConversationName string


local config = require("facilellm.config")
local message = require("facilellm.session.message")
local util = require("facilellm.util")


---@param initial nil | FacileLLM.ConversationName | FacileLLM.Conversation
---@return FacileLLM.Conversation
local create = function (initial)
  if type(initial) == "string" then
    local conv = config.opts.conversations[initial]
    if not conv then
      vim.notify("unavailable conversation " .. initial, vim.log.levels.WARN)
      return {}
    end
    return util.deep_copy_values(conv)
  else
    return initial or {}
  end
end

---@param conversation FacileLLM.Conversation
---@param role FacileLLM.MsgRole
---@param content string | string[]
---@return nil
local add_message = function (conversation, role, content)
  local last_msg = conversation[#conversation]
  if role == nil or last_msg and not message.ispruned(last_msg)
    and role == last_msg.role then
    if type(content) == "string" then
      message.append(last_msg, content)
    else
      message.append_lines(last_msg, content)
    end
  else
    table.insert(conversation, message.create(role, content))
  end
end

---@param conversation FacileLLM.Conversation
---@param content string | string[]
---@return nil
local add_instruction_message = function (conversation, content)
  add_message(conversation, "Instruction", content)
end

---@param conversation FacileLLM.Conversation
---@param content string | string[]
---@return nil
local add_context_message = function (conversation, content)
  add_message(conversation, "Context", content)
end

---@param conversation FacileLLM.Conversation
---@param content string | string[]
---@param filename_tag string
---@param filetype_tag string
---@return nil
local add_file_context_message = function (conversation, content, filename_tag, filetype_tag)
  local last_msg = conversation[#conversation]
  if last_msg and not message.ispruned(last_msg)
    and last_msg.role == "FileContext" then
    ---@cast last_msg FacileLLM.FileContextMessage
    if last_msg.filename_tag == filename_tag and last_msg.filetype_tag == filetype_tag then
      if type(content) == "string" then
        message.append(last_msg, content)
      else
        message.append_lines(last_msg, content)
      end
    end
  else
    table.insert(conversation,
      message.create(
        "FileContext", content,
        {
          filename_tag = filename_tag,
          filetype_tag = filetype_tag
        }
    ))
  end
end

---@param conversation FacileLLM.Conversation
---@param content string | string[]
---@return nil
local add_example_message = function (conversation, content)
  add_message(conversation, "Example", content)
end

---@param conversation FacileLLM.Conversation
---@param content string | string[]
---@return nil
local add_input_message = function (conversation, content)
  add_message(conversation, "Input", content)
end

---@param conversation FacileLLM.Conversation
---@param content string | string[]
---@return nil
local add_llm_message = function (conversation, content)
  add_message(conversation, "LLM", content)
end

---@param conv FacileLLM.Conversation
---@param conv_append FacileLLM.Conversation
---@return nil
local append = function (conv, conv_append)
  for _,msg in ipairs(conv_append) do
    table.insert(conv, msg)
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
---@return FacileLLM.Message?
local get_last_llm_message = function (conv)
  for mx = #conv,1,-1 do
    if not message.ispurged(conv[mx]) and conv[mx].role == "LLM" then
      return conv[mx]
    end
  end
end

---@param lines string[]
---@return FacileLLM.Conversation
local parse_rendered_conversation = function(lines)
  ---@type FacileLLM.Conversation
  local conv = {}
  if #lines == 0 then
    return conv
  end

  local current_role = nil
  local current_lines = {}

  local function flush_message()
    if current_role then
      local first_nonempty_line = 0
      for lx = 1,#current_lines do
        if current_lines[lx] ~= "" then
          first_nonempty_line = lx
          break
        end
      end
      if first_nonempty_line ~= 0 then
        for _ = 1,first_nonempty_line-1 do
          table.remove(current_lines,1)
        end
      end

      for lx = #current_lines,1,-1 do
        if current_lines[lx] == "" then
          table.remove(current_lines)
        end
      end

      if #current_lines > 0 then
        table.insert(conv, message.create(current_role, current_lines))
        current_lines = {}
      end
    end
  end

  for _, line in ipairs(lines) do
    if line == config.opts.naming.role_display.instruction then
      flush_message()
      current_role = "Instruction"
    elseif line == config.opts.naming.role_display.context then
      flush_message()
      current_role = "Context"
    elseif line == config.opts.naming.role_display.file_context then
      flush_message()
      current_role = "FileContext"
    elseif line == config.opts.naming.role_display.example then
      flush_message()
      current_role = "Example"
    elseif line == config.opts.naming.role_display.input then
      flush_message()
      current_role = "Input"
    elseif line == config.opts.naming.role_display.llm then
      flush_message()
      current_role = "LLM"
    elseif current_role then
      table.insert(current_lines, line)
    end
  end

  flush_message()
  return conv
end


return {
  create                      = create,
  add_llm_message             = add_llm_message,
  add_input_message           = add_input_message,
  add_instruction_message     = add_instruction_message,
  add_context_message         = add_context_message,
  add_file_context_message    = add_file_context_message,
  add_example_message         = add_example_message,
  append                      = append,
  get_last_message_with_index = get_last_message_with_index,
  get_last_llm_message        = get_last_llm_message,
  parse_rendered_conversation = parse_rendered_conversation,
}

