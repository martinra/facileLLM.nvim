---@class FacileLLM.RenderState
---@field msg FacileLLM.MsgIndex index of the last rendered message
---@field line number index of the last rendered line
---@field char number index of the last rendered character
---@field lines_total number total number of lines rendered
---@field highlight_receiving FacileLLM.RenderHighlight?

---@class FacileLLM.RenderHighlight
---@field msg FacileLLM.MsgIndex
---@field extmark number?


---@return string
local get_hl_group_receiving = function ()
  return "FacileLLMMsgReceiving"
end

---@return string
local get_hl_group_role = function ()
  return "FacileLLMRole"
end

---@return number
local buf_get_namespace_highlight_msg_receiving = function ()
  return vim.api.nvim_create_namespace("facilellm-highlight-msg-receiving")
end

---@return number
local buf_get_namespace_highlight_role = function ()
  return vim.api.nvim_create_namespace("facilellm-highlight-role")
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

---@param bufnr BufNr
---@param row number
---@param len number
---@return nil
local create_highlight_role = function (bufnr, row, len)
  local ns = buf_get_namespace_highlight_role()
  vim.api.nvim_buf_set_extmark(bufnr, ns,
    row, 0,
    {
      end_row = row,
      end_col = len,
      hl_group = get_hl_group_role(),
    })
end

---@param bufnr BufNr
---@param render_state FacileLLM.RenderState
---@param mx FacileLLM.MsgIndex
---@param msg FacileLLM.Message
---@return nil
local create_highlight_msg_receiving = function (bufnr, render_state, mx, msg)
  if render_state.highlight_receiving and render_state.highlight_receiving.msg == mx then
    local ns = buf_get_namespace_highlight_msg_receiving()
    local row = render_state.lines_total - #msg.lines
    local col = 0
    local end_row = render_state.lines_total
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
          hl_group = get_hl_group_receiving(),
        })
  end
end

---@param bufnr BufNr
---@param render_state FacileLLM.RenderState
---@param msg FacileLLM.Message
---@return nil
local update_highlight_msg_receiving = function (bufnr, render_state, msg)
  if render_state.highlight_receiving and render_state.highlight_receiving.extmark then
    local ns = buf_get_namespace_highlight_msg_receiving()
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
        hl_group = get_hl_group_receiving(),
      })
  end
end

---@return FacileLLM.RenderState
local create_state = function ()
  return {
    msg = 0,
    line = 0,
    char = 0,
    lines_total = 0,
    highlight_receiving = nil,
  }
end

---@param bufnr BufNr
---@param render_state FacileLLM.RenderState
---@return nil
local clear_conversation = function (bufnr, render_state)
  render_state.msg = 0
  render_state.line = 0
  render_state.char = 0
  render_state.lines_total = 0

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

  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)

  if render_state.msg == 0 then
    -- The very first line in the buffer when inserted needs to overwrite the
    -- initial one.
    local mx = 1
    local msg = conv[mx]
    vim.api.nvim_buf_set_lines(bufnr, -2, -1, false, {msg.role .. ":"})
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, msg.lines)

    render_state.lines_total = 1 + #msg.lines

    render_state.msg = 1
    render_state.line = #msg.lines
    render_state.char = msg.lines and string.len(msg.lines[#msg.lines])

    create_highlight_role(bufnr, 0, string.len(msg.role)+1)
    create_highlight_msg_receiving(bufnr, render_state, mx, msg)

  else
    local mx = render_state.msg
    local msg = conv[mx]
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

      render_state.line = #msg.lines
      render_state.char = msg.lines and string.len(msg.lines[#msg.lines])

      update_highlight_msg_receiving(bufnr, render_state, msg)
    end
  end

  -- Render new messages
  for mx = render_state.msg+1, #conv do
    local msg = conv[mx]
    -- NOTE: This requires the role to be completely revealed, since we write
    -- it immediately when inserting a new message.
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {msg.role .. ":"})
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, msg.lines)

    local role_line = render_state.lines_total
    render_state.lines_total = render_state.lines_total + 1 + #msg.lines

    render_state.msg = mx
    render_state.line = #msg.lines
    local line = msg.lines[#msg.lines]
    render_state.char = line and string.len(line) or 0

    create_highlight_role(bufnr, role_line, string.len(msg.role)+1)
    create_highlight_msg_receiving(bufnr, render_state, mx, msg)
  end

  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
end


return {
  create_state = create_state,
  render_conversation = render_conversation,
  clear_conversation = clear_conversation,
  start_highlight_msg_receiving = start_highlight_msg_receiving,
  end_highlight_msg_receiving = end_highlight_msg_receiving,
}
