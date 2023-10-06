local message = require("facilellm.conversation.message")


---@alias Conversation Message[]


---@param initial nil | Conversation
---@return Conversation
local create = function (initial)
  return initial or {}
end

---@param conversation Conversation
---@param role nil | string
---@param content string | string[]
---@return nil
local add_message = function (conversation, role, content)
  local last_msg = conversation[#conversation]
  if role == nil or last_msg and role == last_msg.role then
    message.append(last_msg, content)
  else
    table.insert(conversation, message.create(role, content))
  end
end


return {
  create = create,
  add_message = add_message,
}
