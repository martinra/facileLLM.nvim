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
local validate_facilellm_config = function (opts)
  vim.validate({
    opts = {opts, "t"},
  })
  vim.validate({
    default_model = {opts.default_model, {"s", "n"}, true},
    models        = {opts.models,        "t",        true},
    layout        = {opts.layout,        "t",        true},
  })

  if opts.models then
    for _,model in ipairs(opts.models) do
      vim.validate({
        model                = {model, "t", false}
      })
      vim.validate({
        name                 = {model.name,           "s",        true},
        implementation       = {model.implementation, {"s", "f"}, false},
        opts                 = {model.opts,           "t",        true},
        initial_conversation = {model.initial_conversation, "t",  true},
      })
    end
  end

  if opts.layout then
    local layout = opts.layout
    vim.validate({
      relative = {layout.relative, "s", true}
    })
  end
end


local M = {
  ---@type FacileLLMConfig
  opts = default_opts(),
}

---@param opts table
---@return nil
M.setup = function (opts)
  opts = opts or {}
  validate_facilellm_config(opts)

  -- We merge options anyway, because this has the best change to mirror the
  -- expected behavior.
  M.opts = vim.tbl_deep_extend("force", M.opts, opts)

  vim.api.nvim_set_hl(0, "FacileLLMMsgReceiving", {link = "DiffAdd"})
  vim.api.nvim_set_hl(0, "FacileLLMRole", {link = "markdownH1"})
end


return M
