local config = require("facilellm.config")


---@class FacileLLM.Provider
---@field name string
---@field params table
---@field response_to function(conv: Conversation, add_msg: function, on_cmpl: function, opt:table): function?

---@class FacileLLM.Provider.PromptConversion
---@field conversation_to_input function(FacileLLM.Conversation): string

---@class FacileLLM.Provider.Implementation
---@field create function(opts: table): FacileLLM.Provider
---@field preview function?(opts: table): string

---@param implementation FacileLLM.Provider.Implementation
---@param opts table
---@return FacileLLM.Provider
local create = function (implementation, opts)
  return implementation.create(opts)
end

---@param implementation FacileLLM.Provider.Implementation
---@param opts table
---@return string?
local preview = function (implementation, opts)
  if implementation.preview then
    return implementation.preview(opts)
  else
    return nil
  end
end

---@type integer | string
local _default_provider = nil

---@param default_provider integer | string
---@return nil
local set_default_provider_config = function (default_provider)
  _default_provider = default_provider
end

---@return FacileLLM.Config.Provider
local get_default_provider_config = function ()
  local default_provider = _default_provider or config.opts.default_provider
  local providers = config.opts.providers

  if type(default_provider) == "number" then
    local provider_config = providers[default_provider]
    if not provider_config then
      error("Invalid default provider index " .. default_provider)
    end
    return provider_config
  elseif type(default_provider) == "string" then
    for _,provider in ipairs(providers) do
      if provider.name == default_provider then
        return provider
      end
    end
    error("Invalid default provider name " .. default_provider)
  else
    error("Invalid default provider " .. vim.inspect(default_provider)
           .. ", must be number (list index) or string (provider name)")
  end
end


return {
  create = create,
  preview = preview,
  set_default_provider_config = set_default_provider_config,
  get_default_provider_config = get_default_provider_config,
}
