---@class FacileLLM.Config
---@field default_model string | integer
---@field models FacileLLM.Config.LLM[]
---@field conversations table<FacileLLM.ConversationName, FacileLLM.Conversation>
---@field conversations_csv string?
---@field naming FacileLLM.Config.Naming
---@field interface FacileLLM.Config.Interface
---@field feedback FacileLLM.Config.Feedback

---@class FacileLLM.Config.LLM
---@field name string?
---@field implementation FacileLLM.LLMImplementationName | FacileLLM.LLMImplementation
---@field opts table Options that are forwarded to the implementation.
---@field conversation FacileLLM.ConversationName | FacileLLM.Conversation 
---@field registers table<string, FacileLLM.Config.Register>
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
---@field telescope boolean
---@field unique_session boolean
---@field couple_conv_input_windows boolean
---@field layout_relative ("editor"| "win")
---@field layout_direction ("right"| "left")
---@field input_relative_height number
---@field highlight_role boolean
---@field fold_instruction boolean
---@field fold_context boolean
---@field keymaps FacileLLM.Config.Interface.Keymaps

---@class FacileLLM.Config.Interface.Keymaps
---@field delete_interaction string
---@field delete_conversation string
---@field delete_session string
---@field fork_session string
---@field rename_session string
---@field input_confirm string
---@field input_instruction string
---@field input_context string
---@field requery string
---@field prune_message string
---@field deprune_message string
---@field purge_message string
---@field show string
---@field create_from_model_selection string
---@field delete_from_selection string
---@field focus_from_selection string
---@field rename_from_selection string
---@field set_model_from_selection string
---@field add_visual_as_input_and_query string
---@field add_visual_as_context string
---@field add_visual_as_instruction string
---@field add_visual_as_input_query_and_append string
---@field add_visual_as_input_query_and_prepend string
---@field add_visual_as_input_query_and_substitute string

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

---@class FacileLLM.Config.Register
---@field postprocess ("preserve"| "code"| function)


local util = require("facilellm.util")


---@return nil
local set_highlights = function ()
  vim.api.nvim_set_hl(0, "FacileLLMRole", {link = "markdownH1", default = true})
  vim.api.nvim_set_hl(0, "FacileLLMMsgReceiving", {link = "DiffAdd", default = true})
  vim.api.nvim_set_hl(0, "FacileLLMMsgPruned", {link = "DiffDelete", default = true})
end

---@return nil
local set_global_keymaps = function ()
  local facilellm = require("facilellm")
  local config = require("facilellm.config")

  if config.opts.interface.keymaps.show ~= "" then
    vim.keymap.set("n", config.opts.interface.keymaps.show,
      facilellm.show, {})
  end
  if config.opts.interface.keymaps.create_from_model_selection ~= "" then
    vim.keymap.set("n", config.opts.interface.keymaps.create_from_model_selection,
      facilellm.create_from_model_selection, {})
  end
  if config.opts.interface.keymaps.delete_from_selection ~= "" then
    vim.keymap.set("n", config.opts.interface.keymaps.delete_from_selection,
      facilellm.delete_from_selection, {})
  end
  if config.opts.interface.keymaps.focus_from_selection ~= "" then
    vim.keymap.set("n", config.opts.interface.keymaps.focus_from_selection,
      facilellm.focus_from_selection, {})
  end
  if config.opts.interface.keymaps.rename_from_selection ~= "" then
    vim.keymap.set("n", config.opts.interface.keymaps.rename_from_selection,
      facilellm.rename_from_selection, {})
  end
  if config.opts.interface.keymaps.set_model_from_selection ~= "" then
    vim.keymap.set("n", config.opts.interface.keymaps.set_model_from_selection,
      facilellm.set_model_from_selection, {})
  end

  if config.opts.interface.keymaps.add_visual_as_input_and_query ~= "" then
    vim.keymap.set("v", config.opts.interface.keymaps.add_visual_as_input_and_query,
      facilellm.add_visual_as_input_and_query, {})
  end
  if config.opts.interface.keymaps.add_visual_as_context ~= "" then
    vim.keymap.set("v", config.opts.interface.keymaps.add_visual_as_context,
      facilellm.add_visual_as_context, {})
  end
  if config.opts.interface.keymaps.add_visual_as_instruction ~= "" then
    vim.keymap.set("v", config.opts.interface.keymaps.add_visual_as_instruction,
      facilellm.add_visual_as_instruction, {})
  end
  if config.opts.interface.keymaps.add_visual_as_input_query_and_append ~= "" then
    vim.keymap.set("v", config.opts.interface.keymaps.add_visual_as_input_query_and_append,
      function () facilellm.add_visual_as_input_query_and_insert("append") end, {})
  end
  if config.opts.interface.keymaps.add_visual_as_input_query_and_prepend ~= "" then
    vim.keymap.set("v", config.opts.interface.keymaps.add_visual_as_input_query_and_prepend,
      function () facilellm.add_visual_as_input_query_and_insert("prepend") end, {})
  end
  if config.opts.interface.keymaps.add_visual_as_input_query_and_substitute ~= "" then
    vim.keymap.set("v", config.opts.interface.keymaps.add_visual_as_input_query_and_substitute,
      function () facilellm.add_visual_as_input_query_and_insert("substitute") end, {}
    )
  end
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

---@return FacileLLM.Config.LLM
local default_model_config = function ()
  return {
    name           = nil,
    implementation = "undefined",
    opts           = {},
    conversation   = {},
    registers      = {
      ["l"] = { postprocess = "preserve" },
      ["c"] = { postprocess = "code" },
    },
    autostart      = false,
  }
end

---@return FacileLLM.Config
local default_opts = function ()
  return {
    default_model = "OpenAI GPT 3.5-Turbo",
    models = {
      {
        name = "OpenAI GPT 3.5-Turbo",
        implementation = "OpenAI API",
        opts = {
          openai_model = "gpt-3.5-turbo",
        },
      },
      {
        name = "OpenAI GPT 4",
        implementation = "OpenAI API",
        opts = {
          openai_model = "gpt-4",
        },
      },
      {
        name = "OpenAI GPT 4 32K",
        implementation = "OpenAI API",
        opts = {
          openai_model = "gpt-4-32k",
        },
      },
    },

    conversations = {
      ["Concise answers"] = {
        {
          role = "Instruction",
          lines = { "Give short and concise answers." }
        },
      },
      ["Detailed answers"] = {
        {
          role = "Instruction",
          lines = { "Give detailed answers that scrutinize many aspects of the topic." }
        },
      },
    },
    conversation_csv = nil,

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
      telescope                 = true,
      unique_session            = false,
      couple_conv_input_windows = true,
      layout_relative           = "editor",
      layout_direction          = "right",
      input_relative_height     = 0.15,
      highlight_role            = true,
      fold_instruction          = true,
      fold_context              = true,
      keymaps = {
        delete_interaction  = "<C-d>i",
        delete_conversation = "<C-d>c",
        delete_session      = "<C-d>s",
        fork_session        = "<C-f>",
        rename_session      = "<C-r>",

        input_confirm       = "<Enter>",
        input_instruction   = "<C-i>",
        input_context       = "<C-k>",
        requery             = "<C-r>",

        prune_message       = "p",
        deprune_message     = "P",
        purge_message       = "<C-p>",

        show                                     = "<leader>aiw",
        create_from_model_selection              = "<leader>ain",
        delete_from_selection                    = "<leader>aid",
        focus_from_selection                     = "<leader>aif",
        rename_from_selection                    = "<leader>air",
        set_model_from_selection                 = "<leader>aim",

        add_visual_as_input_and_query            = "<leader>ai<Enter>",
        add_visual_as_context                    = "<leader>aik",
        add_visual_as_instruction                = "<leader>aii",
        add_visual_as_input_query_and_append     = "<leader>aip",
        add_visual_as_input_query_and_prepend    = "<leader>aiP",
        add_visual_as_input_query_and_substitute = "<leader>ais",
      },
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

---@param conv table
---@return nil
local validate_conversation = function (conv)
  for _,msg in ipairs(conv) do
    vim.validate({
      message = {msg,        "t", false},
      role    = {msg.role,   "s", false},
      lines   = {msg.lines,  "t", false},
      status  = {msg.status, "s", true},
    })
    for _,line in ipairs(msg.lines) do
      vim.validate({
        line = {line, "s", false}
      })
    end
    if msg.status then
      if msg.status ~= "pruned" and msg.status ~= "purged" then
        error("invalid message status " .. msg.status)
      end
    end
  end
end

---@param registers table
---@return nil
local validate_registers = function (registers)
  for a,reg in pairs(registers) do
    vim.validate({
      register_name                        = {a,               "s",        false},
      ["register " .. a]                   = {reg,             "t",        false},
      ["register " .. a .. " postprocess"] = {reg.postprocess, {"s", "f"}, false},
    })
    if not string.match(a, "^[%d%l:\\.\\%#=\\*\\+_/]$") then
      error("invalid register name " .. a)
    end
    if type(reg.postprocess) == "string" then
      if reg.postprocess ~= "preserve" and reg.postprocess ~= "code" then
        error("invalid postprocessing for register " .. a " : " .. reg.postprocess)
      end
    end
  end
end

---@param model table
---@return nil
local validate_model_config = function (model)
  vim.validate({
    model                = {model, "t", false}
  })
  vim.validate({
    name           = {model.name,           "s",        true},
    implementation = {model.implementation, {"s", "f"}, false},
    opts           = {model.opts,           "t",        true},
    conversation   = {model.conversation,   {"s", "t"}, true},
    registers      = {model.registers,      "t",        true},
    autostart      = {model.autostart,      "b",        true},
  })
  if model.conversation and type(model.conversation) == "table" then
    validate_conversation(model.conversation)
  end
  if model.registers then
    validate_registers(model.registers)
  end
end

---@param naming table
---@return nil
local validate_naming = function (naming)
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

---@param interface table
---@return nil
local validate_interface = function (interface)
  vim.validate({
    telescope                 = {interface.telescope,                 "b", true},
    unique_session            = {interface.unique_session,            "b", true},
    couple_conv_input_windows = {interface.couple_conv_input_windows, "b", true},
    layout_relative           = {interface.layout_relative,           "s", true},
    layout_direction          = {interface.layout_direction,          "s", true},
    input_relative_height     = {interface.input_relative_height,     "n", true},
    highlight_role            = {interface.highlight_role,            "b", true},
    fold_instruction          = {interface.fold_instruction,          "b", true},
    fold_context              = {interface.fold_context,              "b", true},
    keymaps                   = {interface.keymaps,                   "t", true},
  })

  if interface.keymaps then
    local keymaps = interface.keymaps
    vim.validate({
      delete_interaction   = {keymaps.delete_interaction,  "s", true},
      delete_conversation  = {keymaps.delete_conversation, "s", true},
      delete_session       = {keymaps.delete_session,      "s", true},
      fork_session         = {keymaps.fork_session,        "s", true},
      rename_session       = {keymaps.rename_session,      "s", true},

      input_confirm        = {keymaps.input_confirm,       "s", true},
      input_instruction    = {keymaps.input_instruction,   "s", true},
      input_context        = {keymaps.input_context,       "s", true},

      prune_message        = {keymaps.prune_message,       "s", true},
      deprune_message      = {keymaps.deprune_message,     "s", true},
      purge_message        = {keymaps.purge_message,       "s", true},

      show                        = {keymaps.show,                        "s", true},
      create_from_model_selection = {keymaps.create_from_model_selection, "s", true},
      delete_from_selection       = {keymaps.delete_from_selection,       "s", true},
      focus_from_selection        = {keymaps.focus_from_selection,        "s", true},
      rename_from_selection       = {keymaps.rename_from_selection,       "s", true},
      set_model_from_selection    = {keymaps.set_model_from_selection,    "s", true},

      add_visual_as_input_and_query             =
        {keymaps.add_visual_as_input_and_query,            "s", true},
      add_visual_as_context                     =
        {keymaps.add_visual_as_context,                    "s", true},
      add_visual_as_instruction                 =
        {keymaps.add_visual_as_instruction,                "s", true},
      add_visual_as_input_query_and_append      =
        {keymaps.add_visual_as_input_query_and_append,     "s", true},
      add_visual_as_input_query_and_prepend     =
        {keymaps.add_visual_as_input_query_and_prepend,    "s", true},
      add_visual_as_input_query_and_substitute  =
        {keymaps.add_visual_as_input_query_and_substitute, "s", true},
    })
  end
end

---@param feedback table
---@return nil
local validate_feedback = function (feedback)
  vim.validate({
    highlight_message_while_receiving  = {feedback.highlight_message_while_receiving,  "b", true},
    pending_insertion_feedback         = {feedback.pending_insertion_feedback,         "b", true},
    pending_insertion_feedback_message = {feedback.pending_insertion_feedback_message, "s", true},
    conversation_lock                  = {feedback.conversation_lock,                  "t", true},
  })

  if feedback.conversation_lock then
    local conversation_lock = feedback.conversation_lock
    vim.validate({
      input_confirm     = {conversation_lock.input_confirm,     "b", true},
      input_instruction = {conversation_lock.input_instruction, "b", true},
      input_context     = {conversation_lock.input_context,     "b", true},
      warn_on_query     = {conversation_lock.warn_on_query,     "b", true},
      warn_on_clear     = {conversation_lock.warn_on_clear,     "b", true},
    })
  end
end

---@param opts table
---@return nil
local validate_facilellm_config = function (opts)
  vim.validate({
    opts = {opts, "t"},
  })
  vim.validate({
    -- default_model validated when validating models
    models            = {opts.models,            "t", true},
    conversations     = {opts.conversations,     "t", true},
    conversations_csv = {opts.conversations_csv, "s", true},
    naming            = {opts.naming,            "t", true},
    interface         = {opts.interface,         "t", true},
    feedback          = {opts.feedback,          "t", true},
  })

  if opts.models then
    vim.validate({
      default_model = {opts.default_model, {"s", "n"}, false},
    })

    local default_model_available = false
    if type(opts.default_model) == "number" then
      default_model_available = opts.models[opts.default_model] == nil
    end

    for _,model in ipairs(opts.models) do
      validate_model_config(model)
      if not default_model_available and model.name then
        default_model_available = model.name == opts.default_model
      end
    end

    if not default_model_available then
      error("default model not defined")
    end

  elseif opts.default_model then
    error("default model but no model defined")
  end

  if opts.conversations then
    for _,conv in pairs(opts.conversations) do
      validate_conversation(conv)
    end
  end

  if opts.naming then
    validate_naming(opts.naming)
  end

  if opts.interface then
    validate_interface(opts.interface)
  end

  if opts.feedback then
    validate_feedback(opts.feedback)
  end
end

---@param opts table
---@return FacileLLM.Config
local extend_facilellm_config = function (opts)
  opts = vim.tbl_deep_extend("force", default_opts(), opts)
  for mx,model in ipairs(opts.models) do
    opts.models[mx] = vim.tbl_deep_extend("keep", model, default_model_config())
  end
  if opts.conversations_csv then
    for name, conv in pairs(util.csv_to_conversations(opts.conversations_csv)) do
      opts.conversations[name] = conv
    end
    opts.conversations_csv = nil
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
  validate_facilellm_config(M.opts)

  set_highlights()
  set_global_keymaps()
  autostart_sessions(M.opts.models)
end


return M
