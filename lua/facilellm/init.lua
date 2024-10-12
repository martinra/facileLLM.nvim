local config = require("facilellm.config")
local convenience = require("facilellm.convenience")


return {
  setup = config.setup,

  select_default_provider                     = convenience.select_default_provider,
  create_from_provider                        = convenience.create_from_provider,
  create_from_provider_selection              = convenience.create_from_provider_selection,
  create_from_conversation_selection          = convenience.create_from_conversation_selection,
  create_from_provider_conversation_selection = convenience.create_from_provider_conversation_selection,
  delete_from_selection                       = convenience.delete_from_selection,
  rename_from_selection                       = convenience.rename_from_selection,
  set_provider_from_selection                 = convenience.set_provider_from_selection,

  show                 = convenience.show,
  focus                = convenience.focus,
  focus_from_selection = convenience.focus_from_selection,

  add_visual_as_input_and_query        = convenience.add_visual_as_input_and_query,
  add_visual_as_instruction            = convenience.add_visual_as_instruction,
  add_visual_as_context                = convenience.add_visual_as_context,
  add_visual_as_example                = convenience.add_visual_as_example,
  add_visual_as_input_query_and_insert = convenience.add_visual_as_input_query_and_insert,

  add_line_as_input_and_query        = convenience.add_line_as_input_and_query,
  add_line_as_input_query_and_insert = convenience.add_line_as_input_query_and_insert,
}
