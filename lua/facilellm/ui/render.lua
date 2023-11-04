local util = require("facilellm.util")

---@class FacileLLM.RenderState
---@field msg FacileLLM.MsgIndex index of the last rendered message
---@field line number index of the last rendered line
---@field char number index of the last rendered character
---@field lines_total number total number of lines rendered
---@field highlight_receiving FacileLLM.RenderHighlight?
---@field folded table<FacileLLM.MsgIndex,WinId[]> table of folded messages

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

---@param conv FacileLLM.Conversation
---@param mx FacileLLM.MsgIndex
---@param render_state FacileLLM.RenderState?
---@return {[1]: number, [2]: number}?
local fold_message_range = function (conv, mx, render_state)
  if render_state and render_state.msg < mx then
    return
  end

  local s = 1
  for mxx = 1,mx-1 do
    s = s + 1 + #conv[mxx].lines
  end

  local e
  if render_state and render_state.msg == mx then
    e = s + render_state.line
  else
    e = s + #conv[mx].lines
  end

  return {s,e}
end

---@param conv FacileLLM.Conversation
---@param mx FacileLLM.MsgIndex
---@param winid WinId
---@param render_state FacileLLM.RenderState
---@return nil
local fold_message = function (conv, mx, winid, render_state)
  if mx < #conv then
    return
  end

  if not render_state.folded[mx] then
    render_state.folded[mx] = { winid }
    local fse = fold_message_range(conv, mx, render_state)
    if fse then
      local fs,fe = unpack(fse)
      util.create_fold(winid, fs, fe)
    end
  else
    for _,winid_folded in ipairs(render_state.folded[mx]) do
      if winid_folded == winid then
        local fse = fold_message_range(conv, mx, render_state)
        if fse then
          local fs,fe = unpack(fse)
          util.delete_fold(winid, fs)
          util.create_fold(winid, fs, fe)
        end
        return
      end
    end
    table.insert(render_state.folded[mx], winid)
  end
end

---@param conv FacileLLM.Conversation
---@param winid WinId
---@param render_state FacileLLM.RenderState
---@return nil
local fold_last_message = function (conv, winid, render_state)
  fold_message(conv, #conv, winid, render_state)
end

---@param conv FacileLLM.Conversation
---@param winid WinId
---@param render_state FacileLLM.RenderState
---@return nil
local fold_context_messages = function (conv, winid, render_state)
  for mx = 1,#conv do
    if conv[mx].role == "Context" then
      fold_message(conv, mx, winid, render_state)
    end
  end
end

---@param conv FacileLLM.Conversation
---@param mx FacileLLM.MsgIndex
---@param render_state FacileLLM.RenderState
---@param delete boolean
---@return nil
local update_folds = function (conv, mx, render_state, delete)
  if render_state.folded[mx] then
    for _,winid in ipairs(render_state.folded[mx]) do
      local fse = fold_message_range(conv, mx, render_state)
      if fse then
        local fs,fe = unpack(fse)
        if delete then
          util.delete_fold(winid, fs)
        end
        util.create_fold(winid, fs, fe)
      end
    end
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
    folded = {},
  }
end

---@param msg_map table<FacileLLM.MsgIndex, FacileLLM.MsgIndex>
---@param bufnr BufNr
---@param render_state FacileLLM.RenderState
---@return nil
local clear_conversation = function (msg_map, bufnr, render_state)
  render_state.msg = 0
  render_state.line = 0
  render_state.char = 0
  render_state.lines_total = 0

  if render_state.highlight_receiving then
    end_highlight_msg_receiving(bufnr, render_state)
  end

  local folded_mapped = {}
  for mx,winids in pairs(render_state.folded) do
    if msg_map[mx] then
      folded_mapped[msg_map[mx]] = winids
    end
  end
  render_state.folded = folded_mapped

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, {})
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

    create_highlight_role(bufnr, 0, string.len(msg.role)+1)
    create_highlight_msg_receiving(bufnr, render_state, mx, msg)
    update_folds(conv, mx, render_state, false)

    render_state.lines_total = 1 + #msg.lines

    render_state.msg = 1
    render_state.line = #msg.lines
    render_state.char = msg.lines and string.len(msg.lines[#msg.lines])

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

      update_highlight_msg_receiving(bufnr, render_state, msg)
      update_folds(conv, mx, render_state, true)

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

    create_highlight_role(bufnr, render_state.lines_total, string.len(msg.role)+1)
    create_highlight_msg_receiving(bufnr, render_state, mx, msg)
    update_folds(conv, mx, render_state, false)

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


return {
  create_state = create_state,
  render_conversation = render_conversation,
  clear_conversation = clear_conversation,
  start_highlight_msg_receiving = start_highlight_msg_receiving,
  end_highlight_msg_receiving = end_highlight_msg_receiving,
  fold_message = fold_message,
  fold_last_message = fold_last_message,
  fold_context_messages = fold_context_messages,
}
