---@class FacileLLM.Config
---@field default_model string | number Name or index of the default model.
---@field models FacileLLM.Config.LLM[]
---@field naming FacileLLM.Config.Naming
---@field interface FacileLLM.Config.Interface
---@field feedback FacileLLM.Config.Feedback

---@class FacileLLM.Config.LLM
---@field name string? Name of the model.
---@field implementation FacileLLM.LLMImplementation Name of an implementation. Must be accepted by
---    the function facilelll.llm.dispatch.
---@field opts table Options that are forwarded to the implementation.
---@field initial_conversation FacileLLM.Conversation 
---@field autostart boolean

---@class FacileLLM.Config.Naming
---@field role_display FacileLLM.Config.Naming.RoleDisplay
---@field conversation_buffer_prefix string
---@field input_buffer_prefix string
---@field fork_suffix string

---@class FacileLLM.Config.Naming.RoleDisplay
---@field instruction string
---@field context string
---@field input string
---@field llm string

---@class FacileLLM.Config.Interface
---@field layout_relative ("editor"| "win") Relative to what should the conversation window be opened?
---@field input_relative_height number
---@field highlight_role boolean
---@field fold_instruction boolean
---@field fold_context boolean

---@class FacileLLM.Config.Feedback
---@field highlight_message_while_receiving boolean
---@field pending_insertion_feedback boolean
---@field pending_insertion_feedback_message string
---@field conversation_lock FacileLLM.Config.Feedback.ConversationLock

---@class FacileLLM.Config.Feedback.ConversationLock
---@field input_confirm boolean
---@field input_instruction boolean
---@field input_context boolean
---@field warn_on_query boolean
---@field warn_on_clear boolean


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

---@param models FacileLLM.Config.LLM[]
---@return nil
local autostart_sessions = function (models)
  local ui_session = require("facilellm.ui.session")
  for _,model in ipairs(models) do
    if model.autostart then
      ui_session.create(model)
    end
  end
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
        autostart = false,
      },
    },

    naming = {
      role_display = {
        instruction = "Instruction:",
        context     = "Context:",
        input       = "Input:",
        llm         = "LLM:",
      },
      conversation_buffer_prefix = "facileLLM",
      input_buffer_prefix = "facileLLM Input",
      fork_suffix = "Fork",
    },

    interface = {
      layout_relative = "editor",
      input_relative_height = 0.15,
      highlight_role   = true,
      fold_instruction = true,
      fold_context     = true,
    },

    feedback = {
      highlight_message_while_receiving = true,
      pending_insertion_feedback = true,
      pending_insertion_feedback_message = "Will insert pending LLM response",
      conversation_lock = {
        input_confirm     = true,
        input_instruction = true,
        input_context     = true,
        warn_on_query     = true,
        warn_on_clear     = true,
      },
    },
  }
end

---@return FacileLLM.Config.LLM
local default_model_config = function ()
  return {
    name = nil,
    implementation = "undefined",
    opts = {},
    initial_conversation = {},
    autostart = false,
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
    naming        = {opts.naming,        "t",        true},
    interface     = {opts.interface,     "t",        true},
    feedback      = {opts.feedback,      "t",        true},
  })

  if opts.models then
    vim.validate({
      default_model = {opts.default_model, {"s", "n"}, false},
    })
    local default_model_available = opts.models[opts.default_model] ~= nil

    for _,model in ipairs(opts.models) do
      vim.validate({
        model                = {model, "t", false}
      })
      vim.validate({
        name                 = {model.name,                 "s",        true},
        implementation       = {model.implementation,       {"s", "f"}, false},
        opts                 = {model.opts,                 "t",        true},
        initial_conversation = {model.initial_conversation, "t",        true},
        autostart            = {model.autostart,            "b",        true},
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

  if opts.naming then
    local naming = opts.naming
    vim.validate({
      role_display               = {naming.role_display,               "t", true},
      conversation_buffer_prefix = {naming.conversation_buffer_prefix, "s", true},
      input_buffer_prefix        = {naming.input_buffer_prefix,        "s", true},
      fork_suffix                = {naming.fork_suffix,                "s", true},
    })

    if naming.role_display then
      local role_display = naming.role_display
      vim.validate({
        instruction = {role_display.instruction, "s", true},
        context     = {role_display.context,     "s", true},
        input       = {role_display.input,       "s", true},
        llm         = {role_display.llm,         "s", true},
      })
    end

  end

  if opts.interface then
    local interface = opts.interface
    vim.validate({
      layout_relative       = {interface.layout_relative,       "s", true},
      input_relative_height = {interface.input_relative_height, "n", true},
      highlight_role        = {interface.highlight_role,        "b", true},
      fold_instruction      = {interface.fold_instruction,      "b", true},
      fold_context          = {interface.fold_context,          "b", true},
    })
  end

  if opts.feedback then
    local feedback = opts.feedback
    vim.validate({
      highlight_message_while_receiving  = {feedback.highlight_message_while_receiving,  "b", true},
      pending_insertion_feedback         = {feedback.pending_insertion_feedback,         "b", true},
      pending_insertion_feedback_message = {feedback.pending_insertion_feedback_message, "s", true},
      conversation_lock                  = {feedback.conversation_lock,                  "t", true},
    })

    if feedback.conversation_lock then
      local conversation_lock = feedback.conversation_lock
      vim.validate({
        input_confirm     = {conversation_lock.input_confirm    , "b", true},
        input_instruction = {conversation_lock.input_instruction, "b", true},
        input_context     = {conversation_lock.input_context    , "b", true},
        warn_on_query     = {conversation_lock.warn_on_query    , "b", true},
        warn_on_clear     = {conversation_lock.warn_on_clear    , "b", true},
      })
    end
  end
end

---@param opts table
---@return FacileLLM.Config
local extend_facilellm_config = function (opts)
  opts = vim.tbl_deep_extend("force", default_opts(), opts)
  for mx,model in ipairs(opts.models) do
    opts.models[mx] = vim.tbl_deep_extend("keep", model, default_model_config())
  end
  return opts
end


local M = {}

---@param opts table?
---@return nil
M.setup = function (opts)
  opts = opts or {}
  validate_facilellm_config(opts)
  M.opts = extend_facilellm_config(opts)

  set_highlights()
  set_global_keymaps()
  autostart_sessions(M.opts.models)
end


return M
