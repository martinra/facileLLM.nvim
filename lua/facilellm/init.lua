local config = require("facilellm.config")
local convenience = require("facilellm.convenience")


local M = {}


M.setup = config.setup

M.select_default_model = convenience.select_default_model
M.create_from_model_selection = convenience.create_from_model_selection
M.create_from_conversation_selection = convenience.create_from_conversation_selection
M.create_from_model_conversation_selection = convenience.create_from_model_conversation_selection
M.delete_from_selection = convenience.delete_from_selection
M.rename_from_selection = convenience.rename_from_selection
M.set_model_from_selection = convenience.set_model_from_selection

M.show = convenience.show
M.focus = convenience.focus
M.focus_from_selection = convenience.focus_from_selection

M.add_visual_as_input_and_query = convenience.add_visual_as_input_and_query
M.add_visual_as_context = convenience.add_visual_as_context
M.add_visual_as_instruction = convenience.add_visual_as_instruction
M.add_visual_as_input_query_and_insert = convenience.add_visual_as_input_query_and_insert


return M
