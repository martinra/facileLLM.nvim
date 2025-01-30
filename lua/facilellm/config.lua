---@class FacileLLM.Config
---@field default_provider string | integer
---@field providers FacileLLM.Config.Provider[]
---@field conversations table<FacileLLM.ConversationName, FacileLLM.Conversation>
---@field conversations_csv string?
---@field naming FacileLLM.Config.Naming
---@field interface FacileLLM.Config.Interface
---@field feedback FacileLLM.Config.Feedback

---@class FacileLLM.Config.Provider
---@field name string?
---@field implementation FacileLLM.Provider.Implementation
---@field opts table Options that are forwarded to the implementation.
---@field conversation FacileLLM.ConversationName | FacileLLM.Conversation
---@field registers FacileLLM.Config.Register[]
---@field autostart boolean
---@field autoclear boolean

---@class FacileLLM.Config.Naming
---@field role_display FacileLLM.Config.Naming.RoleDisplay
---@field conversation_buffer_prefix string
---@field input_buffer_prefix string
---@field fork_suffix string

---@class FacileLLM.Config.Naming.RoleDisplay
---@field instruction string
---@field context string
---@field example string
---@field input string
---@field llm string

---@class FacileLLM.Config.Interface
---@field telescope boolean
---@field unique_session boolean
---@field couple_conv_input_windows boolean
---@field layout_relative ("editor"| "win")
---@field layout_direction ("right"| "left")
---@field width integer
---@field input_relative_height number
---@field highlight_role boolean
---@field fold_instruction boolean
---@field fold_context boolean
---@field fold_example boolean
---@field keymaps FacileLLM.Config.Interface.Keymaps

---@class FacileLLM.Config.Interface.Keymaps
---@field clear_interaction string
---@field clear_conversation string
---@field delete_session string
---@field fork_session string
---@field rename_session string
---@field input_confirm string
---@field input_instruction string
---@field input_context string
---@field input_example string
---@field requery string
---@field prune_message string
---@field deprune_message string
---@field purge_message string
---@field show string
---@field select_default_provider string
---@field create_from_provider_selection string
---@field create_from_conversation_selection string
---@field create_from_provider_conversation_selection string
---@field delete_from_selection string
---@field focus_from_selection string
---@field rename_from_selection string
---@field set_provider_from_selection string
---@field add_visual_as_input_and_query string
---@field add_visual_as_instruction string
---@field add_visual_as_context string
---@field add_visual_as_example string
---@field add_visual_as_input_query_and_append string
---@field add_visual_as_input_query_and_prepend string
---@field add_visual_as_input_query_and_substitute string
---@field add_line_as_input_and_query string
---@field add_line_as_input_query_and_append string
---@field add_line_as_input_query_and_prepend string
---@field add_line_as_input_query_and_substitute string

---@class FacileLLM.Config.Feedback
---@field highlight_message_while_receiving boolean
---@field pending_insertion_feedback boolean
---@field pending_insertion_feedback_message string
---@field conversation_lock FacileLLM.Config.Feedback.ConversationLock

---@class FacileLLM.Config.Feedback.ConversationLock
---@field input_confirm boolean
---@field input_instruction boolean
---@field input_context boolean
---@field input_example boolean
---@field warn_on_query boolean
---@field warn_on_clear boolean

---@class FacileLLM.Config.Register
---@field names string
---@field postprocess function?(FacileLLM.Message): (nil | string | string[])


local ui_recent = require("facilellm.ui.recent_session")
local util = require("facilellm.util")


---@return nil
local set_highlights = function ()
  vim.api.nvim_set_hl(0, "FacileLLMRole", {link = "Title", default = true})
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
  if config.opts.interface.keymaps.select_default_provider ~= "" then
    vim.keymap.set("n", config.opts.interface.keymaps.select_default_provider,
      facilellm.select_default_provider, {})
  end
  if config.opts.interface.keymaps.create_from_provider_selection ~= "" then
    vim.keymap.set("n", config.opts.interface.keymaps.create_from_provider_selection,
      facilellm.create_from_provider_selection, {})
  end
  if config.opts.interface.keymaps.create_from_conversation_selection ~= "" then
    vim.keymap.set("n", config.opts.interface.keymaps.create_from_conversation_selection,
      facilellm.create_from_conversation_selection, {})
  end
  if config.opts.interface.keymaps.create_from_provider_conversation_selection ~= "" then
    vim.keymap.set("n", config.opts.interface.keymaps.create_from_provider_conversation_selection,
      facilellm.create_from_provider_conversation_selection, {})
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
  if config.opts.interface.keymaps.set_provider_from_selection ~= "" then
    vim.keymap.set("n", config.opts.interface.keymaps.set_provider_from_selection,
      facilellm.set_provider_from_selection, {})
  end

  if config.opts.interface.keymaps.add_visual_as_input_and_query ~= "" then
    vim.keymap.set("v", config.opts.interface.keymaps.add_visual_as_input_and_query,
      facilellm.add_visual_as_input_and_query, {})
  end
  if config.opts.interface.keymaps.add_visual_as_instruction ~= "" then
    vim.keymap.set("v", config.opts.interface.keymaps.add_visual_as_instruction,
      facilellm.add_visual_as_instruction, {})
  end
  if config.opts.interface.keymaps.add_visual_as_context ~= "" then
    vim.keymap.set("v", config.opts.interface.keymaps.add_visual_as_context,
      facilellm.add_visual_as_context, {})
  end
  if config.opts.interface.keymaps.add_visual_as_example ~= "" then
    vim.keymap.set("v", config.opts.interface.keymaps.add_visual_as_example,
      facilellm.add_visual_as_example, {})
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

  if config.opts.interface.keymaps.add_line_as_input_and_query ~= "" then
    vim.keymap.set("n", config.opts.interface.keymaps.add_line_as_input_and_query,
      facilellm.add_line_as_input_and_query, {})
  end
  if config.opts.interface.keymaps.add_line_as_input_query_and_append ~= "" then
    vim.keymap.set("n", config.opts.interface.keymaps.add_line_as_input_query_and_append,
      function () facilellm.add_line_as_input_query_and_insert("append") end, {})
  end
  if config.opts.interface.keymaps.add_line_as_input_query_and_prepend ~= "" then
    vim.keymap.set("n", config.opts.interface.keymaps.add_line_as_input_query_and_prepend,
      function () facilellm.add_line_as_input_query_and_insert("prepend") end, {})
  end
  if config.opts.interface.keymaps.add_line_as_input_query_and_substitute ~= "" then
    vim.keymap.set("n", config.opts.interface.keymaps.add_line_as_input_query_and_substitute,
      function () facilellm.add_line_as_input_query_and_insert("substitute") end, {}
    )
  end
end

---@param providers FacileLLM.Config.Provider[]
---@return nil
local autostart_sessions = function (providers)
  local ui_session = require("facilellm.ui.session")
  local touched = false
  for _,provider in ipairs(providers) do
    if provider.autostart then
      local sess = ui_session.create(provider)
      if not touched then
        ui_recent.touch(sess)
        touched = true
      end
    end
  end
end

---@return FacileLLM.Config.Provider
local default_provider_config = function ()
  return {
    name           = nil,
    implementation = "undefined",
    opts           = {},
    conversation   = {},
    registers      = {
      {
        names = "l",
      },
    },
    autostart      = false,
    autoclear      = false,
  }
end

---@return FacileLLM.Config
local default_opts = function ()
  return {
    default_provider = "OpenAI GPT 3.5-Turbo",
    providers = {
      {
        name = "OpenAI GPT 3.5-Turbo",
        implementation = require("facilellm.provider.api.openai"),
        opts = {
          openai_model = "gpt-3.5-turbo",
        },
      },
      {
        name = "OpenAI GPT 4",
        implementation = require("facilellm.provider.api.openai"),
        opts = {
          openai_model = "gpt-4",
        },
      },
      {
        name = "OpenAI GPT 4 32K",
        implementation = require("facilellm.provider.api.openai"),
        opts = {
          openai_model = "gpt-4-32k",
        },
      },
    },

    conversations = {
      ["Blank conversation"] = {},
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
        instruction = "## Instruction:",
        context     = "## Context:",
        example     = "## Example:",
        input       = "## Input:",
        llm         = "## LLM:",
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
      width                     = 0,
      input_relative_height     = 0.15,
      highlight_role            = true,
      fold_instruction          = true,
      fold_context              = true,
      fold_example              = true,
      keymaps = {
        clear_interaction   = "<C-d>i",
        clear_conversation  = "<C-d>c",
        delete_session      = "<C-s>d",
        fork_session        = "<C-s>f",
        rename_session      = "<C-s>r",

        input_confirm       = "<Enter>",
        input_instruction   = "<C-i>",
        input_context       = "<C-k>",
        input_example       = "<C-e>",
        requery             = "<C-r>",

        prune_message       = "p",
        deprune_message     = "P",
        purge_message       = "<C-p>",

        show                                        = "<leader>aiw",
        select_default_provider                     = "<leader>aiP",
        create_from_provider_selection              = "<leader>ain",
        create_from_conversation_selection          = "<leader>aib",
        create_from_provider_conversation_selection = "<leader>aiN",
        delete_from_selection                       = "<leader>aid",
        focus_from_selection                        = "<leader>aif",
        rename_from_selection                       = "<leader>air",
        set_provider_from_selection                 = "<leader>aip",

        add_visual_as_input_and_query            = "<leader>ai<Enter>",
        add_visual_as_instruction                = "<leader>aii",
        add_visual_as_context                    = "<leader>aik",
        add_visual_as_example                    = "<leader>aie",
        add_visual_as_input_query_and_append     = "<leader>aip",
        add_visual_as_input_query_and_prepend    = "<leader>aiP",
        add_visual_as_input_query_and_substitute = "<leader>ais",
        add_line_as_input_and_query              = "<leader>ai<Enter>",
        add_line_as_input_query_and_append       = "<leader>aip",
        add_line_as_input_query_and_prepend      = "<leader>aiP",
        add_line_as_input_query_and_substitute   = "<leader>ais",
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
        input_example     = true,
        warn_on_query     = true,
        warn_on_clear     = true,
      },
    },
  }
end

---@param impl table
---@return nil
local validate_implementation = function (impl)
  vim.validate({
    implementation = {impl,         "t", false},
    create         = {impl.create,  "f", false},
    preview        = {impl.preview, "f", true},
  })
end

---@param conv table
---@return nil
local validate_conversation = function (conv)
  if conv.role or conv.lines or conv.status then
    error("invalid conversation: role, line, or status on top level")
  end

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
      if string.find(line, "\n") then
        error("invalid message line: contains newline")
      end
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
  for _,reg in ipairs(registers) do
    vim.validate({
      register_names       = {reg.names,       "s", false},
      register_postprocess = {reg.postprocess, "f", true},
    })
    if not string.match(reg.names, "^[%d%l:\\.\\%#=\\*\\+_/]+$") then
      error("invalid register names " .. reg.names)
    end
  end
end

---@param provider table
---@return nil
local validate_provider_config = function (provider)
  vim.validate({
    provider       = {provider, "t", false}
  })
  vim.validate({
    name           = {provider.name,           "s",        true},
    implementation = {provider.implementation, {"s", "t"}, false},
    opts           = {provider.opts,           "t",        true},
    conversation   = {provider.conversation,   {"s", "t"}, true},
    registers      = {provider.registers,      "t",        true},
    autostart      = {provider.autostart,      "b",        true},
    autoclear      = {provider.autoclear,      "b",        true},
  })
  if provider.implementation and type(provider.implementation) == "table" then
    validate_implementation(provider.implementation)
  end
  if provider.conversation and type(provider.conversation) == "table" then
    validate_conversation(provider.conversation)
  end
  if provider.registers then
    validate_registers(provider.registers)
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
      example     = {role_display.example,     "s", true},
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
    width                     = {interface.width,                     "n", true},
    input_relative_height     = {interface.input_relative_height,     "n", true},
    highlight_role            = {interface.highlight_role,            "b", true},
    fold_instruction          = {interface.fold_instruction,          "b", true},
    fold_context              = {interface.fold_context,              "b", true},
    fold_example              = {interface.fold_example,              "b", true},
    keymaps                   = {interface.keymaps,                   "t", true},
  })

  if interface.keymaps then
    local keymaps = interface.keymaps
    vim.validate({
      clear_interaction    = {keymaps.clear_interaction,   "s", true},
      clear_conversation   = {keymaps.clear_conversation,  "s", true},
      delete_session       = {keymaps.delete_session,      "s", true},
      fork_session         = {keymaps.fork_session,        "s", true},
      rename_session       = {keymaps.rename_session,      "s", true},

      input_confirm        = {keymaps.input_confirm,       "s", true},
      input_instruction    = {keymaps.input_instruction,   "s", true},
      input_context        = {keymaps.input_context,       "s", true},
      input_example        = {keymaps.input_example,       "s", true},

      prune_message        = {keymaps.prune_message,       "s", true},
      deprune_message      = {keymaps.deprune_message,     "s", true},
      purge_message        = {keymaps.purge_message,       "s", true},

      show                        = {keymaps.show,                        "s", true},
      select_default_provider     = {keymaps.select_default_provider,     "s", true},
      create_from_provider_selection =
        {keymaps.create_from_provider_selection, "s", true},
      create_from_provider_conversation_selection =
        {keymaps.create_from_provider_conversation_selection, "s", true},
      delete_from_selection       = {keymaps.delete_from_selection,       "s", true},
      focus_from_selection        = {keymaps.focus_from_selection,        "s", true},
      rename_from_selection       = {keymaps.rename_from_selection,       "s", true},
      set_provider_from_selection = {keymaps.set_provider_from_selection, "s", true},

      add_visual_as_input_and_query             =
        {keymaps.add_visual_as_input_and_query,            "s", true},
      add_visual_as_instruction                 =
        {keymaps.add_visual_as_instruction,                "s", true},
      add_visual_as_context                     =
        {keymaps.add_visual_as_context,                    "s", true},
      add_visual_as_example                     =
        {keymaps.add_visual_as_example,                    "s", true},
      add_visual_as_input_query_and_append      =
        {keymaps.add_visual_as_input_query_and_append,     "s", true},
      add_visual_as_input_query_and_prepend     =
        {keymaps.add_visual_as_input_query_and_prepend,    "s", true},
      add_visual_as_input_query_and_substitute  =
        {keymaps.add_visual_as_input_query_and_substitute, "s", true},

      add_line_as_input_and_query             =
        {keymaps.add_line_as_input_and_query,            "s", true},
      add_line_as_input_query_and_append      =
        {keymaps.add_line_as_input_query_and_append,     "s", true},
      add_line_as_input_query_and_prepend     =
        {keymaps.add_line_as_input_query_and_prepend,    "s", true},
      add_line_as_input_query_and_substitute  =
        {keymaps.add_line_as_input_query_and_substitute, "s", true},
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
      input_example     = {conversation_lock.input_example,     "b", true},
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
    -- default_provider validated when validating providers
    providers         = {opts.providers,            "t", true},
    conversations     = {opts.conversations,     "t", true},
    conversations_csv = {opts.conversations_csv, "s", true},
    naming            = {opts.naming,            "t", true},
    interface         = {opts.interface,         "t", true},
    feedback          = {opts.feedback,          "t", true},
  })

  if opts.providers then
    vim.validate({
      default_provider = {opts.default_provider, {"s", "n"}, false},
    })

    local default_provider_available = false
    if type(opts.default_provider) == "number" then
      default_provider_available = opts.providers[opts.default_provider] == nil
    end

    for _,provider in ipairs(opts.providers) do
      validate_provider_config(provider)
      if not default_provider_available and provider.name then
        default_provider_available = provider.name == opts.default_provider
      end
    end

    if not default_provider_available then
      error("default provider not defined")
    end

  elseif opts.default_provider then
    error("default provider but no provider defined")
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
  for px,provider in ipairs(opts.providers) do
    opts.providers[px] = vim.tbl_deep_extend("force", default_provider_config(), provider)
  end
  if opts.conversations_csv then
    for name, conv in pairs(util.csv_to_conversations(opts.conversations_csv)) do
      opts.conversations[name] = conv
    end
    opts.conversations_csv = nil
  end
  return opts
end


local M = {
  opts = nil,
}

---@param opts table?
---@return nil
M.setup = function (opts)
  opts = opts or {}
  validate_facilellm_config(opts)
  M.opts = extend_facilellm_config(opts)
  validate_facilellm_config(M.opts)

  set_highlights()
  set_global_keymaps()
  autostart_sessions(M.opts.providers)
end


return M
