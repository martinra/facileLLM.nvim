local config = require("facilellm.config")
local message = require("facilellm.session.message")
local session = require("facilellm.session")
local ui_common = require("facilellm.ui.common")
local ui_conversation = require("facilellm.ui.conversation")
local ui_input = require("facilellm.ui.input")
local ui_render = require("facilellm.ui.render")
local ui_select = require("facilellm.ui.select_session")
local util = require("facilellm.util")


---@class FacileLLM.SessionUI
---@field conv_bufnr BufNr
---@field input_bufnr BufNr
---@field render_state FacileLLM.RenderState
---@field follow_conversation_flags table<WinId,boolean>
---@field pending_insertion_feedback FacileLLM.SessionUI.PendingInsertionFeedback?

---@class FacileLLM.SessionUI.PendingInsertionFeedback
---@field bufnr BufNr
---@field mark integer


---@type FacileLLM.SessionUI[]
local session_uis = {}


---@param sessionid FacileLLM.SessionId
---@return BufNr
local get_conversation_buffer = function (sessionid)
  return session_uis[sessionid].conv_bufnr
end

---@param sessionid FacileLLM.SessionId
---@return BufNr
local get_input_buffer = function (sessionid)
  return session_uis[sessionid].input_bufnr
end

---@param sessionid FacileLLM.SessionId
---@return WinId?
local get_some_conversation_window = function (sessionid)
  local bufnr = get_conversation_buffer(sessionid)
  for _,winid in pairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(winid) == bufnr then
      return winid
    end
  end
end

---@param sessionid FacileLLM.SessionId
---@return WinId?
local get_some_input_window = function (sessionid)
  local bufnr = get_input_buffer(sessionid)
  for _,winid in pairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(winid) == bufnr then
      return winid
    end
  end
end

---@param sessionid FacileLLM.SessionId
---@return FacileLLM.RenderState
local get_render_state = function (sessionid)
  return session_uis[sessionid].render_state
end

---@param name string
---@return string
local conversation_buffer_name = function (name)
  return config.opts.naming.conversation_buffer_prefix .. " " .. name
end

---@param name string
---@return string
local input_buffer_name = function (name)
  return config.opts.naming.input_buffer_prefix .. " " .. name
end

---@param sessionid FacileLLM.SessionId
---@param winid WinId
---@return nil
local follow_conversation = function (sessionid, winid)
  session_uis[sessionid].follow_conversation_flags[winid] = true
end

---@param sessionid FacileLLM.SessionId
---@param winid WinId
---@return nil
local unfollow_conversation = function (sessionid, winid)
  session_uis[sessionid].follow_conversation_flags[winid] = false
end

---@param sessionid FacileLLM.SessionId
---@param winid WinId
---@return boolean
local does_follow_conversation = function (sessionid, winid)
  return session_uis[sessionid].follow_conversation_flags[winid]
end

---@param sessionid FacileLLM.SessionId
---@return WinId
local create_conversation_win = function (sessionid)
  local bufnr = get_conversation_buffer(sessionid)
  local conv_winid = ui_conversation.create_window(bufnr)
  follow_conversation(sessionid, conv_winid)
  return conv_winid
end

---@param sessionid FacileLLM.SessionId
---@param conv_winid WinId?
---@return WinId
local create_input_win = function (sessionid, conv_winid)
  local bufnr = get_input_buffer(sessionid)
  return ui_input.create_window(bufnr, conv_winid)
end

---@param sessionid FacileLLM.SessionId
---@return nil
local win_close_all_but_unique = function (sessionid)
  for _,winid in pairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(winid) then
      local sessionid__loc = ui_common.win_get_session(winid)
      if sessionid__loc ~= nil and sessionid__loc ~= sessionid then
        vim.api.nvim_win_close(winid, true)
      end
    end
  end
end

---@param sessionid FacileLLM.SessionId
---@return nil
local set_current_win_conversation_input = function (sessionid)
  -- We need to touch the session before creating any windows in order to avoid
  -- the WinNew autocmd to close them if unique_session is true.
  ui_select.touch(sessionid)

  local conv_winid = get_some_conversation_window(sessionid)
  if not conv_winid then
    conv_winid = create_conversation_win(sessionid)
  end

  local input_winid = get_some_input_window(sessionid)
  if not input_winid then
    input_winid = create_input_win(sessionid, conv_winid)
  end

  if config.opts.interface.unique_session then
    win_close_all_but_unique(sessionid)
  end
  vim.api.nvim_set_current_win(input_winid)
end

---@param sessionid FacileLLM.SessionId
---@return nil
local set_current_win_conversation = function (sessionid)
  if config.opts.interface.couple_conv_input_windows then
    set_current_win_conversation_input(sessionid)
    return
  end

  -- We need to touch the session before creating any windows in order to avoid
  -- the WinNew autocmd to close them if unique_session is true.
  ui_select.touch(sessionid)

  local conv_winid = get_some_conversation_window(sessionid)
  if not conv_winid then
    conv_winid = create_conversation_win(sessionid)
  end

  if config.opts.interface.unique_session then
    win_close_all_but_unique(sessionid)
  end
  vim.api.nvim_set_current_win(conv_winid)
  return conv_winid
end

---@param sessionid FacileLLM.SessionId
---@return nil
local set_current_win_input = function (sessionid)
  if config.opts.interface.couple_conv_input_windows then
    set_current_win_conversation_input(sessionid)
    return
  end

  -- We need to touch the session before creating any windows in order to avoid
  -- the WinNew autocmd to close them if unique_session is true.
  ui_select.touch(sessionid)

  local input_winid = get_some_input_window(sessionid)
  if not input_winid then
    input_winid = create_input_win(sessionid)
  end

  if config.opts.interface.unique_session then
    win_close_all_but_unique(sessionid)
  end
  vim.api.nvim_set_current_win(input_winid)
  return input_winid
end

---@return integer
local get_namespace_pending_insertion = function ()
  return vim.api.nvim_create_namespace("facilellm-pending-insertion")
end

---@param sessionid FacileLLM.SessionId
---@param row integer
---@return nil
local set_pending_insertion_feedback = function (sessionid, bufnr, row)
  if not config.opts.feedback.pending_insertion_feedback then
    return
  end
  if session_uis[sessionid].pending_insertion_feedback ~= nil then
    return
  end

  local ns = get_namespace_pending_insertion()
  local mark = vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0,
  {
    virt_text = { {config.opts.feedback.pending_insertion_feedback_message, "WarningMsg"} },
    virt_text_pos = "overlay"
  })

  session_uis[sessionid].pending_insertion_feedback = {
    bufnr = bufnr,
    mark = mark,
  }
end

---@param sessionid FacileLLM.SessionId
local del_pending_insertion_feedback = function (sessionid)
  if session_uis[sessionid].pending_insertion_feedback == nil then
    return
  end
  local bufnr = session_uis[sessionid].pending_insertion_feedback.bufnr
  local mark = session_uis[sessionid].pending_insertion_feedback.mark

  local ns = get_namespace_pending_insertion()
  vim.api.nvim_buf_del_extmark(bufnr, ns, mark)

  session_uis[sessionid].pending_insertion_feedback = nil
end

---@param sessionid FacileLLM.SessionId
---@param instruction ("delete"| "preserve"| "combine")
---@param context ("delete"| "preserve"| "combine")
---@param example ("delete"| "preserve"| "combine")
---@return nil
local clear_conversation = function (sessionid, instruction, context, example)
  if not session.clear_conversation(sessionid, instruction, context, example) then
    return
  end
  local conv = session.get_conversation(sessionid)
  local conv_bufnr = get_conversation_buffer(sessionid)
  local render_state = get_render_state(sessionid)
  ui_render.clear_conversation(conv_bufnr, render_state)
  ui_render.render_conversation(conv_bufnr, conv, render_state)
end

---@param sessionid FacileLLM.SessionId
---@return nil
local render_conversation = function (sessionid)
  local conv = session.get_conversation(sessionid)
  local bufnr = get_conversation_buffer(sessionid)
  local render_state = get_render_state(sessionid)
  ui_render.render_conversation(bufnr, conv, render_state)
  for _,winid in pairs(vim.api.nvim_list_wins()) do
    if does_follow_conversation(sessionid, winid) then
      ui_conversation.follow(bufnr, winid)
    end
  end
end

---@param sessionid FacileLLM.SessionId
---@param name string
---@return nil
local set_name = function (sessionid, name)
  name = session.set_name(sessionid, name)
  vim.api.nvim_buf_set_name(get_conversation_buffer(sessionid), conversation_buffer_name(name))
  vim.api.nvim_buf_set_name(get_input_buffer(sessionid), input_buffer_name(name))
end

---@param sessionid FacileLLM.SessionId
---@return nil
local delete = function (sessionid)
  ui_select.delete(sessionid)
  for _,winid in pairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(winid)
      and ui_common.win_get_session(winid) == sessionid then
      vim.api.nvim_win_close(winid, true)
    end
  end
  del_pending_insertion_feedback(sessionid)
  vim.api.nvim_buf_delete(session_uis[sessionid].conv_bufnr, {force = true})
  vim.api.nvim_buf_delete(session_uis[sessionid].input_bufnr, {force = true})
  session.delete(sessionid)
end

---@param sessionid FacileLLM.SessionId
---@return nil
local rename = function (sessionid)
  local cur_name = session.get_name(sessionid)
  vim.ui.input({prompt = "Rename session " .. cur_name .. ": "},
    function (name)
      set_name(sessionid, name)
    end
  )
end

---@param sessionid FacileLLM.SessionId
---@return nil
local set_buf_keymaps = function (sessionid)
  local ui_session = require("facilellm.ui.session")

  local conv_bufnr = get_conversation_buffer(sessionid)
  local input_bufnr = get_input_buffer(sessionid)


  if config.opts.interface.keymaps.delete_interaction ~= "" then
    vim.keymap.set("n", config.opts.interface.keymaps.delete_interaction,
      function () ui_session.clear_conversation(sessionid, "preserve", "preserve", "preserve") end,
      { buffer = conv_bufnr })
    vim.keymap.set("n", config.opts.interface.keymaps.delete_interaction,
      function () ui_session.clear_conversation(sessionid, "preserve", "preserve", "preserve") end,
      { buffer = input_bufnr })
  end

  if config.opts.interface.keymaps.delete_conversation ~= "" then
    vim.keymap.set("n", config.opts.interface.keymaps.delete_conversation,
      function () ui_session.clear_conversation(sessionid, "delete", "delete", "delete") end,
      { buffer = conv_bufnr })
    vim.keymap.set("n", config.opts.interface.keymaps.delete_conversation,
      function () ui_session.clear_conversation(sessionid, "delete", "delete", "delete") end,
      { buffer = input_bufnr })
  end

  if config.opts.interface.keymaps.delete_session ~= "" then
    vim.keymap.set("n", config.opts.interface.keymaps.delete_session,
      function () ui_session.delete(sessionid) end,
      { buffer = conv_bufnr })
    vim.keymap.set("n", config.opts.interface.keymaps.delete_session,
      function () ui_session.delete(sessionid) end,
      { buffer = input_bufnr })
  end

  if config.opts.interface.keymaps.fork_session ~= "" then
    vim.keymap.set("n", config.opts.interface.keymaps.fork_session,
      function () ui_session.fork(sessionid) end,
      { buffer = conv_bufnr })
    vim.keymap.set("n", config.opts.interface.keymaps.fork_session,
      function () ui_session.fork(sessionid) end,
      { buffer = input_bufnr })
  end

  if config.opts.interface.keymaps.rename_session ~= "" then
    vim.keymap.set("n", config.opts.interface.keymaps.rename_session,
      function () ui_session.rename(sessionid) end,
      { buffer = conv_bufnr })
    vim.keymap.set("n", config.opts.interface.keymaps.rename_session,
      function () ui_session.rename(sessionid) end,
      { buffer = input_bufnr })
  end

  if config.opts.interface.keymaps.input_confirm ~= "" then
    ui_input.set_confirm_keymap(input_bufnr,
      "n", config.opts.interface.keymaps.input_confirm, function (lines)
      ui_session.add_input_message_and_query(sessionid, lines)
    end)
  end
  if config.opts.interface.keymaps.input_instruction ~= "" then
    ui_input.set_instruction_keymap(input_bufnr,
      "n", config.opts.interface.keymaps.input_instruction, function (lines)
      ui_session.add_message(sessionid, "Instruction", lines)
    end)
  end
  if config.opts.interface.keymaps.input_context ~= "" then
    ui_input.set_context_keymap(input_bufnr,
      "n", config.opts.interface.keymaps.input_context, function (lines)
      ui_session.add_message(sessionid, "Context", lines)
    end)
  end
  if config.opts.interface.keymaps.input_example ~= "" then
    ui_input.set_example_keymap(input_bufnr,
      "n", config.opts.interface.keymaps.input_example, function (lines)
      ui_session.add_message(sessionid, "Example", lines)
    end)
  end

  if config.opts.interface.keymaps.requery ~= "" then
    vim.keymap.set("n", config.opts.interface.keymaps.requery,
      function () ui_session.requery(sessionid) end,
      { buffer = conv_bufnr })
  end
  if config.opts.interface.keymaps.requery ~= "" then
    vim.keymap.set("n", config.opts.interface.keymaps.requery,
      function () ui_session.requery(sessionid) end,
      { buffer = input_bufnr })
  end

  if config.opts.interface.keymaps.prune_message ~= "" then
    vim.keymap.set("n", config.opts.interface.keymaps.prune_message,
      function ()
        local conv = session.get_conversation(sessionid)
        local bufnr = ui_session.get_conversation_buffer(sessionid)
        local render_state = get_render_state(sessionid)

        local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
        local mx = ui_render.get_message_index(row-1, conv, render_state)
        if not mx then
          return
        end

        message.prune(conv[mx])
        ui_render.prune_message(bufnr, mx, conv[mx], render_state)
      end,
      { buffer = conv_bufnr })
  end
  if config.opts.interface.keymaps.deprune_message ~= "" then
    vim.keymap.set("n", config.opts.interface.keymaps.deprune_message,
      function ()
        local conv = session.get_conversation(sessionid)
        local bufnr = ui_session.get_conversation_buffer(sessionid)
        local render_state = get_render_state(sessionid)

        local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
        local mx = ui_render.get_message_index(row-1, conv, render_state)
        if not mx then
          return
        end

        message.deprune(conv[mx])
        ui_render.deprune_message(bufnr, mx, conv[mx], render_state)
      end,
      { buffer = conv_bufnr })
  end
  if config.opts.interface.keymaps.purge_message ~= "" then
    vim.keymap.set("n", config.opts.interface.keymaps.purge_message,
      function ()
        local conv = session.get_conversation(sessionid)
        local bufnr = ui_session.get_conversation_buffer(sessionid)
        local render_state = get_render_state(sessionid)

        local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
        local mx = ui_render.get_message_index(row-1, conv, render_state)
        if not mx then
          return
        end

        message.purge(conv[mx])
        ui_render.purge_message(bufnr, mx, conv[mx], render_state)
      end,
      { buffer = conv_bufnr })
  end
end

---@param sessionid FacileLLM.SessionId
---@param role FacileLLM.MsgRole
---@param lines string[]
---@return nil
local add_message = function (sessionid, role, lines)
  ui_select.touch(sessionid)
  session.add_message(sessionid, role, lines)
  vim.schedule(
    function ()
      render_conversation(sessionid)
    end)
end

---@param sessionid FacileLLM.SessionId
---@param conversation FacileLLM.Conversation
---@return nil
local append_conversation = function (sessionid, conversation)
  ui_select.touch(sessionid)
  session.append_conversation(sessionid, conversation)
  vim.schedule(
    function ()
      render_conversation(sessionid)
    end)
end

---@param sessionid FacileLLM.SessionId
---@param response_callback function?(): nil
---@return nil
local on_complete_query = function (sessionid, response_callback)
  local bufnr = get_conversation_buffer(sessionid)
  ui_render.end_highlight_receiving(bufnr, get_render_state(sessionid))
  ui_conversation.on_complete_query(bufnr)
  ui_input.on_complete_query(get_input_buffer(sessionid))

  local msg = session.get_last_llm_message(sessionid)
  if msg then
    local provider_config = session.get_provider_config(sessionid)
    for name,reg in pairs(provider_config.registers) do
      local text = message.postprocess(msg, reg)
      if text and string.len(text) ~= 0 then
        vim.fn.setreg(name, text, "l")
      end
    end

    if response_callback then
      response_callback(msg.lines)
    end
  end
end

---@param sessionid FacileLLM.SessionId
---@param response_callback function?(): nil
---@return nil
local query = function (sessionid, response_callback)
  ui_select.touch(sessionid)

  local conv = session.get_conversation(sessionid)
  local render_state = get_render_state(sessionid)
  ui_render.start_highlight_receiving(conv, render_state)
  session.query_provider(sessionid, render_conversation,
    function (sessionid__loc)
      on_complete_query(sessionid__loc, response_callback)
    end)
  vim.schedule(
    function ()
      render_conversation(sessionid)
    end)
end

---@param sessionid FacileLLM.SessionId
---@param lines string[]
---@param response_callback function?(): nil
---@return nil
local add_input_message_and_query = function (sessionid, lines, response_callback)
  session.add_message(sessionid, "Input", lines)
  query(sessionid, response_callback)
end

---@param sessionid FacileLLM.SessionId
---@param lines string[]
---@return nil
local add_input_message_query_and_insert = function (sessionid, lines)
  local bufnr = vim.api.nvim_get_current_buf()
  local row, _ = unpack(vim.api.nvim_win_get_cursor(0))

  set_pending_insertion_feedback(sessionid, bufnr, row-1)

  ---@param lines__loc string[]
  local response_callback = function (lines__loc)
    del_pending_insertion_feedback(sessionid)
    vim.api.nvim_buf_set_lines(bufnr, row-1, row, false, lines__loc)
  end

  add_input_message_and_query(sessionid, lines, response_callback)
end

---@param sessionid FacileLLM.SessionId
---@return nil
local requery = function (sessionid)
  local mx, msg = session.get_last_message_with_index(sessionid)
  if not msg or msg.role ~= "LLM" and msg.role ~= "Input" then
    return
  end
  ---@cast mx FacileLLM.MsgIndex

  local bufnr = get_conversation_buffer(sessionid)
  local render_state = get_render_state(sessionid)

  ui_select.touch(sessionid)
  if msg.role == "LLM" then
    message.purge(msg)
    ui_render.purge_message(bufnr, mx, msg, render_state)
  end
  query(sessionid)
end

---@param sessionid FacileLLM.SessionId
---@return nil
local set_buf_autocmds = function (sessionid)
  local conv_bufnr = get_conversation_buffer(sessionid)
  local input_bufnr = get_input_buffer(sessionid)

  if config.opts.interface.couple_conv_input_windows then
    vim.api.nvim_create_autocmd("WinClosed", {
      buffer = conv_bufnr,
      callback = function()
        local nmb_conv_wins = 0
        for _,winid in pairs(vim.api.nvim_list_wins()) do
          if ui_common.win_get_session(winid) == sessionid
            and ui_common.win_is_conversation(winid) then
            if nmb_conv_wins == 0 then
              nmb_conv_wins = 1
            else
              return
            end
          end
        end
        for _,winid in pairs(vim.api.nvim_list_wins()) do
          if ui_common.win_get_session(winid) == sessionid then
            vim.api.nvim_win_close(winid, true)
          end
        end
      end
    })
    vim.api.nvim_create_autocmd("WinClosed", {
      buffer = input_bufnr,
      callback = function()
        local nmb_input_wins = 0
        for _,winid in pairs(vim.api.nvim_list_wins()) do
          if ui_common.win_get_session(winid) == sessionid
            and not ui_common.win_is_conversation(winid) then
            if nmb_input_wins == 0 then
              nmb_input_wins = 1
            else
              return
            end
          end
        end
        for _,winid in pairs(vim.api.nvim_list_wins()) do
          if ui_common.win_get_session(winid) == sessionid then
            vim.api.nvim_win_close(winid, true)
          end
        end
      end
    })
  end

  if config.opts.interface.unique_session then
    vim.api.nvim_create_autocmd("WinNew", {
      buffer = conv_bufnr,
      callback = function()
        local most_recent_session = ui_select.get_most_recent()
        if most_recent_session == nil then
          ui_select.touch(sessionid)
        elseif most_recent_session ~= sessionid then
          win_close_all_but_unique(most_recent_session)
        end
      end
    })
    vim.api.nvim_create_autocmd("WinNew", {
      buffer = conv_bufnr,
      callback = function()
        local most_recent_session = ui_select.get_most_recent()
        if most_recent_session == nil then
          ui_select.touch(sessionid)
        elseif most_recent_session ~= sessionid then
          win_close_all_but_unique(most_recent_session)
        end
      end
    })
  end
end

---@param provider_config FacileLLM.Config.Provider
---@return FacileLLM.SessionId
local create = function (provider_config)
  local sessionid = session.create(provider_config)
  local name = session.get_name(sessionid)

  local sess = {
    conv_bufnr = ui_conversation.create_buffer(sessionid, conversation_buffer_name(name)),
    input_bufnr = ui_input.create_buffer(sessionid, input_buffer_name(name)),
    render_state = ui_render.create_state(),
    conversation_winids = {},
    follow_conversation_flags = {},
    input_winid = nil,
    input_conv_winid = nil,
  }
  session_uis[sessionid] = sess

  set_buf_autocmds(sessionid)
  set_buf_keymaps(sessionid)

  local conv = session.get_conversation(sessionid)
  ui_render.render_conversation(sess.conv_bufnr, conv, sess.render_state)

  return sessionid
end

---@param sessionid FacileLLM.SessionId
---@return FacileLLM.SessionId
local fork = function (sessionid)
  local provider_config = {
    name = session.fork_name_variant(session.get_name(sessionid)),
    conversation = util.deep_copy_values(session.get_conversation(sessionid))
  }
  provider_config =
    vim.tbl_deep_extend("keep", provider_config, session.get_provider_config(sessionid))
  return create(provider_config)
end


return {
  create                             = create,
  delete                             = delete,
  fork                               = fork,
  rename                             = rename,
  get_conversation_buffer            = get_conversation_buffer,
  get_input_buffer                   = get_input_buffer,
  get_some_conversation_window       = get_some_conversation_window,
  get_some_input_window              = get_some_input_window,
  follow_conversation                = follow_conversation,
  unfollow_conversation              = unfollow_conversation,
  set_current_win_conversation_input = set_current_win_conversation_input,
  set_current_win_conversation       = set_current_win_conversation,
  set_current_win_input              = set_current_win_input,
  clear_conversation                 = clear_conversation,
  render_conversation                = render_conversation,
  add_message                        = add_message,
  append_conversation                = append_conversation,
  query                              = query,
  add_input_message_and_query        = add_input_message_and_query,
  add_input_message_query_and_insert = add_input_message_query_and_insert,
  requery                            = requery,
}
