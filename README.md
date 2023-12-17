# FacileLLM

FacileLLM is a plugin for NeoVim that provides an interface to Large Language
Models (LLMs, aka AI). It is designed to be agnostic of the currently most
popular solutions and in particular can accommodate the use of locally run
models. The interface is designed to integrate well into the buffer-based
workflow of NeoVim. Some of the key points during design were:

* Multi-session and multi-model support allows for more flexible workflows that
  leverage the combined power of several LLMs. For example, it is possible to
  let a suitably fine-tuned model take over a conversation when needed. 

* Initial conversations (sometimes referred to "persona") are separate from
  models and thus modular.

* Separate recording of LLM instructions, context, examples, and input allow
  for more flexible, semi-automated prompt design.

* Pruning can help to make the best our of models of limited context length.

## Alternatives

I am aware of two LLM interfaces for NeoVim:
[NeoAI](https://github.com/Bryley/neoai.nvim/) and
[ChatGPT.nvim](https://github.com/jackMort/ChatGPT.nvim).

## License

Licensed under EuPL. For details see the `LICENSE` file and the [compatibility
matrix](https://joinup.ec.europa.eu/collection/eupl/matrix-eupl-compatible-open-source-licences)
published by the European Commission.

## Installation

Using the package manager [Lazy](https://github.com/folke/lazy.nvim), include
the following entry in your call to `require("lazy").setup`:

```lua
{
  "martinra/facilellm",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
  opts = {}
},
```

Can also remove telescope dependency, in which case some of the preview features during model, conversation, and session selection are not available:

```lua
{
  "martinra/facilellm",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  opts = {}
},
```

To integrate facileLLM into [Edgy](https://github.com/folke/edgy.nvim) include,
for instance, the follwoing in the call to `require("edgy").setup`:

```lua
options = {
 right = { size = 15 },
},
right = {
  {
    ft = "facilellm-conversation",
    open = function ()
      require("facilellm").show()
    end,
    wo = { winbar = false },
  },
  {
    title = "Input",
    ft = "facilellm-input",
    open = function ()
      require("facilellm").show()
    end,
    size = {height = 0.15},
  },
},
```

When using facileLLM in combination with Edgy, you probably want to use unique
sessions (see the configuration section. When using Lazy, you can achieve this
by including the following options:

```lua
opts = {
  interface = {
    unique_session = true,
    couple_conv_input_windows = true,
  },
},
```

## Global commands

### `show`

Show the most recently used session, presenting
both its conversation and input winow. If none is availabe create a new
session.

Bound by default to `<leader>aiw`.

### `select_default_model`

If several models are configured, this command lets you select the default one
that is used to create sessions without selecting a model explictly.

Bound by default to `<leader>aiM`.

### `create_from_model_selection`

Create a new session by selecting a model to instantiate it.

Bound by default to `<leader>ain`.

### `create_from_conversation_selection`

Create a new session using the default model but allowing for the selection of
an initial conversation.

Bound by default to `<leader>aib`.

### `create_from_model_conversation_selection`

Create a new session by selecting a model and and initial conversation.

Bound by default to `<leader>aiN`.

### `delete_from_selection`

Delete a session after selecting it.

Bound by default to `<leader>aid`.

### `focus_from_selection`

Focus a session after selecting it. When using unique sessions, this closes
other sessions currently presented.

Bound by default to `<leader>aif`.

### `rename_from_selection`

Rename a session after selecting it.

Bound by default to `<leader>air`.

### `set_model_from_selection`

Set the model of a selected session.

Bound by default to `<leader>aim`.

### `add_visual_as_input_and_query`

In visual mode, add the selected text as input for the current session and
then query the model for a response.

Bound by default to `<leader>ai<Enter>`.

### `add_visual_as_instruction`

In visual mode, add the selected text as an instruction to the current session.

Bound by default to `<leader>aii`.

### `add_visual_as_context`

In visual mode, add the selected text as context to the current session.

Bound by default to `<leader>aik`.

### `add_visual_as_example`

In visual mode, add the selected text as example to the current session.

Bound by default to `<leader>aie`.

### `add_visual_as_input_query_and_append`

In visual mode, add the selected text as input for the current session, then
query the model for a response, and once this response is completed insert it
after the selection.

Bound by default to `<leader>aip`.

### `add_visual_as_input_query_and_prepend`

Same as `add_visual_as_input_query_and_append`, but insert the response before
the selection.

Bound by default to `<leader>aiP`.

### `add_visual_as_input_query_and_substitute`

Same as `add_visual_as_input_query_and_append`, but delete the selection and
substitute the response once completely received.

Bound by default to `<leader>ais`.

### `add_line_as_input_and_query`

In normal mode, add the current line as input for the current session and
then query the model for a response.

Bound by default to `<leader>ai<Enter>`.

### `add_input_as_input_query_and_append`

In normal mode, add the current line as input for the current session, then
query the model for a response, and once this response is completed insert it
after the current line.

Bound by default to `<leader>aip`.

### `add_input_as_input_query_and_prepend`

Same as `add_input_as_input_query_and_append`, but insert the response before
the current lint.

Bound by default to `<leader>aiP`.

### `add_input_as_input_query_and_substitute`

Same as `add_input_as_input_query_and_append`, but delete the current line and
substitute the response once completely received.

Bound by default to `<leader>ais`.

## Local commands

Local commands are the ones awailable in the conversation and/or input buffer
of a session.

### `delete_interaction`

Delete the user input and the LLM responses of a session, but not the
instructions, the context, and the examples.

Bound by default to `<C-d>i`.

### `delete_conversation`

Delete the whole conversation of a session.

Bound by default to `<C-d>c`.

### `delete_session`

Delete a session.

Bound by default to `<C-s>d`.

### `fork_session`

Fork a session, replicating its current model configuration and conversation.

Bound by default to `<C-s>f`.

### `rename_session`

Rename a session.

Bound by default to `<C-s>r`.

### `input_confirm`

Include the provided input into the session conversation and query the LLM for
a response.

Bound by default to `<Enter>`. Only available in the input buffer. Consider
using `<C-o><Enter>` when in insert mode.

### `input_instruction`

Include the provided input as an instruction into the session conversation.

Bound by default to `<C-i>`. Only available in the input buffer. Consider
using `<C-o><C-i>` when in insert mode.


### `input_context`

Include the provided input as context into the session conversation.

Bound by default to `<C-k>`. Only available in the input buffer. Consider
using `<C-o><C-k>` when in insert mode.

### `input_example`

Include the provided input as an example into the session conversation.

Bound by default to `<C-e>`. Only available in the input buffer. Consider
using `<C-o><C-e>` when in insert mode.

### `requery`

Purge the last LLM response and re-query it.

Bound by default to `<C-r>`.

### `prune_message`

Prune the message under the cursor. Pruned messages are usually not provided to
the LLM when querying it.

Bound by default to `p`. Only availabe in the conversation buffer.

### `deprune_message`

De-prune the message under the cursor. 

Bound by default to `P`. Only availabe in the conversation buffer.

### `purge_message`

Purge the message under the cursor. Purged messages cannot be recovered.

Bound by default to `<C-p>`. Only availabe in the conversation buffer.

## Setup

The function `setup` (or alternatively the `opts` structure when using Lazy) is
subdivided into tables:

```lua
opts = {
  default_model = "Model Name",
  models = {},
  conversations = {},
  conversations_csv = nil,
  naming = {},
  interface = {},
  feedback = {},
},
```

The default model must be given. It can be an index to the model list, or
preferably one of the names of a model included in this list. 

### Model configuration

The model is a list of model configuratons. A complete and functional example
configuration of a model is

```lua
{
  name           = "ChatGPT 3.5 (Hot)",
  implementation = "OpenAI API",
  opts           = {
    url = "https://api.openai.com/v1/chat/completions",
    get_api_key = function ()
      local key = vim.fn.system("pass show OpenAI/facilellm_token")
      key = string.gsub(key, "\n", "")
      return key
    end,
    openai_model = "gpt-3.5-turbo",
    params = {
      temperature = 0.9,
    },
  },
  conversation   = {},
  registers      = {
    ["l"] = { postprocess = "preserve" },
    ["c"] = { postprocess = "code" },
  },
  autostart      = false,
}
```

The implementation must be a string identifying one of the available model
implementations, or a structure with a `create` and a `preview` function.
Details on this are currently only available in the source code.

The field `opts` is forwarded to both the `create` and the `preview` functions
and depends on the model implementation.

The field `conversation` can be an intial conversation or the name of a
conversation that is made available through the `conversations` or
`conversations_csv` fields during the setup.

The field `registers` is a list of registers together with a postprocessing
function or a string referring to one of the provided implementations.

A session is started automatically if the field `autostart` is set to true.

### OpenAI API configuration

The `opts` field in the model configuration is specific to the model
implementation. For the OpenAI API that is provided in facileLLM, the fields
are as follows:

```lua
opts = {
  url = "https://api.openai.com/v1/chat/completions",
  get_api_key = function ()
    local key = vim.fn.system("pass show OpenAI/facilellm_token")
    key = string.gsub(key, "\n", "")
    return key
  end,
  openai_model = "gpt-3.5-turbo",
  params = {
    temperature = 0.9,
  },
},
```

The `url` points to an address that will be interacted with through curl. The
default points to the api endpoint of OpenAI the company.

The field `get_api_key` is a function that acquires the API key. It defaults to
an input prompt, but in the example above invokes a password manager.

The field `openai_model` specifies the model provided by the API. The default
points to GPT-3.5 Turbo.

The field `params` specifies parameters that are provided to the model when
calling the API. Changes to fields of `params` after initializing a session
take effect on future API calls. This allows for exmaple to adjust the
temperature of a model without having to setup many of them.

### Conversation configuration

Conversations can be given in two ways. To explicitly configure a list of them
use the field `conversations`. For example, the default configuration includes:

```lua
conversations = {
  ["Empty"] = {},
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
```

To amend this list by further options that are extracted from a CSV file use
`conversations_csv`. The intention behind this option is to accommodate the use of
["Awesome ChatGPT Prompts"](`https://raw.githubusercontent.com/f/awesome-chatgpt-prompts/main/prompts.csv`)
and similar prompt files. They are intentionally not included in facileLLM, but
those who wish to use them can download the CSV file to a path of their choice
and use the following code to load it:

```lua
conversations_csv = (function ()
  io.input(path .. "/promts.csv")
  local csv = io.read("*a")
  io.input()
  local fst_linebreak = string.find(csv, "\n")
  csv = string.sub(csv, fst_linebreak+1, string.len(csv))
  return csv
end)(),
```

### Naming configuration

These options determine the text displayed by facileLLM. The default is

```lua
naming = {
  role_display = {
    instruction = "Instruction:",
    context     = "Context:",
    example     = "Example:",
    input       = "Input:",
    llm         = "LLM:",
  },
  conversation_buffer_prefix = "facileLLM",
  input_buffer_prefix = "facileLLM Input",
  fork_suffix = "Fork",
},
```

### Interface configuration

The interface configuration includes the keymaps, which we give separately below.

```lua
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
  fold_example              = true,
  keymaps = {},
},
```

### Keymap configuration

```lua
keymaps = {
  delete_interaction  = "<C-d>i",
  delete_conversation = "<C-d>c",
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

  show                                     = "<leader>aiw",
  select_default_model                     = "<leader>aiM",
  create_from_model_selection              = "<leader>ain",
  create_from_conversation_selection       = "<leader>aib",
  create_from_model_conversation_selection = "<leader>aiN",
  delete_from_selection                    = "<leader>aid",
  focus_from_selection                     = "<leader>aif",
  rename_from_selection                    = "<leader>air",
  set_model_from_selection                 = "<leader>aim",

  add_visual_as_input_and_query            = "<leader>ai<Enter>",
  add_visual_as_instruction                = "<leader>aii",
  add_visual_as_context                    = "<leader>aik",
  add_visual_as_example                    = "<leader>aie",
  add_visual_as_input_query_and_append     = "<leader>aip",
  add_visual_as_input_query_and_prepend    = "<leader>aiP",
  add_visual_as_input_query_and_substitute = "<leader>ais",
},
```

### Feedback configuration

The feedback configuration allows to tweak the feedback provided by facileLLM.

```lua
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
```

### Theming

FacileLLM uses the following highlights that are link to default highlight, but
can be configured separately.

```lua
FacileLLMRole: markdownH1
FacileLLMMsgReceiving: DiffAdd
FacileLLMMsgPruned: DiffDelete
```

## Example usage

FacileLLM intentionally does not include prebuilt complex workflows. This is
the bussiness of more integrated solutions like LunarVIM once they include an
LLM interface. The plan is to include in this place a list of possible usage to
illustrate the possibilities.
