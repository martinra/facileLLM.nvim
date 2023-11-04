-- Possible roles in a Message need to be provided/translated
-- by a model, we do not check them. The default role for
-- input is "Input".
---@alias FacileLLM.MsgRole ("Context"| "Input"| "LLM")

---@class FacileLLM.Message
---@field role FacileLLM.MsgRole
---@field lines string[]


---@param role FacileLLM.MsgRole
---@param content string | string[]
---@return FacileLLM.Message
local create = function (role, content)
  local lines = {}
  if type(content) == "string" then
    lines = vim.split(content, "\n")
  else
    lines = content
  end

  ---@type FacileLLM.Message
  local msg = {
    role = role,
    lines = lines,
  }
  return msg
end

---@param msg FacileLLM.Message
---@param content string
---@return nil
local append = function (msg, content)
  local lines = vim.split(content, "\n")
  for ix,line in ipairs(lines) do
    if ix == 1 then
      msg.lines[#msg.lines] = msg.lines[#msg.lines] .. line
    else
      table.insert(msg.lines, line)
    end
  end
end

---@param msg FacileLLM.Message
---@param lines string[]
---@return nil
local append_lines = function (msg, lines)
  for _,line in ipairs(lines) do
    table.insert(msg.lines, line)
  end
end


return {
  create       = create,
  append       = append,
  append_lines = append_lines,
}
