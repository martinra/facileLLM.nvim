local config = require("facilellm.config")
local ui = require("facilellm.ui")


---@class ModuleFacileLLM
---@field setup function(nil | table): nil
---@field show function(nil | number sessionid): nil
local M = {}


M.setup = config.setup
M.show = ui.show


---@type ModuleFacileLLM
return M
