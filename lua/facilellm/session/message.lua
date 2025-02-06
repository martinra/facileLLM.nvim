-- Possible roles in a Message need to be provided/translated
-- by a model, we do not check them. The default role for
-- input is "Input".
---@alias FacileLLM.MsgRole ("Instruction"| "Context"| "FileContext"| "Example"| "Input"| "LLM")

---@alias FacileLLM.MsgStatus (nil| "pruned"| "purged")

---@class FacileLLM.Message
---@field role FacileLLM.MsgRole
---@field lines string[]
---@field status FacileLLM.MsgStatus
---@field preserve boolean?
---@field cache boolean?

---@class FacileLLM.FileContextMessage : FacileLLM.Message
---@field filetype_tag string


---@param role string
---@return boolean
local is_general_instruction_role = function (role)
  return role == "Instruction" or role == "Context" or role == "FileContext" or role == "Example"
end

---@param role FacileLLM.MsgRole
---@param content nil | string | string[]
---@param opts table?
---@return FacileLLM.Message
local create = function (role, content, opts)
  local lines = {}
  if type(content) == "string" then
    lines = vim.split(content, "\n")
  elseif type(content) == "table" then
    lines = content
  end

  ---@type FacileLLM.Message
  local msg = {
    role = role,
    lines = lines,
    status = nil,
    preserve = is_general_instruction_role(role),
    cache = is_general_instruction_role(role),
  }
  return vim.tbl_deep_extend("keep", msg, opts or {})
end

---@param msg FacileLLM.Message
---@return boolean
local isempty = function (msg)
  return #msg.lines == 0
end

---@param msg FacileLLM.Message
---@return boolean
local ispruned = function (msg)
  return msg.status == "pruned" or msg.status == "purged"
end

---@param msg FacileLLM.Message
---@return boolean
local ispurged = function (msg)
  return msg.status == "purged"
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

---@param msg FacileLLM.Message
---@return nil
local prune = function (msg)
  if msg.status == nil then
    msg.status = "pruned"
  end
end

---@param msg FacileLLM.Message
---@return nil
local deprune = function (msg)
  if msg.status == "pruned" then
    msg.status = nil
  end
end

---@param msg FacileLLM.Message
---@return nil
local purge = function (msg)
  msg.status = "purged"
end


return {
  is_general_instruction_role = is_general_instruction_role,
  create       = create,
  isempty      = isempty,
  ispruned     = ispruned,
  ispurged     = ispurged,
  append       = append,
  append_lines = append_lines,
  prune        = prune,
  deprune      = deprune,
  purge        = purge,
}
