local session = require("facilellm.session")
local ui_session = require("facilellm.ui.session")


---@param sessionid number?
---@return nil
local show = function (sessionid)
  sessionid = sessionid or ui_session.get_most_recent()
  sessionid = sessionid or ui_session.select()
  sessionid = sessionid or ui_session.create_from_model()

  ui_session.touch(sessionid)
  ui_session.set_current_win_conversation_input(sessionid)
end

---@return nil
local add_context = function ()
  local sessionid = ui_session.get_most_recent()
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
  add_context = add_context,
  show = show,
}
