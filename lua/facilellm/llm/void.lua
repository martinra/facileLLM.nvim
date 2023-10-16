local R = {}

---comment
---@param add_message function
---@param on_complete function
---@param lines (string[] | string)[]
---@param delay number
---@return nil
R.send_word_by_word = function (add_message, on_complete, lines, delay)
  if #lines == 0 then
    on_complete()
    return
  end

  local fst_line = lines[1]
  if type(fst_line) == "string" then
    ---@cast fst_line string
    local words = {}
    for w in string.gmatch(fst_line, "%S+") do
      table.insert(words, w)
    end
    fst_line = words
    lines[1] = words
  end
  if #fst_line ~= 0 then
    local word = table.remove(fst_line, 1)
    add_message("Void", word .. " ")
  else
    add_message("Void", "\n")
    table.remove(lines, 1)
  end

  vim.defer_fn(function () R.send_word_by_word(add_message, on_complete, lines, delay) end, delay)
end

---comment
---@param add_message function
---@param on_complete function
---@param lines string[]
---@param response_lines string[]
---@return nil
R.send_response = function(add_message, on_complete, lines, response_lines)
  if #response_lines == 0 then
    vim.defer_fn(function () R.send_word_by_word(add_message, on_complete, lines, 20) end, 1500)
  else
    local line = table.remove(response_lines, 1)
    add_message("Void", line .. "\n")
    vim.defer_fn(function () R.send_response(add_message, on_complete, lines, response_lines) end, 1500)
  end
end

---@param conv Conversation
---@param add_message function
---@param on_complete function
---@param _ table
---@return nil
local response_to = function (conv, add_message, on_complete, _)
  if #conv == 0 then
    add_message("Void", "The void tried to hear your message, but there is nothing to be heard.")
    on_complete()
    return
  end

  local lines = conv[#conv].lines

  local response_lines = {
    "The void heard your message.",
    "The echo of your message comes closer.",
    "Soon it will arrive.",
   }

  R.send_response(add_message, on_complete, lines, response_lines)
end

---@return table
local default_opts = function ()
  return {
    name = "The Void Mock LLM",
    params = {},
  }
end

---@param opts table
---@return LLM
local create = function (opts)
  opts = opts or {}
  opts = vim.tbl_extend("force", default_opts(), opts)

  ---@type LLM
  local llm = {
    name = opts.name,
    params = opts.params,
    response_to = response_to,
  }
  return llm
end


return {
  create = create,
}
