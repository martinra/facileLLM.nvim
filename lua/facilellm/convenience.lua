local config = require("facilellm.config")
local llm = require("facilellm.llm")
local session = require("facilellm.session")
local ui_select = require("facilellm.ui.select_session")
local ui_session = require("facilellm.ui.session")
local util = require("facilellm.util")


---@return nil
local select_default_model = function ()
  ui_select.select_model(config.opts.models,
    function (model_config)
      llm.set_default_model_config(model_config.name)
    end,
    "Select default model"
  )
end

---@param model_config? FacileLLM.Config.LLM
---@return FacileLLM.SessionId
local create_from_model = function (model_config)
  model_config = model_config or llm.get_default_model_config()
  return ui_session.create(model_config)
end

---@return nil
local create_from_model_selection = function ()
  ui_select.select_model(config.opts.models,
    function (model_config)
      local sessionid = ui_session.create(model_config)
      ui_session.set_current_win_conversation_input(sessionid)
    end,
    "Select model to create new session from"
  )
end

---@return nil
local create_from_conversation_selection = function ()
  ui_select.select_conversation(config.opts.conversations,
  function (conversation)
    local model_config = llm.get_default_model_config()
    model_config = util.deep_copy_values(model_config)
    model_config.conversation = util.deep_copy_values(conversation)
    local sessionid = ui_session.create(model_config)
    ui_session.set_current_win_conversation_input(sessionid)
  end,
  "Select initial conversation of new session"
  )
end

---@return nil
local create_from_model_conversation_selection = function ()
  ui_select.select_model(config.opts.models,
    function (model_config)
      ui_select.select_conversation(config.opts.conversations,
        function (conversation)
          model_config = util.deep_copy_values(model_config)
          model_config.conversation = util.deep_copy_values(conversation)
          local sessionid = ui_session.create(model_config)
          ui_session.set_current_win_conversation_input(sessionid)
        end,
        "Select initial conversation of new session"
      )
    end,
    "Select model to create new session from"
  )
end

---@return nil
local delete_from_selection = function ()
  ui_select.select_session(session.get_session_names(),
    function (sessionid)
      ui_session.delete(sessionid)
    end,
    "Select session to delete"
  )
end

---@return nil
local rename_from_selection = function ()
  ui_select.select_session(session.get_session_names(),
    function (sessionid)
      ui_session.rename(sessionid)
    end,
    "Select session to rename"
  )
end

---@return nil
local set_model_from_selection = function ()
  ui_select.select_session(session.get_session_names(),
    function (sessionid)
      local name = session.get_name(sessionid)
      ui_select.select_model(config.opts.models,
        function (model_config)
          session.set_model(sessionid, model_config)
        end,
        "Select model for session " .. name
      )
    end,
    "Select session to change model of"
  )
end

---@param sessionid FacileLLM.SessionId?
---@return nil
local show = function (sessionid)
  sessionid = sessionid or ui_select.get_most_recent()
  sessionid = sessionid or session.get_some_session()
  sessionid = sessionid or create_from_model()

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

---@return nil
local focus_from_selection = function ()
  ui_select.select_session(session.get_session_names(),
    function (sessionid)
      ui_session.set_current_win_conversation_input(sessionid)
    end,
    "Select session to focus"
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
  select_default_model = select_default_model,
  create_from_model = create_from_model,
  create_from_model_selection = create_from_model_selection,
  create_from_conversation_selection = create_from_conversation_selection,
  create_from_model_conversation_selection = create_from_model_conversation_selection,
  delete_from_selection = delete_from_selection,
  rename_from_selection = rename_from_selection,
  set_model_from_selection = set_model_from_selection,
  show = show,
  focus = focus,
  focus_from_selection = focus_from_selection,
  add_visual_as_input_and_query = add_visual_as_input_and_query,
  add_line_as_input_and_query = add_line_as_input_and_query,
  add_visual_as_context = add_visual_as_context,
  add_visual_as_instruction = add_visual_as_instruction,
  add_visual_as_input_query_and_insert = add_visual_as_input_query_and_insert,
  add_line_as_input_query_and_insert = add_line_as_input_query_and_insert,
}
