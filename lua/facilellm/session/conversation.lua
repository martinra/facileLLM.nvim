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
local add_llm_message = function (conversation, content)
  add_message(conversation, "LLM", content)
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
local add_context_message = function (conversation, content)
  add_message(conversation, "Context", content)
end

---@param conversation FacileLLM.Conversation
---@param content string | string[]
---@param filetype_tag string
---@return nil
local add_file_context_message = function (conversation, content, filetype_tag)
  local last_msg = conversation[#conversation]
  if last_msg and not message.ispruned(last_msg)
    and last_msg.role == "FileContext" then
    ---@cast last_msg FacileLLM.FileContextMessage
    if last_msg.filetype_tag == filetype_tag then
      if type(content) == "string" then
        message.append(last_msg, content)
      else
        message.append_lines(last_msg, content)
      end
    end
  else
    table.insert(conversation, message.create("FileContext", content, {filetype_tag = filetype_tag}))
  end
end

---@param conversation FacileLLM.Conversation
---@param content string | string[]
---@return nil
local add_example_message = function (conversation, content)
  add_message(conversation, "Example", content)
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


return {
  create                      = create,
  add_llm_message             = add_llm_message,
  add_input_message           = add_input_message,
  add_context_message         = add_context_message,
  add_file_context_message    = add_file_context_message,
  add_example_message         = add_example_message,
  append                      = append,
  get_last_message_with_index = get_last_message_with_index,
  get_last_llm_message        = get_last_llm_message,
}

