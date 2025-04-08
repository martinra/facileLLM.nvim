---@class FacileLLM.RenderState
---@field pos FacileLLM.RenderState.Position
---@field last_displayed_mx FacileLLM.MsgIndex
---@field offsets integer[]
---@field offset_total integer total number of lines rendered
---@field highlight_receiving FacileLLM.RenderState.HighlightReceiving?
---@field prune_extmarks table<FacileLLM.MsgIndex, integer>

---@class FacileLLM.RenderState.Position
---@field mx FacileLLM.MsgIndex index of the last rendered message
---@field line integer index of the last rendered line
---@field char integer index of the last rendered character

---@class FacileLLM.RenderState.HighlightReceiving
---@field mx FacileLLM.MsgIndex
---@field extmark integer?


local config = require("facilellm.config")
local message = require("facilellm.session.message")


---@param role FacileLLM.MsgRole
---@return string
local role_display = function (role)
  if role == "Instruction" then
    return config.opts.naming.role_display.instruction
  elseif role == "Context" then
    return config.opts.naming.role_display.context
  elseif role == "FileContext" then
    return config.opts.naming.role_display.file_context
  elseif role == "Example" then
    return config.opts.naming.role_display.example
  elseif role == "Input" then
    return config.opts.naming.role_display.input
  elseif role == "LLM" then
    return config.opts.naming.role_display.llm
  else
    error("unreachable role " .. vim.inspect(role))
  end
end

---@param conv FacileLLM.Conversation
---@return string[] lines
local preview_conversation = function (conv)
  local lines = {}

  for mx = 1, #conv do
    local msg = conv[mx]
    if not message.ispruned(msg) then
      -- Add newline before role display, except for the first message
      if mx > 1 then
        table.insert(lines, "")
      end
      table.insert(lines, role_display(msg.role))
      -- Add newline after role display
      table.insert(lines, "")
      for _,l in ipairs(msg.lines) do
        table.insert(lines, l)
      end
    end
  end

  return lines
end

---This assumes that the message is displayed.
---@param mx FacileLLM.MsgIndex
---@param render_state FacileLLM.RenderState
---@return integer
---@return integer
local get_message_start = function (mx, render_state)
  local row = render_state.offsets[mx]
  local col = 0
  return row, col
end

---Following the convention of extmarks, we return 0-based inclusive row
---indices.
---This assumes that the message is displayed.
---@param mx FacileLLM.MsgIndex
---@param msg FacileLLM.Message
---@param render_state FacileLLM.RenderState
---@return integer
---@return integer
---@return integer
---@return integer
local get_message_range = function (mx, msg, render_state)
  local row, col = get_message_start(mx, render_state)
  local end_row, end_col
  --  Role displays are padded by the blank lines except for the first one,
  --  which only has a trailing one. This means that in general every message
  --  receives two extra lines, except for the last rendered one which only
  --  receives one.
  if mx == render_state.pos.mx then
    end_row = row + 1 + render_state.pos.line
    end_col = render_state.pos.char
  elseif mx == render_state.last_displayed_mx then
    end_row = row + 1 + #msg.lines
    -- The last line contains text, except if there is no text
    if #msg.lines ~= 0 then
      end_col = string.len(msg.lines[#msg.lines])
    else
      end_col = 0
    end
  else
    end_row = row + 2 + #msg.lines
    -- The last line is always an empty one that originates from padding.
    end_col = 0
  end
  return row, col, end_row, end_col
end

---Following the convention of extmarks, we return 0-based inclusive row
---indices.
---This assumes that the message is displayed.
local get_role_range = function (mx, msg, render_state)
  -- See get_message_range for a description of padding lines.
  local row, col = get_message_start(mx, render_state)
  local end_row, end_col = row, string.len(role_display(msg.role))
  return row, col, end_row, end_col
end

---@return integer
local get_namespace_highlight_role = function ()
  return vim.api.nvim_create_namespace("facilellm-highlight-role")
end

---@return integer
local get_namespace_highlight_receiving = function ()
  return vim.api.nvim_create_namespace("facilellm-highlight-receiving")
end

local get_namespace_highlight_pruned = function ()
  return vim.api.nvim_create_namespace("facilellm-highlight-pruned")
end

---This assumes that the message is displayed.
---@param bufnr BufNr
---@param mx FacileLLM.MsgIndex
---@param msg FacileLLM.Message
---@param render_state FacileLLM.RenderState
---@return nil
local set_highlight_role = function (bufnr, mx, msg, render_state)
  local row, col, end_row, end_col = get_role_range(mx, msg, render_state)
  local ns = get_namespace_highlight_role()
  vim.api.nvim_buf_set_extmark(bufnr, ns,
    row, col,
    {
      end_row = end_row,
      end_col = end_col,
      hl_group = "FacileLLMRole",
    })
end

---This assumes that the message is displayed.
---@param bufnr BufNr
---@param mx FacileLLM.MsgIndex
---@param msg FacileLLM.Message
---@param render_state FacileLLM.RenderState
---@return nil
local set_highlight_receiving = function (bufnr, mx, msg, render_state)
  local row, col, end_row, end_col = get_message_range(mx, msg, render_state)
  local ns = get_namespace_highlight_receiving()
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

---This assumes that the message is displayed.
---@param bufnr BufNr
---@param mx FacileLLM.MsgIndex
---@param msg FacileLLM.Message
---@param render_state FacileLLM.RenderState
---@return nil
local set_highlight_pruned = function (bufnr, mx, msg, render_state)
  local row, col, end_row, end_col = get_message_range(mx, msg, render_state)
  local ns = get_namespace_highlight_pruned()
  if render_state.prune_extmarks[mx] then
    vim.api.nvim_buf_set_extmark(bufnr, ns,
      row, col,
      {
        id = render_state.prune_extmarks[mx],
        end_row = end_row,
        end_col = end_col,
        hl_group = "FacileLLMMsgPruned",
      })
  else
    render_state.prune_extmarks[mx] =
      vim.api.nvim_buf_set_extmark(bufnr, ns,
        row, col,
        {
          end_row = end_row,
          end_col = end_col,
          hl_group = "FacileLLMMsgPruned",
        })
  end
end

---This assumes that the message is displayed.
---@param bufnr BufNr
---@param mx FacileLLM.MsgIndex
---@param render_state FacileLLM.RenderState
---@return nil
local del_highlight_pruned = function (bufnr, mx, render_state)
  if render_state.prune_extmarks[mx] then
    local ns = get_namespace_highlight_pruned()
    vim.api.nvim_buf_del_extmark(bufnr, ns, render_state.prune_extmarks[mx])
    render_state.prune_extmarks[mx] = nil
  end
end

---@param conv FacileLLM.Conversation
---@param render_state FacileLLM.RenderState
---@return nil
local start_highlight_receiving = function (conv, render_state)
  render_state.highlight_receiving = {
    mx = #conv + 1,
    extmark = nil,
  }
end

---@param bufnr BufNr
---@param render_state FacileLLM.RenderState
---@return nil
local end_highlight_receiving = function (bufnr, render_state)
  render_state.highlight_receiving = nil
  local ns = get_namespace_highlight_receiving()
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

---@return FacileLLM.RenderState
local create_state = function ()
  return {
    pos = {
      msg = 0, line = 0, char = 0
    },
    last_displayed_mx = 0,
    offsets = {},
    offset_total = 0,
    highlight_receiving = nil,
    prune_extmarks = {},
  }
end

---@param bufnr BufNr
---@param render_state FacileLLM.RenderState
---@return nil
local clear_conversation = function (bufnr, render_state)
  render_state.pos = {
    mx = 0, line = 0, char = 0
  }
  render_state.last_displayed_mx = 0
  render_state.offsets = {}
  render_state.offset_total = 0

  if render_state.highlight_receiving then
    end_highlight_receiving(bufnr, render_state)
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr})
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr})
end

---@param bufnr BufNr
---@param conv FacileLLM.Conversation
---@param render_state FacileLLM.RenderState
---@return nil
local render_conversation = function (bufnr, conv, render_state)
  if #conv == 0 then
    return
  end

  local workaround_fold = false

  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr})

  for mx = render_state.pos.mx, #conv do
    local msg = conv[mx]
    if msg and not message.ispurged(msg) then
      if not render_state.offsets[mx] then
        render_state.offsets[mx] = render_state.offset_total
      end

      -- Render role
      if mx ~= render_state.pos.mx then
        if mx == 1 then
          -- The very first line in the buffer when inserted needs to overwrite the
          -- initial one. In that case, we do not include a leading blank line.
          vim.api.nvim_buf_set_lines(bufnr, -2, -1, false, {role_display(msg.role), ""})
          render_state.offset_total = render_state.offset_total + 2
        else
          -- Add a blank line before the role display (except for first message)
          vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {"", role_display(msg.role), ""})
          render_state.offset_total = render_state.offset_total + 3
          render_state.offsets[mx] = render_state.offsets[mx] + 1
        end

        if config.opts.interface.highlight_role then
          set_highlight_role(bufnr, mx, msg, render_state)
        end
      end

      -- Render lines
      if mx ~= render_state.pos.mx or render_state.pos.line == 0 then
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, msg.lines)
        render_state.offset_total = render_state.offset_total + #msg.lines
      else
        -- Render the remainder of the last rendered line, if it was extended.
        local line = msg.lines[render_state.pos.line]
        if render_state.pos.char ~= string.len(line) then
          local pos_line
          if mx == 1 then
            pos_line = render_state.offsets[mx]+1+render_state.pos.line
          else
            pos_line = render_state.offsets[mx]+2+render_state.pos.line
          end
          vim.api.nvim_buf_set_text(bufnr,
            pos_line, render_state.pos.char,
            pos_line, render_state.pos.char,
            { string.sub(line, render_state.pos.char+1, string.len(line)) })
        end

        -- Render new lines in the last rendered message, if it was extended.
        if render_state.pos.line ~= #msg.lines then
          local new_lines = {}
          for lx = render_state.pos.line+1, #msg.lines do
            table.insert(new_lines, msg.lines[lx])
          end
          vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, new_lines)

          render_state.offset_total = render_state.offset_total + #new_lines
        end
      end

      render_state.pos.mx = mx
      render_state.pos.line = #msg.lines
      local line = msg.lines[#msg.lines]
      render_state.pos.char = line and string.len(line) or 0
      render_state.last_displayed_mx = mx

      if config.opts.feedback.highlight_message_while_receiving
        and render_state.highlight_receiving
        and render_state.highlight_receiving.mx == mx then
        set_highlight_receiving(bufnr, mx, msg, render_state)
      end
      if message.ispruned(msg) then
        set_highlight_pruned(bufnr, mx, msg, render_state)
      end

      if message.is_general_instruction_role(msg.role) then
        workaround_fold = true
      end
    end
  end

  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  if workaround_fold then
    vim.schedule( function ()
      local orig_winid = vim.api.nvim_get_current_win()
      local ui_common = require("facilellm.ui.common")
      for _,winid in pairs(vim.api.nvim_list_wins()) do
        if ui_common.win_get_session(winid) and ui_common.win_is_conversation(winid) then
          vim.api.nvim_set_current_win(winid)
          vim.api.nvim_feedkeys("zX", "nx", false)
        end
      end
      vim.api.nvim_set_current_win(orig_winid)
    end)
  end
end

---@param bufnr BufNr
---@param mx FacileLLM.MsgIndex
---@param msg FacileLLM.Message
---@param render_state FacileLLM.RenderState
---@return nil
local prune_message = function (bufnr, mx, msg, render_state)
  if not message.ispruned(msg) then
    vim.notify("only rendering pruned messages as such", vim.log.levels.WARN)
    return
  end
  if render_state.pos.mx >= mx then
    set_highlight_pruned(bufnr, mx, msg, render_state)
  end
end

---@param bufnr BufNr
---@param mx FacileLLM.MsgIndex
---@param msg FacileLLM.Message
---@param render_state FacileLLM.RenderState
---@return nil
local deprune_message = function (bufnr, mx, msg, render_state)
  if message.ispruned(msg) then
    vim.notify("only rendering unpruned messages as such", vim.log.levels.WARN)
    return
  end
  if render_state.offsets[mx] and render_state.pos.mx >= mx then
    del_highlight_pruned(bufnr, mx, render_state)
  end
end

---@param bufnr BufNr
---@param mx FacileLLM.MsgIndex
---@param msg FacileLLM.Message
---@param render_state FacileLLM.RenderState
---@return nil
local purge_message = function (bufnr, mx, msg, render_state)
  if not message.ispurged(msg) then
    vim.notify("only rendering purged messages as such", vim.log.levels.WARN)
    return
  end

  -- In this case the message has not yet been rendered or is already purged.
  if render_state.pos.mx < mx or render_state.offsets[mx] == nil then
    return
  end
  if render_state.highlight_receiving and render_state.highlight_receiving.mx == mx then
    end_highlight_receiving(bufnr, render_state)
  end
  if render_state.prune_extmarks[mx] then
    del_highlight_pruned(bufnr, mx, render_state)
  end

  local row, _, row_end, _ = get_message_range(mx, msg, render_state)
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, row, row_end+1, false, {})
  local offset_reduction = row_end - row + 1
  -- If the last viewed message is purged then the preceeding padding line has
  -- to be removed as well. An exception is the first message, which is not
  -- preceeded by such a line.
  if render_state.last_displayed_mx == mx and mx ~= 1 then
    vim.api.nvim_buf_set_lines(bufnr, row-1, row, false, {})
    offset_reduction = offset_reduction + 1
  end
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  if render_state.last_displayed_mx == mx then
    for ix = mx-1,1,-1 do
      if render_state.offsets[ix] ~= nil then
        render_state.last_displayed_mx = ix
        goto break_set_last_displayed_mx
      end
    end
    render_state.last_displayed_mx = 0
    ::break_set_last_displayed_mx::
  end

  render_state.offset_total = render_state.offset_total - offset_reduction
  render_state.offsets[mx] = nil
  for ox,_ in pairs(render_state.offsets) do
    if ox > mx then
      render_state.offsets[ox] = render_state.offsets[ox] - offset_reduction
    end
  end
end

---@param row integer 0-based
---@param conv FacileLLM.Conversation
---@param render_state FacileLLM.RenderState
---@return integer
local get_message_index = function (row, conv, render_state)
  -- Iterating via pairs skips the offsets that are set to nil.
  for mx,_ in pairs(render_state.offsets) do
    local mrow, _, end_mrow, _ = get_message_range(mx, conv[mx], render_state)
    if mrow <= row and row <= end_mrow then
      return mx
    end
  end
  error("Row not contained in any message")
end


return {
  create_state = create_state,
  render_conversation = render_conversation,
  preview_conversation = preview_conversation,
  clear_conversation = clear_conversation,
  start_highlight_receiving = start_highlight_receiving,
  end_highlight_receiving = end_highlight_receiving,
  prune_message = prune_message,
  deprune_message = deprune_message,
  purge_message = purge_message,
  get_message_index = get_message_index,
}
