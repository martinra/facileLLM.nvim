local config = require("facilellm.config")


---@class FacileLLM.LLM
---@field name string
---@field params table
---@field response_to function(conv: Conversation, add_msg: function, on_cmpl: function, opt:table)

---@class FacileLLM.LLMImplementation
---@field create function(opts: table): FacileLLM.LLM
---@field preview function?(opts: table): string

---@alias FacileLLM.LLMImplementationName ("OpenAI API"| "The Void Mock LLM")


---@param name FacileLLM.LLMImplementationName
---@return FacileLLM.LLMImplementation
local dispatch = function (name)
  if name == "OpenAI API" then
    return require("facilellm.llm.openai")
  elseif name == "The Void Mock LLM" then
    return require("facilellm.llm.void")
  else
    error("Unknown LLM implementation " .. vim.inspect(name))
  end
end

---@param implementation FacileLLM.LLMImplementation | FacileLLM.LLMImplementationName
---@param opts table
---@return FacileLLM.LLM
local create = function (implementation, opts)
  if type(implementation) == "string" then
    implementation = dispatch(implementation)
  end
  return implementation.create(opts)
end

---@param implementation FacileLLM.LLMImplementation | FacileLLM.LLMImplementationName
---@param opts table
---@return string?
local preview = function (implementation, opts)
  if type(implementation) == "string" then
    implementation = dispatch(implementation)
  end
  if implementation.preview then
    return implementation.preview(opts)
  else
    return nil
  end
end

---@return FacileLLM.Config.LLM
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
  create = create,
  preview = preview,
  default_model_config = default_model_config,
}
