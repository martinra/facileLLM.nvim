---@class FacileLLM.Config
---@field default_model string | number Name or index of the default model.
---@field models FacileLLM.LLMConfig[]
---@field layout FacileLLM.LayoutConfig

---@class FacileLLM.LLMConfig
---@field name string? Name of the model.
---@field implementation FacileLLM.LLMImplementation Name of an implementation. Must be accepted by
---    the function facilelll.llm.dispatch.
---@field opts table Options that are forwarded to the implementation.
---@field initial_conversation FacileLLM.Conversation 

---@class FacileLLM.LayoutConfig
---@field relative string Relative to what should the conversation window be opened?


---@return nil
local set_highlights = function ()
  vim.api.nvim_set_hl(0, "FacileLLMMsgReceiving", {link = "DiffAdd"})
  vim.api.nvim_set_hl(0, "FacileLLMRole", {link = "markdownH1"})
end

---@return nil
local set_global_keymaps = function ()
  local facilellm = require("facilellm")

  vim.keymap.set('n', '<leader>aiw', facilellm.show, {})
  vim.keymap.set('n', '<leader>ain', facilellm.create_from_selection, {})
  vim.keymap.set('n', '<leader>aid', facilellm.delete_from_selection, {})
  vim.keymap.set('n', '<leader>aif', facilellm.focus_from_selection, {})
  vim.keymap.set('n', '<leader>air', facilellm.rename_from_selection, {})
  vim.keymap.set('n', '<leader>aim', facilellm.set_model_from_selection, {})

  vim.keymap.set('v', '<leader>ai<Enter>', facilellm.add_visual_as_input_and_query, {})
  vim.keymap.set('v', '<leader>aic', facilellm.add_visual_as_context, {})
  vim.keymap.set('v', '<leader>aii', facilellm.add_visual_as_instruction, {})
  vim.keymap.set('v', '<leader>aip',
    function () facilellm.add_visual_as_input_query_and_insert("append") end, {})
  vim.keymap.set('v', '<leader>aiP',
    function () facilellm.add_visual_as_input_query_and_insert("prepend") end, {})
  vim.keymap.set('v', '<leader>ais',
    function () facilellm.add_visual_as_input_query_and_insert("substitute") end, {})
end

---@return FacileLLM.Config
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
---@return nil
local validate_facilellm_config = function (opts)
  vim.validate({
    opts = {opts, "t"},
  })
  vim.validate({
    -- default_model validated when validating models
    models        = {opts.models,        "t",        true},
    layout        = {opts.layout,        "t",        true},
  })

  if opts.models then
    vim.validate({
      default_model = {opts.default_model, {"s", "n"}, false}
    })
    local default_model_available = opts.models[opts.default_model] ~= nil

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
      if not default_model_available and model.name and opts.default_model == model.name then
        default_model_available = true
      end
    end

    if not default_model_available then
      error("default model not defined")
    end

  elseif opts.default_model then
    error("default model but no model defined")
  end

  if opts.layout then
    local layout = opts.layout
    vim.validate({
      relative = {layout.relative, "s", true}
    })
  end
end


local M = {
  ---@type FacileLLM.Config
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

  set_highlights()
  set_global_keymaps()
end


return M
