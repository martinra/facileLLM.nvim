---@class Message
---@field role  string
---@field lines string[]

-- Possible roles in a Message need to be provided/translated by
-- a model, we do not check them. The default role for input is
-- "Input".


---@param role string
---@param lines string | string[]
---@return Message
local create = function (role, lines)
  lines = lines or ""
  if type(lines) == "string" then
    lines = { lines }
  end

  ---@type Message
  local msg = {
    role = role,
    lines = lines,
  }
  return msg
end

---@param msg Message
---@param content string | string[]
---@return nil
local append = function (msg, content)
  local lines = {}
  if type(content) == "string" then
    lines = vim.split(content, "\n")
  else
    lines = content
  end

  for ix,line in ipairs(lines) do
    if ix == 1 then
      msg.lines[#msg.lines] = msg.lines[#msg.lines] .. line
    else
      table.insert(msg.lines, line)
    end
  end
end


return {
  create = create,
  append = append,
}
