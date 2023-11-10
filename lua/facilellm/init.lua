local config = require("facilellm.config")
local convenience = require("facilellm.convenience")


local M = {}


M.setup = config.setup
M.create_from_selection = convenience.create_from_selection
M.delete_from_selection = convenience.delete_from_selection
M.rename_from_selection = convenience.rename_from_selection
M.set_model_from_selection = convenience.set_model_from_selection
M.show = convenience.show
M.focus = convenience.focus
M.focus_from_selection = convenience.focus_from_selection
M.add_context = convenience.add_context


return M
