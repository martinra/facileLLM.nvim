local config = require("facilellm.config")


---@class LLM
---@field name string
---@field params table
---@field response_to function(conv: string, add_msg: function, on_cmpl: function, opt:table)


---@param implementation string
---@return function(opts: table): LLM
local dispatch = function (implementation)
  if implementation == "OpenAI API" then
    return require("facilellm.llm.openai").create
  elseif implementation == "The Void Mock LLM" then
    return require("facilellm.llm.void").create
  else
    error("Unknown LLM implementation " .. vim.inspect(implementation))
  end
end

---@return LLMConfig
local default_model_config = function ()
  local default_model = config.opts.default_model
  local models = config.opts.models

  if type(default_model) == "number" then
    return models[default_model]
  elseif type(default_model) == "string" then
    for _,model in ipairs(models) do
      if model.name == default_model then
        return model
      end
    end
    error("Could not find default model with name " .. config.opts.default_model)
  else
    error("Default model " .. vim.inspect(config.opts.default_model) .. " must be number (list index) or string (model name)")
  end
end


return {
  dispatch = dispatch,
  default_model_config = default_model_config,
}
