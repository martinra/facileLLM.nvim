--- Convenience functions for FacileLLM
--- Provides high-level functions for common operations like creating sessions,
--- managing providers, and handling visual/line selections for LLM interactions.
---@module 'facilellm.convenience'

local config = require("facilellm.config")
local provider = require("facilellm.provider")
local session = require("facilellm.session")
local conversation = require("facilellm.session.conversation")
local ui_recent = require("facilellm.ui.recent_session")
local ui_select = require("facilellm.ui.select_session")
local ui_session = require("facilellm.ui.session")
local util = require("facilellm.util")


--- Opens a selection UI to choose the default provider from configured providers.
---@return nil
local select_default_provider = function ()
  ui_select.select_provider(config.opts.providers,
    function (provider_config)
      provider.set_default_provider_config(provider_config.name)
    end,
    "Select default provider"
  )
end

--- Creates a new session from a provider configuration.
---@param provider_config? FacileLLM.Config.Provider The provider configuration to use, or default if nil
---@return FacileLLM.SessionId The ID of the newly created session
local create_from_provider = function (provider_config)
  provider_config = provider_config or provider.get_default_provider_config()
  return ui_session.create(provider_config)
end

--- Opens a selection UI to create a new session from available providers.
---@param opts table? Options passed through to telescope
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

--- Opens a selection UI to create a new session from available converstrations, using the default provider.
---@param opts table? Options passed through to telescope
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

--- Opens a selection UI to create a new session by selecting both provider and conversation separately.
---@param opts table? Options passed through to telescope
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

--- Opens a selection UI to delete a session.
---@param opts table? Options passed through to telescope
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

--- Opens a selection UI to rename a session.
---@param opts table? Options passed through to telescope
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

--- Opens a selection UI to change a session's provider.
---@param opts table? Options passed through to telescope
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

--- Shows a session in the current FacileLLM window, creating one if needed.
---@param sessionid FacileLLM.SessionId? The session to show, or most recent if nil
---@return nil
local show = function (sessionid)
  sessionid = sessionid or ui_recent.get_most_recent()
  sessionid = sessionid or session.get_some_session()
  sessionid = sessionid or create_from_provider()

  ui_session.set_current_win_conversation_input(sessionid)
end

--- Focuses on a specific session's window.
---@param sessionid FacileLLM.SessionId? The session to focus, or most recent if nil
---@return nil
local focus = function (sessionid)
  sessionid = sessionid or ui_recent.get_most_recent()
  sessionid = sessionid or session.get_some_session()
  if not sessionid then
    return
  end

  ui_session.set_current_win_conversation_input(sessionid)
end

--- Opens a selection UI to focus on a specific session.
---@param opts table? Options passed through to telescope
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
  local sessionid = ui_recent.get_most_recent()
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
  local sessionid = ui_recent.get_most_recent()
  if not sessionid then
    return
  end

  local lines = util.get_visual_selection()
  if lines then
    ui_session.add_instruction_message(sessionid, lines)
  end
end

---@return nil
local add_visual_as_context = function ()
  local sessionid = ui_recent.get_most_recent()
  if not sessionid then
    return
  end

  local lines = util.get_visual_selection()
  if lines then
    ui_session.add_context_message(sessionid, lines)
  end
end

---@return nil
local add_visual_as_example = function ()
  local sessionid = ui_recent.get_most_recent()
  if not sessionid then
    return
  end

  local lines = util.get_visual_selection()
  if lines then
    ui_session.add_example_message(sessionid, lines)
  end
end

---@return nil
local add_line_as_input_and_query = function ()
  local sessionid = ui_recent.get_most_recent()
  if not sessionid then
    return
  end

  local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
  local lines = vim.api.nvim_buf_get_lines(0, row-1, row, false)
  if lines and #lines ~= 0 then
    ui_session.add_input_message_and_query(sessionid, lines)
  end
end

--- Uses the visual line selection as input and inserts the LLM response
--- The response can either substitute the selection, be appended after it,
--- or be prepended before it.
---@param method ("substitute"| "append"| "prepend") How to insert the LLM response
---@return nil
local add_visual_as_input_query_and_insert = function (method)
  local sessionid = ui_recent.get_most_recent()
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

--- Uses the current line as input in normal mode and inserts the LLM response
--- The response can either substitute the line, be appended after it,
--- or be prepended before it.
---@param method ("substitute"| "append"| "prepend") How to insert the LLM response
---@return nil
local add_line_as_input_query_and_insert = function (method)
  local sessionid = ui_recent.get_most_recent()
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

---@return nil
local add_visual_as_conversation = function()
  local sessionid = ui_recent.get_most_recent()
  if not sessionid then
    return
  end

  local lines = util.get_visual_selection()
  if not lines then
    return
  end

  local conv = conversation.parse_rendered_conversation(lines)
  ui_session.append_conversation(sessionid, conv)
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
  add_visual_as_conversation = add_visual_as_conversation,
}
