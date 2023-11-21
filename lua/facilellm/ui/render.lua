local config = require("facilellm.config")


---@class FacileLLM.RenderState
---@field msg FacileLLM.MsgIndex index of the last rendered message
---@field line number index of the last rendered line
---@field char number index of the last rendered character
---@field offsets number[]
---@field offset_total number total number of lines rendered
---@field highlight_receiving FacileLLM.RenderState.HighlightReceiving?
---@field pruned table<FacileLLM.MsgIndex, FacileLLL.RenderState.PruneState>

---@class FacileLLM.RenderState.HighlightReceiving
---@field msg FacileLLM.MsgIndex
---@field extmark number?

---@class FacileLLL.RenderState.PruneState
---@field visible boolean


---@param role FacileLLM.MsgRole
---@return string
local role_display = function (role)
  if role == "Instruction" then
    return config.opts.naming.role_display.instruction
  elseif role == "Context" then
    return config.opts.naming.role_display.context
  elseif role == "Input" then
    return config.opts.naming.role_display.input
  elseif role == "LLM" then
    return config.opts.naming.role_display.llm
  else
    error("unreachable role dispatch")
  end
end

---@return number
local buf_get_namespace_highlight_role = function ()
  return vim.api.nvim_create_namespace("facilellm-highlight-role")
end

---@return number
local buf_get_namespace_highlight_msg_receiving = function ()
  return vim.api.nvim_create_namespace("facilellm-highlight-msg-receiving")
end

---@param bufnr BufNr
---@param row number
---@param len number
---@return nil
local set_highlight_role = function (bufnr, row, len)
  local ns = buf_get_namespace_highlight_role()
  vim.api.nvim_buf_set_extmark(bufnr, ns,
    row, 0,
    {
      end_row = row,
      end_col = len,
      hl_group = "FacileLLMRole",
    })
end

---@param bufnr BufNr
---@param render_state FacileLLM.RenderState
---@param mx FacileLLM.MsgIndex
---@param msg FacileLLM.Message
---@return nil
local set_highlight_msg_receiving = function (bufnr, render_state, mx, msg)
  if render_state.highlight_receiving and render_state.highlight_receiving.msg == mx then
    local row = render_state.offsets[mx-1] or 0
    local col = 0
    local end_row = render_state.offsets[mx] - 1
    local end_col
    if #msg.lines == 0 then
      end_col = string.len(role_display(msg.role))
    else
      end_col = string.len(msg.lines[#msg.lines])
    end

    local ns = buf_get_namespace_highlight_msg_receiving()
    if render_state.highlight_receiving.extmark then
      vim.api.nvim_buf_set_extmark(bufnr, ns,
        row, col,
        {
          id = render_state.highlight_receiving.extmark,
          end_row = end_row,
          end_col = end_col,
          hl_group = "FacileLLMMsgReceiving",
        })
    else
      render_state.highlight_receiving.extmark =
        vim.api.nvim_buf_set_extmark(bufnr, ns,
          row, col,
          {
            end_row = end_row,
            end_col = end_col,
            hl_group = "FacileLLMMsgReceiving",
          })
    end
  end
end

---@param conv FacileLLM.Conversation
---@param render_state FacileLLM.RenderState
---@return nil
local start_highlight_msg_receiving = function (conv, render_state)
  render_state.highlight_receiving = {
    msg = #conv + 1,
    extmark = nil,
  }
end

---@param bufnr BufNr
---@param render_state FacileLLM.RenderState
---@return nil
local end_highlight_msg_receiving = function (bufnr, render_state)
  render_state.highlight_receiving = nil
  local ns = buf_get_namespace_highlight_msg_receiving()
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

---@return FacileLLM.RenderState
local create_state = function ()
  return {
    msg = 1,
    line = 1,
    char = 0,
    offsets = {},
    offset_total = 0,
    highlight_receiving = nil,
    pruned = {},
  }
end

---@param bufnr BufNr
---@param render_state FacileLLM.RenderState
---@return nil
local clear_conversation = function (bufnr, render_state)
  render_state.msg = 0
  render_state.line = 0
  render_state.char = 0
  render_state.offsets = {}
  render_state.offset_total = 0

  if render_state.highlight_receiving then
    end_highlight_msg_receiving(bufnr, render_state)
  end

  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
end

---@param conv FacileLLM.Conversation
---@param bufnr BufNr
---@param render_state FacileLLM.RenderState
---@return nil
local render_conversation = function (conv, bufnr, render_state)
  if #conv == 0 then
    return
  end

  local workaround_fold = false

  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)

  -- Render the remained of the last rendered message
  do
    local mx = render_state.msg
    local msg = conv[mx]

    if msg and #msg.lines > 0 then
      -- Render the remainder of the last rendered line, if it was extended.
      local line = msg.lines[render_state.line]
      if render_state.char ~= string.len(line) then
        vim.api.nvim_buf_set_text(bufnr,
          render_state.offset_total-1, render_state.char,
          render_state.offset_total-1, render_state.char,
          { string.sub(line, render_state.char+1, string.len(line)) })
      end

      -- Render new lines in the last rendered message, if it was extended.
      if render_state.line ~= #msg.lines then
        local new_lines = {}
        for lx = render_state.line+1, #msg.lines do
          table.insert(new_lines, msg.lines[lx])
        end
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, new_lines)

        render_state.offset_total = render_state.offset_total + #new_lines
        render_state.offsets[mx] = render_state.offset_total
      end

      render_state.line = #msg.lines
      render_state.char = msg.lines and string.len(msg.lines[#msg.lines])

      if config.opts.feedback.highlight_message_while_receiving then
        set_highlight_msg_receiving(bufnr, render_state, mx, msg)
      end

      if msg.role == "Instruction" or msg.role == "Context" then
        workaround_fold = true
      end
    end
  end

  -- Render new messages
  for mx = render_state.msg+1, #conv do
    local msg = conv[mx]

    if render_state.offset_total == 0 then
      -- The very first line in the buffer when inserted needs to overwrite the
      -- initial one.
      vim.api.nvim_buf_set_lines(bufnr, -2, -1, false, {role_display(msg.role)})
    else
      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {role_display(msg.role)})
    end
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, msg.lines)

    local role_line = render_state.offset_total
    render_state.offset_total = render_state.offset_total + 1 + #msg.lines
    render_state.offsets[mx] = render_state.offset_total

    render_state.msg = mx
    render_state.line = #msg.lines
    local line = msg.lines[#msg.lines]
    render_state.char = line and string.len(line) or 0

    if config.opts.interface.highlight_role then
      set_highlight_role(bufnr, role_line, string.len(role_display(msg.role)))
    end
    if config.opts.feedback.highlight_message_while_receiving then
      set_highlight_msg_receiving(bufnr, render_state, mx, msg)
    end

    if msg.role == "Instruction" or msg.role == "Context" then
      workaround_fold = true
    end
  end

  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  -- HACK: We recompute all folds. Without this on 0.9.4 when creating from
  -- selection, they are seemingly never applied. This might not be neccessary
  -- once #18479 of github/neovim is applied (v0.10?).
  if workaround_fold then
    local orig_winid = vim.api.nvim_get_current_win()
    local ui_common = require("facilellm.ui.common")
    for _,winid in pairs(vim.api.nvim_list_wins()) do
      if ui_common.win_get_session(winid) and ui_common.win_is_conversation(winid) then
        vim.api.nvim_set_current_win(winid)
        vim.api.nvim_feedkeys("zx", "nx", false)
        vim.api.nvim_feedkeys("zc", "nx", false)
      end
    end
    vim.api.nvim_set_current_win(orig_winid)
  end
end

local prune_message = function (conv, mx, bufnr, render_state)
  if not render_state.pruned[mx] then
    render_state.pruned[mx] = {
      visible = true
    }
  end
end

local purge_message = function (conv, mx, bufnr, render_state)
  if not render_state.pruned[mx] then
    render_state.pruned[mx] = {
      visible = false
    }
  end
end


return {
  create_state = create_state,
  render_conversation = render_conversation,
  clear_conversation = clear_conversation,
  start_highlight_msg_receiving = start_highlight_msg_receiving,
  end_highlight_msg_receiving = end_highlight_msg_receiving,
  prune_message = prune_message,
  purge_message = purge_message,
}
