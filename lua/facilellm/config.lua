---@class FacileLLMConfig
---@field default_model string | number Name or index of the default model.
---@field models LLMConfig[]
---@field layout LayoutConfig

---@class LLMConfig
---@field name string Name of the model.
---@field implementation string Name of an implementation. Must be accepted by
---    the function facilelll.llm.dispatch.
---@field opts table Options that are forwarded to the implementation.
---@field initial_conversation Conversation 

---@class LayoutConfig
---@field relative string Relative to what should the conversation window be opened?


---@return FacileLLMConfig
local default_opts = function ()
  return {
    default_model = "OpenAI GPT 3.5-Turbo",
    models = {
      {
        name = "OpenAI GPT 3.5-Turbo",
        implementation = "OpenAI API",
        opts = {},
        initial_conversation = {},
      },
    },

    layout = {
      relative = "editor",
    },
  }
end

---@param opts table
---@return nil | string
local validate = function (opts)
   if type(opts) ~= "table" then
     return "opts must be a table"
  end
  -- WARN: validation not yet implemented
end


local M = {
  ---@type FacileLLMConfig
  opts = default_opts(),
}

---@param opts table
---@return nil
M.setup = function (opts)
  opts = opts or {}
  local validation_error = validate(opts)
  if validation_error then
    vim.notify("FacileLLM: Error validating options passed to setup.\n" .. validation_error, vim.log.levels.ERROR)
  end
  -- We merge options anyway, because this has the best change to mirror the expected behavior.
  M.opts = vim.tbl_deep_extend("force", M.opts, opts)
end


return M
