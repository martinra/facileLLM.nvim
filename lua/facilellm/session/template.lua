---@alias FacileLLM.Template function(WinId): FacileLLM.Conversation

---@class FacileLLM.Template.ContextTags
---@field before_cursor_tag string
---@field after_cursor_tag string 
---@field cursor_position_tag string
---@field filetype_tag string

---@class FacileLLM.Template.RegisterTags
---@field begin_tag string
---@field end_tag string

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
  lines[#lines] = string.sub(lines[#lines], 1, c+1)
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
  lines[1] = string.sub(lines[1], c+2)
  return lines
end

---@param winid WinId
---@param tags FacileLLM.Template.ContextTags
---@param context_size integer?
---@return FacileLLM.Conversation
local template_filetype_and_context = function (winid, tags, context_size)
  local before_cursor_tag = tags.before_cursor_tag
  local after_cursor_tag = tags.after_cursor_tag
  local cursor_position_tag = tags.cursor_position_tag
  local filetype_tag = tags.filetype_tag

  local before = context_before_cursor(winid, context_size)
  before[1] = before_cursor_tag .. before[1]
  before[#before] = before[#before] .. cursor_position_tag
  local after = context_after_cursor(winid, context_size)
  after[1] = after_cursor_tag .. after[1]


  local bufnr = vim.api.nvim_win_get_buf(winid)
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })

  local lines = { filetype_tag .. filetype }
  for _,line in ipairs(after) do
    table.insert(lines, line)
  end
  for _,line in ipairs(before) do
    table.insert(lines, line)
  end
  table.insert(lines, "```")
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
