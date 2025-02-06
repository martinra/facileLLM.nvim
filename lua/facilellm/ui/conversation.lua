local config = require("facilellm.config")
local ui_common = require("facilellm.ui.common")
local util = require("facilellm.util")


---@param sessionid FacileLLM.SessionId
---@param name string
---@return BufNr
local create_buffer = function (sessionid, name)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, name)

  vim.api.nvim_set_option_value("buftype",    "nofile",                  { buf = bufnr })
  vim.api.nvim_set_option_value("filetype",   "facilellm-conversation",  { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile",   false,                     { buf = bufnr })
  vim.api.nvim_set_option_value("buflisted",  false,                     { buf = bufnr })
  vim.api.nvim_set_option_value("bufhidden",  "hide",                    { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", false,                     { buf = bufnr })

  ui_common.buf_set_session(bufnr, sessionid)
  ui_common.buf_set_is_conversation(bufnr)

  return bufnr
end

---@param winid WinId
---@return nil
local fold_messages = function (winid)
  if not config.opts.interface.fold_instruction
    and not config.opts.interface.fold_context
    and not config.opts.interface.fold_example then
    vim.api.nvim_set_option_value("foldenable", false, { win = winid })
    return
  end

  local hlroleexpr = "'^\\("
  if config.opts.interface.fold_instruction then
    hlroleexpr = hlroleexpr .. config.opts.naming.role_display.instruction
  end
  if config.opts.interface.fold_context then
    if config.opts.interface.fold_instruction then
      hlroleexpr = hlroleexpr .. "\\|"
    end
    hlroleexpr = hlroleexpr .. config.opts.naming.role_display.context
  end
  if config.opts.interface.fold_context then
    if config.opts.interface.fold_instruction then
      hlroleexpr = hlroleexpr .. "\\|"
    end
    hlroleexpr = hlroleexpr .. config.opts.naming.role_display.file_context
  end
  if config.opts.interface.fold_example then
    if config.opts.interface.fold_instruction
      or config.opts.interface.fold_context then
      hlroleexpr = hlroleexpr .. "\\|"
    end
    hlroleexpr = hlroleexpr .. config.opts.naming.role_display.example
  end
  hlroleexpr = hlroleexpr .. "\\)$'"

  local allroleexpr = "'^\\("
  allroleexpr = allroleexpr .. config.opts.naming.role_display.instruction
  allroleexpr = allroleexpr .. "\\|"
  allroleexpr = allroleexpr .. config.opts.naming.role_display.context
  allroleexpr = allroleexpr .. "\\|"
  allroleexpr = allroleexpr .. config.opts.naming.role_display.file_context
  allroleexpr = allroleexpr .. "\\|"
  allroleexpr = allroleexpr .. config.opts.naming.role_display.example
  allroleexpr = allroleexpr .. "\\|"
  allroleexpr = allroleexpr .. config.opts.naming.role_display.input
  allroleexpr = allroleexpr .. "\\|"
  allroleexpr = allroleexpr .. config.opts.naming.role_display.llm
  allroleexpr = allroleexpr .. "\\)$'"

  local foldexpr = ""
  foldexpr = foldexpr .. "getline(v:lnum)=~"
  foldexpr = foldexpr .. hlroleexpr
  foldexpr = foldexpr .. "?'>1':"
  foldexpr = foldexpr .. "getline(v:lnum+1)=~"
  foldexpr = foldexpr .. allroleexpr
  foldexpr = foldexpr .. "?'<1':'='"

  vim.api.nvim_set_option_value("foldenable", true,   { win = winid })
  vim.api.nvim_set_option_value("foldmethod", "expr", { win = winid })
  vim.api.nvim_set_option_value("foldexpr", foldexpr, { win = winid })
end

---@param bufnr BufNr
---@return WinId
local create_window = function (bufnr)
  local split_modifier = util.win_vsplit_modifier(
    config.opts.interface.layout_relative,
    config.opts.interface.layout_direction
  )
  vim.cmd(string.format("noau %s vsplit", split_modifier))
  local winid = vim.api.nvim_get_current_win()

  if config.opts.interface.width ~= 0 then
    vim.api.nvim_win_set_width(winid, config.opts.interface.width)
  end

  fold_messages(winid)

  vim.api.nvim_win_set_buf(winid, bufnr)

  return winid
end

---@param bufnr BufNr
---@param winid WinId
---@return nil
local follow = function (bufnr, winid)
  local nlines = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_win_set_cursor(winid, {nlines, 0})
end

---@param _ BufNr
---@return nil
local on_complete_query = function (_)
end


return {
  create_buffer = create_buffer,
  create_window = create_window,
  follow = follow,
  on_complete_query = on_complete_query,
}
