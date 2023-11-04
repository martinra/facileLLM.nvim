local config = require("facilellm.config")
local convenience = require("facilellm.convenience")


---@class ModuleFacileLLM
---@field setup function(table?): nil
---@field show function(number? sessionid): nil
---@field add_context function(nil): nil
local M = {}


M.setup = config.setup
M.show = convenience.show
M.new_from_selection = convenience.new_from_selection
M.add_context = convenience.add_context


---@type ModuleFacileLLM
return M
