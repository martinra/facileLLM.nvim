local config = require("facilellm.config")
local llm = require("facilellm.llm")
local session = require("facilellm.session")
local ui_select = require("facilellm.ui.select_session")
local ui_session = require("facilellm.ui.session")
local util = require("facilellm.util")


---@param model_config? FacileLLM.Config.LLM
---@return FacileLLM.SessionId
local create_from_model = function (model_config)
  model_config = model_config or llm.default_model_config()
  return ui_session.create(model_config)
end

---@return nil
local create_from_model_selection = function ()
  ui_select.select_model(config.opts.models,
    function (model_config)
      local sessionid = create_from_model(model_config)
      ui_session.set_current_win_conversation_input(sessionid)
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

-- Use the visual line selection as input. Depending on the value of mode
-- * substitute the selection by the LLM output,
-- * append the LLM output after the selection, or
-- * prepend the LLM output before the selection.
---@param mode ("substitute"| "append"| "prepend")
---@return nil
local add_visual_as_input_query_and_insert = function (mode)
  local sessionid = ui_select.get_most_recent()
  if not sessionid then
    return
  end

  local lines
  if mode == "substitute" then
    if vim.fn.mode() ~= "V" then
      return
    end
    lines = util.substitute_visual_selection()
  else
    if mode == "append" then
      lines = util.get_visual_selection("bottom")
      vim.api.nvim_feedkeys("o", "nx", false)
    else
      lines = util.get_visual_selection("top")
      vim.api.nvim_feedkeys("O", "nx", false)
    end
  end
  ---@cast lines string[]

  local esckey = vim.api.nvim_replace_termcodes("<Esc>", true, true, true)
  vim.api.nvim_feedkeys(esckey, "nx", false)

  -- This can happen when only one empty line is selected.
  if not lines or #lines == 0 then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
  local nspc_pending_insert = vim.api.nvim_create_namespace("facilellm-pending-insert")

  ---@param lines__loc string[]
  local response_callback = function (lines__loc)
    vim.api.nvim_buf_clear_namespace(bufnr, nspc_pending_insert, row-1, row)
    vim.api.nvim_buf_set_lines(bufnr, row-1, row, false, lines__loc)
  end

  if config.opts.feedback.pending_insertion_feedback then
    vim.api.nvim_buf_set_extmark(bufnr, nspc_pending_insert, row-1, 0,
    {
      virt_text = { {config.opts.feedback.pending_insertion_feedback_message, "WarningMsg"} },
      virt_text_pos = "overlay"
    })
  end

  ui_session.add_input_message_and_query(sessionid, lines, response_callback)
end


return {
  create_from_model = create_from_model,
  create_from_model_selection = create_from_model_selection,
  delete_from_selection = delete_from_selection,
  rename_from_selection = rename_from_selection,
  set_model_from_selection = set_model_from_selection,
  show = show,
  focus = focus,
  focus_from_selection = focus_from_selection,
  add_visual_as_input_and_query = add_visual_as_input_and_query,
  add_visual_as_context = add_visual_as_context,
  add_visual_as_instruction = add_visual_as_instruction,
  add_visual_as_input_query_and_insert = add_visual_as_input_query_and_insert
}
