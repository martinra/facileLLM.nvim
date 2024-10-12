local config = require("facilellm.config")
local provider = require("facilellm.provider")
local session = require("facilellm.session")
local ui_select = require("facilellm.ui.select_session")
local ui_session = require("facilellm.ui.session")
local util = require("facilellm.util")


---@return nil
local select_default_provider = function ()
  ui_select.select_provider(config.opts.providers,
    function (provider_config)
      provider.set_default_provider_config(provider_config.name)
    end,
    "Select default provider"
  )
end

---@param provider_config? FacileLLM.Config.Provider
---@return FacileLLM.SessionId
local create_from_provider = function (provider_config)
  provider_config = provider_config or provider.get_default_provider_config()
  return ui_session.create(provider_config)
end

---@params opts table? options passed through to telescope
---@return nil
local create_from_provider_selection = function (opts)
  ui_select.select_provider(config.opts.providers,
    function (provider_config)
      local sessionid = ui_session.create(provider_config)
      ui_session.set_current_win_conversation_input(sessionid)
    end,
    "Select provider to create new session from",
    opts
  )
end

---@params opts table? options passed through to telescope
---@return nil
local create_from_conversation_selection = function (opts)
  ui_select.select_conversation(config.opts.conversations,
    function (conversation)
      local provider_config = provider.get_default_provider_config()
      provider_config = util.deep_copy_values(provider_config)
      provider_config.conversation = util.deep_copy_values(conversation)
      local sessionid = ui_session.create(provider_config)
      ui_session.set_current_win_conversation_input(sessionid)
    end,
    "Select initial conversation of new session",
    opts
  )
end

---@params opts table? options passed through to telescope
---@return nil
local create_from_provider_conversation_selection = function (opts)
  ui_select.select_provider(config.opts.providers,
    function (provider_config)
      ui_select.select_conversation(config.opts.conversations,
        function (conversation)
          provider_config = util.deep_copy_values(provider_config)
          provider_config.conversation = util.deep_copy_values(conversation)
          local sessionid = ui_session.create(provider_config)
          ui_session.set_current_win_conversation_input(sessionid)
        end,
        "Select initial conversation of new session"
      )
    end,
    "Select provider to create new session from",
    opts
  )
end

---@params opts table? options passed through to telescope
---@return nil
local delete_from_selection = function (opts)
  ui_select.select_session(session.get_session_names(),
    function (sessionid)
      ui_session.delete(sessionid)
    end,
    "Select session to delete",
    opts
  )
end

---@params opts table? options passed through to telescope
---@return nil
local rename_from_selection = function (opts)
  ui_select.select_session(session.get_session_names(),
    function (sessionid)
      ui_session.rename(sessionid)
    end,
    "Select session to rename",
    opts
  )
end

---@params opts table? options passed through to telescope
---@return nil
local set_provider_from_selection = function (opts)
  ui_select.select_session(session.get_session_names(),
    function (sessionid)
      local name = session.get_name(sessionid)
      ui_select.select_provider(config.opts.providers,
        function (provider_config)
          session.set_provider(sessionid, provider_config)
        end,
        "Select provider for session " .. name,
        opts
      )
    end,
    "Select session to change provider of",
    opts
  )
end

---@param sessionid FacileLLM.SessionId?
---@return nil
local show = function (sessionid)
  sessionid = sessionid or ui_select.get_most_recent()
  sessionid = sessionid or session.get_some_session()
  sessionid = sessionid or create_from_provider()

  ui_session.set_current_win_conversation_input(sessionid)
end

---@param sessionid FacileLLM.SessionId?
---@return nil
local focus = function (sessionid)
  sessionid = sessionid or ui_select.get_most_recent()
  sessionid = sessionid or session.get_some_session()
  if not sessionid then
    return
  end

  ui_session.set_current_win_conversation_input(sessionid)
end

---@params opts table? options passed through to telescope
---@return nil
local focus_from_selection = function (opts)
  ui_select.select_session(session.get_session_names(),
    function (sessionid)
      ui_session.set_current_win_conversation_input(sessionid)
    end,
    "Select session to focus",
    opts
  )
end

---@return nil
local add_visual_as_input_and_query = function ()
  local sessionid = ui_select.get_most_recent()
  if not sessionid then
    return
  end

  local lines = util.get_visual_selection()
  if lines and #lines ~= 0 then
    ui_session.add_input_message_and_query(sessionid, lines)
  end
end

---@return nil
local add_visual_as_instruction = function ()
  local sessionid = ui_select.get_most_recent()
  if not sessionid then
    return
  end

  local lines = util.get_visual_selection()
  if lines then
    ui_session.add_message(sessionid, "Instruction", lines)
  end
end

---@return nil
local add_visual_as_context = function ()
  local sessionid = ui_select.get_most_recent()
  if not sessionid then
    return
  end

  local lines = util.get_visual_selection()
  if lines then
    ui_session.add_message(sessionid, "Context", lines)
  end
end

---@return nil
local add_visual_as_example = function ()
  local sessionid = ui_select.get_most_recent()
  if not sessionid then
    return
  end

  local lines = util.get_visual_selection()
  if lines then
    ui_session.add_message(sessionid, "Example", lines)
  end
end

---@return nil
local add_line_as_input_and_query = function ()
  local sessionid = ui_select.get_most_recent()
  if not sessionid then
    return
  end

  local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
  local lines = vim.api.nvim_buf_get_lines(0, row-1, row, false)
  if lines and #lines ~= 0 then
    ui_session.add_input_message_and_query(sessionid, lines)
  end
end

-- Use the visual line selection as input. Depending on the value of method
-- * substitute the selection by the LLM output,
-- * append the LLM output after the selection, or
-- * prepend the LLM output before the selection.
---@param method ("substitute"| "append"| "prepend")
---@return nil
local add_visual_as_input_query_and_insert = function (method)
  local sessionid = ui_select.get_most_recent()
  if not sessionid then
    return
  end

  local mode_init = string.sub(vim.fn.mode(), 1,1)

  local lines
  if method == "substitute" then
    if vim.fn.mode() == "V" then
      lines = util.substitute_visual_selection()
    else
      -- There is no good heuristic to deside what substitution of a
      -- arbitrary LLM response to a character or block selection should
      -- be. So we do not provide that option.
      return
    end
  elseif method == "append" then
    if mode_init == "v" or mode_init == "V" or mode_init == "" then
      lines = util.get_visual_selection("bottom")
    else
      return
    end
    vim.api.nvim_feedkeys("o", "nx", false)
  elseif method == "prepend" then
    if mode_init == "v" or mode_init == "V" or mode_init == "" then
      lines = util.get_visual_selection("top")
    else
      return
    end
    vim.api.nvim_feedkeys("O", "nx", false)
  else
    error("unsupported method " .. method)
  end
  ---@cast lines string[]

  local esckey = vim.api.nvim_replace_termcodes("<Esc>", true, true, true)
  vim.api.nvim_feedkeys(esckey, "nx", false)

  -- This can happen when only one empty line is selected.
  if not lines or #lines == 0 then
    return
  end

  ui_session.add_input_message_query_and_insert(sessionid, lines)
end

-- In normal mode use current line as input. Depending on the value of method
-- * substitute the current line by the LLM output,
-- * append the LLM output after the current line, or
-- * prepend the LLM output before the current line.
---@param method ("substitute"| "append"| "prepend")
---@return nil
local add_line_as_input_query_and_insert = function (method)
  local sessionid = ui_select.get_most_recent()
  if not sessionid then
    return
  end

  local mode_init = string.sub(vim.fn.mode(), 1,1)
  if mode_init ~= "n" then
    return
  end

  local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
  local lines = vim.api.nvim_buf_get_lines(0, row-1, row, false)
  if method == "substitute" then
      vim.api.nvim_feedkeys("S", "nx", false)
  elseif method == "append" then
    vim.api.nvim_feedkeys("o", "nx", false)
  elseif method == "prepend" then
    vim.api.nvim_feedkeys("O", "nx", false)
  else
    error("unsupported method " .. method)
  end
  ---@cast lines string[]

  local esckey = vim.api.nvim_replace_termcodes("<Esc>", true, true, true)
  vim.api.nvim_feedkeys(esckey, "nx", false)

  -- This can happen when only one empty line is selected.
  if not lines or #lines == 0 then
    return
  end

  ui_session.add_input_message_query_and_insert(sessionid, lines)
end


return {
  select_default_provider = select_default_provider,
  create_from_provider = create_from_provider,
  create_from_provider_selection = create_from_provider_selection,
  create_from_conversation_selection = create_from_conversation_selection,
  create_from_provider_conversation_selection = create_from_provider_conversation_selection,
  delete_from_selection = delete_from_selection,
  rename_from_selection = rename_from_selection,
  set_provider_from_selection = set_provider_from_selection,
  show = show,
  focus = focus,
  focus_from_selection = focus_from_selection,
  add_visual_as_input_and_query = add_visual_as_input_and_query,
  add_line_as_input_and_query = add_line_as_input_and_query,
  add_visual_as_instruction = add_visual_as_instruction,
  add_visual_as_context = add_visual_as_context,
  add_visual_as_example = add_visual_as_example,
  add_visual_as_input_query_and_insert = add_visual_as_input_query_and_insert,
  add_line_as_input_query_and_insert = add_line_as_input_query_and_insert,
}
