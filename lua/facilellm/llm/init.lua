local config = require("facilellm.config")


---@class FacileLLM.LLM
---@field name string
---@field params table
---@field response_to function(conv: Conversation, add_msg: function, on_cmpl: function, opt:table): function?

---@class FacileLLM.LLM.PromptConversion
---@field conversation_to_input function(FacileLLM.Conversation): string
---@field output_to_string function(table): string

---@class FacileLLM.LLM.Implementation
---@field create function(opts: table): FacileLLM.LLM
---@field preview function?(opts: table): string

---@param implementation FacileLLM.LLM.Implementation
---@param opts table
---@return FacileLLM.LLM
local create = function (implementation, opts)
  return implementation.create(opts)
end

---@param implementation FacileLLM.LLM.Implementation
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
local _default_model = nil

---@param default_model integer | string
---@return nil
local set_default_model_config = function (default_model)
  _default_model = default_model
end

---@return FacileLLM.Config.LLM
local get_default_model_config = function ()
  local default_model = _default_model or config.opts.default_model
  local models = config.opts.models

  if type(default_model) == "number" then
    local model_config = models[default_model]
    if not model_config then
      error("Invalid default model index " .. default_model)
    end
    return model_config
  elseif type(default_model) == "string" then
    for _,model in ipairs(models) do
      if model.name == default_model then
        return model
      end
    end
    error("Invalid default model name " .. default_model)
  else
    error("Invalid default model " .. vim.inspect(default_model)
           .. ", must be number (list index) or string (model name)")
  end
end


return {
  create = create,
  preview = preview,
  set_default_model_config = set_default_model_config,
  get_default_model_config = get_default_model_config,
}
