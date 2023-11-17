---@param relative ("editor"| "win")
---@param direction ("right"| "left")
---@return string
local win_vsplit_modifier = function (relative, direction)
  if relative == "editor" then
    if direction == "right" then
      return "botright"
    elseif direction == "left" then
      return "topleft"
    else
      error("unknown split direction " .. direction)
    end
  elseif relative == "win" then
    if direction == "right" then
      return "rightbelow"
    elseif direction == "left" then
      return "leftabove"
    else
      error("unknown split direction " .. direction)
    end
  else
    error("unknown value for relative: " .. relative)
  end
end

---@param cursor_position ("top"| "bottom")?
---@return string[]?
local get_visual_selection = function (cursor_position)
  if cursor_position then
    vim.api.nvim_feedkeys("o", "vx", false)
    local r1,_ = unpack(vim.api.nvim_win_get_cursor(0))
    vim.api.nvim_feedkeys("o", "vx", false)
    local r2,_ = unpack(vim.api.nvim_win_get_cursor(0))
    if (cursor_position == "top" and r1 < r2) or
       (cursor_position == "bottom" and r1 > r2) then
      vim.api.nvim_feedkeys("o", "vx", false)
    end
  end

  local mode = vim.fn.mode()
  local esckey = vim.api.nvim_replace_termcodes("<Esc>", true, true, true)
  vim.api.nvim_feedkeys(esckey, "nx", false)
  local _, rs, cs = unpack(vim.fn.getpos("'<"))
  local _, re, ce = unpack(vim.fn.getpos("'>"))

  if mode == "v" then
    return vim.api.nvim_buf_get_text(0, rs-1, cs-1, re-1, ce, {})
  elseif mode == "V" then
    return vim.api.nvim_buf_get_lines(0, rs-1, re, false)
  elseif mode == "" then
    local lines = vim.api.nvim_buf_get_lines(0, rs-1, re, false)
    local block = {}
    for _,l in ipairs(lines) do
      table.insert(block, string.sub(l, cs, ce))
    end
    return block
  end
end

---@return string[]
local substitute_visual_selection = function ()
  vim.api.nvim_feedkeys("s", "vx", false)
  local lines = {}
  for line in string.gmatch(vim.fn.getreg("1"), "[^\n]+") do
    table.insert(lines, line)
  end
  return lines
end

---@param winid WinId
---@param row_start number
---@param row_end number
---@return nil
local create_fold = function (winid, row_start, row_end)
  local winid_orig = vim.api.nvim_get_current_win()
  if winid ~= winid_orig then
    vim.api.nvim_set_current_win(winid)
  end
  vim.cmd(row_start .. "," .. row_end .. "fo")
  if winid ~= winid_orig then
    vim.api.nvim_set_current_win(winid_orig)
  end
end

---@param winid WinId
---@param row number
---@return nil
local delete_fold = function (winid, row)
  local winid_orig = vim.api.nvim_get_current_win()
  if winid_orig ~= winid then
    vim.api.nvim_set_current_win(winid)
  end

  local cursor_orig = vim.api.nvim_win_get_cursor(winid)
  vim.api.nvim_win_set_cursor(winid, {row,1})

  vim.api.nvim_feedkeys("zd", "nx", false)

  vim.api.nvim_win_set_cursor(winid, cursor_orig)
  if winid_orig ~= winid then
    vim.api.nvim_set_current_win(winid_orig)
  end
end


return {
  win_vsplit_modifier  = win_vsplit_modifier,
  get_visual_selection = get_visual_selection,
  substitute_visual_selection = substitute_visual_selection,
  create_fold          = create_fold,
  delete_fold          = delete_fold,
}
