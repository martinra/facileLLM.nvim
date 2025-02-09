---@alias FacileLLM.Template function(WinId): FacileLLM.Conversation

---@class FacileLLM.Template.ContextTags
---@field size integer?
---@field before_cursor_tag string
---@field cursor_position_tag string
---@field after_cursor_tag string 
---@field reverse boolean


---@param winid WinId
---@param context_size integer?
---@return string[]
local context_before_cursor = function (winid, context_size)
  local bufnr = vim.api.nvim_win_get_buf(winid)

  local r, c = unpack(vim.api.nvim_win_get_cursor(winid))
  local rb
  if not context_size then
    rb = 0
  else
    rb = r - context_size
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, rb, r, false)
  if #lines ~= 0 then
    lines[#lines] = string.sub(lines[#lines], 1, c+1)
  end

  return lines
end

---@param winid WinId
---@param context_size integer?
---@return string[]
local context_after_cursor = function (winid, context_size)
  local bufnr = vim.api.nvim_win_get_buf(winid)

  local r, c = unpack(vim.api.nvim_win_get_cursor(winid))
  local re
  if not context_size then
    re = -1
  else
    re = r + context_size
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, r-1, re, false)
  if #lines ~= 0 then
    lines[1] = string.sub(lines[1], c+2)
  end

  return lines
end

---@param winid WinId
---@param context_tags FacileLLM.Template.ContextTags
---@param filename_tag string
---@param filetype_tag string
---@return FacileLLM.Conversation
local template_filetype_and_context = function (winid, context_tags, filename_tag, filetype_tag)
  local size                = context_tags.size
  local before_cursor_tag   = context_tags.before_cursor_tag
  local cursor_position_tag = context_tags.cursor_position_tag
  local after_cursor_tag    = context_tags.after_cursor_tag
  local reverse             = context_tags.reverse

  local before = context_before_cursor(winid, size)
  local after = context_after_cursor(winid, size)
  if #before == 0 then
    before = { "" }
  end
  if #after == 0 then
    after = { "" }
  end

  local bufnr = vim.api.nvim_win_get_buf(winid)
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })

  local lines = {}

  if filename_tag ~= "" then
    local filename = vim.api.nvim_buf_get_name(bufnr)
    if filename ~= nil then
      table.insert(lines, { filename_tag .. filename })
    end
  end
  if filetype_tag ~= "" then
    table.insert(lines, { filetype_tag .. filetype })
  end

  if not reverse then

    before[1] = before_cursor_tag .. before[1]
    after[#after] = after[#after] .. after_cursor_tag
    local middle = table.remove(before) .. cursor_position_tag .. table.remove(after, 1)

    for _,line in ipairs(before) do
      table.insert(lines, line)
    end
    table.insert(lines, middle)
    for _,line in ipairs(after) do
      table.insert(lines, line)
    end
  else
    after[1] = after_cursor_tag .. after[1]
    before[1] = before_cursor_tag .. before[1]
    before[#before] = before[#before] .. cursor_position_tag

    for _,line in ipairs(after) do
      table.insert(lines, line)
    end
    for _,line in ipairs(before) do
      table.insert(lines, line)
    end
  end

  return {
    {
      role = "Input",
      lines = lines,
    },
  }
end


return {
  context_before_cursor = context_before_cursor,
  context_after_cursor = context_after_cursor,
  template_filetype_and_context = template_filetype_and_context,
}
