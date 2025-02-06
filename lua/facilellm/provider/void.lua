local conversation = require("facilellm.session.conversation")


local R = {}

---@param add_message function
---@param on_complete function
---@param lines (string[] | string)[]
---@param delay integer
---@param cancelled { [1]: boolean }
---@return nil
R.send_word_by_word = function (conv, add_message, on_complete, lines, delay, cancelled)
  if cancelled[1] then
    return
  end

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
    add_message(word)
    if #fst_line ~= 0 then
      add_message(" ")
    end
  else
    table.remove(lines, 1)
    if #lines ~= 0 then
      add_message("\n")
    end
  end

  vim.defer_fn(function ()
    R.send_word_by_word(conv, add_message, on_complete, lines, delay, cancelled)
  end, delay)
end

---@param add_message function
---@param on_complete function
---@param lines string[]
---@param response_lines string[]
---@param major_delay integer
---@param minor_delay integer
---@param cancelled { [1]: boolean }
---@return nil
R.send_response = function(conv, add_message, on_complete, lines, response_lines, major_delay, minor_delay, cancelled)
  if cancelled[1] then
    return
  end

  if #response_lines == 0 then
    local lines_loc = {}
    for k,v in pairs(lines) do
      lines_loc[k] = v
    end
    vim.defer_fn(
      function ()
        R.send_word_by_word(conv, add_message, on_complete, lines_loc, minor_delay, cancelled)
      end,
      major_delay)
  else
    local line = table.remove(response_lines, 1)
    add_message(line)
    if #response_lines ~= 0 or #lines ~= 0 then
      add_message("\n")
    end
    vim.defer_fn( function ()
      R.send_response(conv, add_message, on_complete, lines, response_lines, major_delay, minor_delay, cancelled)
    end, major_delay)
  end
end

---@param conv FacileLLM.Conversation
---@param add_message function
---@param on_complete function
---@param opts table
---@return function?
local response_to = function (conv, add_message, on_complete, opts)
  local _, msg = conversation.get_last_message_with_index(conv)
  if not msg then
    add_message("The void tried to hear your message, but there is nothing to be heard.")
    on_complete()
    return function () end
  end

  local response_lines = {
    "The void heard your message.",
    "The echo of your message comes closer.",
    "Soon it will arrive.",
  }

  local cancelled = { false }

  local major_delay = opts.params.major_delay
  local minor_delay = opts.params.minor_delay
  R.send_response(conv, add_message, on_complete,
    msg.lines, response_lines, major_delay, minor_delay, cancelled)

  return function ()
    cancelled[1] = true
  end
end

---@return table
local default_opts = function ()
  return {
    name = "The Void Mock LLM",
    params = {
      major_delay = 1500,
      minor_delay = 20,
    },
  }
end

---@param opts table
---@return FacileLLM.Provider
local create = function (opts)
  opts = opts or {}
  opts = vim.tbl_deep_extend("force", default_opts(), opts)

  ---@type FacileLLM.Provider
  local provider = {
    name = opts.name,
    params = opts.params,
    response_to = function(conv, add_message, on_complete)
      return response_to(conv, add_message, on_complete, opts)
    end,
  }
  return provider
end


return {
  create = create,
}
