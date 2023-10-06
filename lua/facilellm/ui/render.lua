---@class RenderState
---@field msg number index of the last rendered message
---@field line number index of the last rendered line
---@field char number index of the last rendered character


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
    local msg = conv[1]
    -- The very first line, when inserted needs to overwrite the initial one.
    vim.api.nvim_buf_set_lines(bufnr, -2, -1, false, {msg.role .. ":"})
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, msg.lines)
    render_state.msg = 1
    render_state.line = #msg.lines
    render_state.char = msg.lines and string.len(msg.lines[#msg.lines])

  else
    -- Render the remainder of the last rendered line, if it was extended.
    local msg = conv[render_state.msg]
    do
      local line = msg.lines[render_state.line]
      if render_state.char ~= string.len(line) then
        -- NOTE: By replacing the line, we discard marks, but since we are
        -- updating the line this seems acceptable.
        vim.api.nvim_buf_set_lines(bufnr, -2, -1, false, {line})
      end
    end

    -- Render new lines in the last rendered message, if it was extended.
    if render_state.line ~= #msg.lines then
      local new_lines = {}
      for lx = render_state.line+1, #msg.lines do
        table.insert(new_lines, msg.lines[lx])
      end
      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, new_lines)
    end
  end

  -- Render new messages
  for mx = render_state.msg+1, #conv do
    local msg = conv[mx]
    -- NOTE: This requires the role to be completely revealed, since we write
    -- it immediately when inserting a new message.
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {msg.role .. ":"})
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, msg.lines)
  end

  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  -- Track last rendered part of the conversation.
  render_state.msg = #conv
  local msg = conv[render_state.msg]
  render_state.line = #msg.lines
  local line = msg.lines[render_state.line]
  render_state.char = line and string.len(line)
end


return {
  conversation = conversation,
}
