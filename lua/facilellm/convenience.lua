local config = require("facilellm.config")
local llm = require("facilellm.llm")
local session = require("facilellm.session")
local ui_select = require("facilellm.ui.select_session")
local ui_session = require("facilellm.ui.session")


---@param model_config? FacileLLM.LLMConfig
---@return FacileLLM.SessionId
local create_from_model = function (model_config)
  model_config = model_config or llm.default_model_config()
  ---@cast model_config FacileLLM.LLMConfig
  return ui_session.create(model_config)
end

---@return nil
local create_from_selection = function ()
  ui_select.select_model(config.opts.models,
    function (model_config)
      local sessionid = create_from_model(model_config)
      ui_select.touch(sessionid)
      ui_session.set_current_win_conversation_input(sessionid)
    end
  )

end

---@param sessionid FacileLLM.SessionId?
---@return nil
local show = function (sessionid)
  sessionid = sessionid or ui_select.get_most_recent()
  sessionid = sessionid or session.get_some_session()
  sessionid = sessionid or create_from_model()

  ui_select.touch(sessionid)
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

  ui_select.touch(sessionid)
  ui_session.set_current_win_conversation_input(sessionid)
end

---@return nil
local focus_from_selection = function ()
  ui_select.select_session(session.get_session_names(),
    function (sessionid)
      ui_select.touch(sessionid)
      ui_session.set_current_win_conversation_input(sessionid)
    end
  )
end

---@return nil
local add_context = function ()
  local sessionid = ui_select.get_most_recent()
  if not sessionid then
    return
  end

  session.add_message(sessionid, "Context",
    {
      "The conversation will be based on the following context:",
      '"""',
    })
  session.add_message_selection(sessionid, "Context")
  session.add_message(sessionid, "Context", {'"""'} )
  ui_session.render_conversation(sessionid)
  ui_session.fold_last_message(sessionid)
end


return {
  create_from_model = create_from_model,
  create_from_selection = create_from_selection,
  show = show,
  focus = focus,
  focus_from_selection = focus_from_selection,
  add_context = add_context,
}
