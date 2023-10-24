---@class RenderState
---@field msg number index of the last rendered message
---@field line number index of the last rendered line
---@field char number index of the last rendered character
---@field lines_total number total number of lines rendered
---@field highlight_receiving RenderHighlight?

---@class RenderHighlight
---@field msg number
---@field extmark number?


---@param bufnr number
---@return number
local buf_get_namespace_highlight_receiving = function (bufnr)
  return vim.api.nvim_create_namespace("facilellm-highlight-receiving" .. bufnr)
end

---@return string
local receiving_hl_group = function ()
  return "WarningMsg"
end

---@param bufnr number
---@param render_state RenderState
---@param mx number message index
---@param msg Message
---@return nil
local start_highlight_msg_receiving = function (bufnr, render_state, mx, msg)
  if render_state.highlight_receiving and render_state.highlight_receiving.msg == mx then
    local ns = buf_get_namespace_highlight_receiving(bufnr)
    local row = render_state.lines_total
    local col = 0
    local end_row = render_state.lines_total + #msg.lines
    local end_col
    if #msg.lines == 0 then
      end_col = string.len(msg.role .. ":")
    else
      end_col = string.len(msg.lines[#msg.lines])
    end

    render_state.highlight_receiving.extmark =
      vim.api.nvim_buf_set_extmark(bufnr, ns,
        row, col,
        {
          end_row = end_row,
          end_col = end_col,
          hl_group = receiving_hl_group(),
        })
  end
end

---@param bufnr number
---@param render_state RenderState
---@param msg Message
---@return nil
local update_highlight_msg_receiving = function (bufnr, render_state, msg)
  if render_state.highlight_receiving and render_state.highlight_receiving.extmark then
    local ns = buf_get_namespace_highlight_receiving(bufnr)
    local id = render_state.highlight_receiving.extmark
    local row, col = unpack(vim.api.nvim_buf_get_extmark_by_id(bufnr, ns, id, {}))
    local end_row = render_state.lines_total-1
    local end_col = string.len(msg.lines[#msg.lines])

    vim.api.nvim_buf_set_extmark(bufnr, ns,
      row, col,
      {
        id = id,
        end_row = end_row,
        end_col = end_col,
        hl_group = receiving_hl_group(),
      })
  end
end

---@return table
local create_state = function ()
  return {
    msg = 0,
    line = 0,
    char = 0,
    lines_total = 0,
    highlight_receiving = nil,
  }
end

---@param conv Conversation
---@param bufnr number
---@param render_state RenderState
---@return nil
local conversation = function (conv, bufnr, render_state)
  if #conv == 0 then
    return
  end

  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)

  if render_state.msg == 0 then
    -- The very first line in the buffer when inserted needs to overwrite the
    -- initial one.
    local msg = conv[1]
    vim.api.nvim_buf_set_lines(bufnr, -2, -1, false, {msg.role .. ":"})
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, msg.lines)

    start_highlight_msg_receiving(bufnr, render_state, 1, msg)

    render_state.lines_total = 1 + #msg.lines

    render_state.msg = 1
    render_state.line = #msg.lines
    render_state.char = msg.lines and string.len(msg.lines[#msg.lines])

  else
    local msg = conv[render_state.msg]
    if #msg.lines > 0 then
      -- Render the remainder of the last rendered line, if it was extended.
      local line = msg.lines[render_state.line]
      if render_state.char ~= string.len(line) then
        vim.api.nvim_buf_set_text(bufnr,
          render_state.lines_total-1, render_state.char,
          render_state.lines_total-1, render_state.char,
          { string.sub(line, render_state.char+1, string.len(line)) })
      end

      -- Render new lines in the last rendered message, if it was extended.
      if render_state.line ~= #msg.lines then
        local new_lines = {}
        for lx = render_state.line+1, #msg.lines do
          table.insert(new_lines, msg.lines[lx])
        end
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, new_lines)

        render_state.lines_total = render_state.lines_total + #new_lines
      end

      update_highlight_msg_receiving(bufnr, render_state, msg)

      render_state.line = #msg.lines
      render_state.char = msg.lines and string.len(msg.lines[#msg.lines])
    end
  end

  -- Render new messages
  for mx = render_state.msg+1, #conv do
    local msg = conv[mx]
    -- NOTE: This requires the role to be completely revealed, since we write
    -- it immediately when inserting a new message.
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {msg.role .. ":"})
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, msg.lines)

    start_highlight_msg_receiving(bufnr, render_state, mx, msg)

    render_state.lines_total = render_state.lines_total + 1 + #msg.lines
  end

  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  -- Track last rendered part of the conversation.
  render_state.msg = #conv
  local msg = conv[render_state.msg]
  render_state.line = #msg.lines
  local line = msg.lines[render_state.line]
  render_state.char = line and string.len(line) or 0
end

---@param conv Conversation
---@param render_state RenderState
---@return nil
local highlight_msg_receiving = function (conv, render_state)
  render_state.highlight_receiving = {
    msg = #conv + 1,
    extmark = nil,
  }
end

local end_highlight_msg_receiving = function (bufnr, render_state)
  render_state.highlight_receiving = nil
  local ns = buf_get_namespace_highlight_receiving(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

return {
  create_state = create_state,
  conversation = conversation,
  highlight_msg_receiving = highlight_msg_receiving,
  end_highlight_msg_receiving = end_highlight_msg_receiving,
}
