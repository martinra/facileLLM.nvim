local message = require("facilellm.session.message")


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
    if type(content) == "string" then
      message.append(last_msg, content)
    else
      message.append_lines(last_msg, content)
    end
  else
    table.insert(conversation, message.create(role, content))
  end
end


return {
  create = create,
  add_message = add_message,
}
