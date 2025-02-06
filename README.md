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

* Implementation of the OpenAI API and in particular OpenRouterAI and ChatGPT
  in its various versions.

* Implementation of the Replicate API. Ready access to LLama3 70B Instruct,
  Mixtral 8x7B Instruct, and the possibility to connect to any open LLM model
  by only providing prompt encoding.

## Alternatives

I am aware of two LLM interfaces for NeoVim:
[NeoAI](https://github.com/Bryley/neoai.nvim/),
[ChatGPT.nvim](https://github.com/jackMort/ChatGPT.nvim), and
- [Avante.nvim](https://github.com/yetone/avante.nvim).

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

You can remove the telescope dependency, in which case some of the preview features during provider, conversation, and session selection are not available:

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
for instance, the following in the call to `require("edgy").setup`:

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
sessions (see the configuration section for and explanation). When using Lazy,
you can achieve this by including the following options:

```lua
opts = {
  interface = {
    unique_session = true,
    couple_conv_input_windows = true,
  },
},
```

## Setup

The function `setup` (or alternatively the `opts` structure when using Lazy) is
subdivided into tables:

```lua
opts = {
  default_provider = "Provider Name",
  providers = {},
  conversations = {},
  conversations_csv = nil,
  naming = {},
  interface = {},
  feedback = {},
},
```

The default provider must be given. It can be an index to the provider list, or
preferably one of the names of a provider included in this list. 

### Provider configuration

The field `providers` is a list of provider configuratons. A complete and
functional example configuration of a provider is

```lua
{
  name           = "ChatGPT 3.5 (Hot)",
  implementation = "OpenAI API",
  opts           = {
    url = "https://api.openai.com/v1/chat/completions",
    get_api_key = function ()
      return require("facilellm.provider.util").get_api_key_from_pass("OpenAI/facilellm_token")
    end,
    openai_model = "gpt-3.5-turbo",
    params = {
      temperature = 0.9,
    },
  },
  conversation   = {},
  registers      = {
    {
      names = "l",
    },
    {
      names = "c",
      postprocess = function (lines)
        return string.match(table.concat(lines, "\n"), "```\n(.-\n)```")
      end,
    },
    {
      names = "vb",
      postprocess = function (lines)
        clines = table.concat(lines, "\n")
        return {
          string.match(clines, "```\n([^`]-\n)```"),
          string.match(clines, "```\n[^`]-\n```(.-)"),
        }
      end,
    },
  },
  autostart      = false,
}
```

The implementation must be a string identifying one of the available API
implementations, or a structure with a `create` and a `preview` function.
Details on the latter are currently only available in the source code. The
 accepted strings are `OpenAI API` and `Replicate MistralAI`.

The field `opts` is forwarded to both the `create` and the `preview` functions
and depends on the API implementation. In the example configuration, the API
key is retrieved through the Linux password manager `pass`. In general,
`get_api_key` is a function that returns the API key as a string. This includes
the (strongly dicouraged) possibility to hardcode it in the configuration as a
return value.

The field `conversation` can be an intial conversation or the name of a
conversation that is made available through the `conversations` or
`conversations_csv` fields during the setup.

The field `registers` is a list of registers that will be populated together
with an optional postprocessing function. If several names are given and the
postprocessing function returns a list of strings, registers are set to the
corresponding string in given order.

A session is started automatically if the field `autostart` is set to true.

### OpenAI API configuration

The `opts` field in the provider configuration is specific to the API
implementation. For the OpenAI API that is provided in facileLLM, the fields
are as follows:

```lua
opts = {
  url = "https://api.openai.com/v1/chat/completions",
  get_api_key = function ()
    return require("facilellm.provider.util").get_api_key_from_pass("OpenAI/facilellm_token")
  end,
  openai_model = "gpt-3.5-turbo",
  params = {
    temperature = 0.9,
    max_tokens = 1024,
    top_p = 1,
    frequency_penalty = 0,
    presence_penalty = 0,
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
take effect on future API calls. This allows for example to adjust the
temperature of a model without having to setup many of them.

### Llama3 via Replicate configuration

The next provider is an instance of a Meta model run via the Replicate API.

```lua
implementation = "Replicate Meta",
```

The options that are available to change are 

```lua
opts = {
  url = "https://api.replicate.com/v1/models/meta/meta-llama-3-8b-instruct/predictions",
  get_api_key = function ()
    return require("facilellm.provider.util").get_api_key_from_pass("Replicate/facilellm_token")
  end,
  replicate_version = nil,
  replicate_model_name = "Llama3 8b Instruct",
  prompt_conversion = require("facilellm.provider.model.llama3_prompt"),
  params = {
    temperature = 0.6,
    top_p = 0.9,
    top_k = 50,
    presence_penalty = 0,
    max_new_tokens = 1024,
  },
},
```

### MistralAI via Replicate configuration

This provider is an instance of a MistralAI model run via the Replicate API.

```lua
implementation = "Replicate MistralAI",
```

The options that are available to change are 

```lua
opts = {
  url = "https://api.replicate.com/v1/models/mistralai/mixtral-8x7b-instruct-v0.1/predictions",
  get_api_key = function ()
    return require("facilellm.provider.util").get_api_key_from_pass("Replicate/facilellm_token")
  end,
  replicate_version = nil,
  replicate_model_name = "Mixtral 8x7B Instruct v0.1",
  prompt_conversion = require("facilellm.provider.model.mixtral_prompt"),
  params = {
    temperature = 0.6,
    top_p = 0.9,
    top_k = 50,
    presence_penalty = 0,
    frequency_penalty = 0,
    max_new_tokens = 1024,
  },
},
```

### Replicate API

The implementations of Llama3 and Mixtral are a combination of a Replicate
specific API implementation combined with prompt encoding specific to the
model. In particular the Replicate API can be used to provide implementations
for other models by merely replacing the prompt encoder. Details on this are
currently only available in the source code.

### Conversation configuration

Conversations can be given in two ways. To explicitly configure a list of them
use the field `conversations`. For example, the default configuration includes:

```lua
conversations = {
  ["Blank"] = {},
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
(referenced in the following code as `path`) and use the following code to load
it:

```lua
conversations_csv = (function ()
  local plenary_path = require("plenary.path")
  local csv = plenary_path:new(path .. "/promts.csv"):read()
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

  show                                     = "<leader>aiw",
  select_default_provider                  = "<leader>aiP",
  create_from_provider_selection           = "<leader>ain",
  create_from_conversation_selection       = "<leader>aib",
  create_from_provider_conversation_selection = "<leader>aiN",
  delete_from_selection                    = "<leader>aid",
  focus_from_selection                     = "<leader>aif",
  rename_from_selection                    = "<leader>air",
  set_provider_from_selection              = "<leader>aip",

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
the business of more integrated solutions like LunarVIM once they include an
LLM interface.

This section includes examples of how the FacileLLM can be used to support some
workflows. Their descriptions will include prompts, and as such display
techniques of prompt engineering. They are the result of best-effort but little
profound knowledge on the topic. Two disclaimers are thus due: First, do not
overrate the suggested prompts and view them as not more than an inspiration.
Second, be aware that the use of fine-tuned models specific to the intended
purposes seems superior to prompt engineering. However a combination of both
might indeed work best.

### Basic interaction: Creating new prompts

What could be more natural than creating LLM prompts by ... prompting an LLM?
Include the following conversation into your configuration:

```lua
["Prompt Engineer"] = {
  {
    role = "Instruction",
    lines = {
         "You are a prompt engineer for ChatGPT working on creating the most "
      .. "efficient and precise prompts. You have ample experience in the field "
      .. "and know all tricks and tweaks."
    },
  },
},
```

We start by creating a new session with default model and configurable
background: `<leader>aib` in normal mode. Select the "Prompt Engineer"
conversation. The cursor should be placed in a window showing the input buffer
of the new FacileLLM session.

In the input buffer write:

```
Suggest ChatGPT instructions that trigger it to generate new Spanish vocabulary at level C1.
```

Submit the text by `<CR>` in normal mode (or `<C-o><CR>` in insert mode).

A possible generated answer is:

```
Sure! Here are some ChatGPT instructions that can trigger it to generate new Spanish vocabulary at level C1:

1. "Please provide me with a list of advanced Spanish vocabulary words related to technology and innovation."
2. "Generate a set of complex Spanish idioms and their meanings."
3. "Can you give examples of sophisticated Spanish adjectives to describe emotions and feelings?"
4. "I want to expand my Spanish vocabulary at a C1 level. Could you suggest some advanced words related to finance and economics?"
5. "Create a list of advanced Spanish verbs used in academic writing and their corresponding noun forms."
6. "Can you generate a collection of advanced Spanish vocabulary related to art, literature, and culture?"
7. "I'm preparing for an advanced Spanish exam. Please provide me with a variety of complex vocabulary words in different categories - science, politics, environment, etc."
8. "I'm looking to enhance my Spanish vocabulary for business purposes. Can you suggest some advanced words and phrases commonly used in professional settings?"

Remember to specify the desired level (C1) and the specific topic or context to generate more precise and relevant Spanish vocabulary.
```

If the response is too far from what you have hoped you can regenerate the response by `<C-r>`.

To further refine the prompts, write in the input buffer:

```
Include instructions to generate a CSV file for import into Anki.
```

Again submit via `<CR>` in normal mode and continue. When finished copy the
last LLM response to your working buffer from the register `l`, that is in
normal mode invoke for instance `"lp`. Then delete the session by one of the
following two actions: `<leader>aid` to select a session for deletion. Or with
the cursor in the output or input buffer of that facileLLM session use `<C-s>d`
in normal mode.

### Context and pruning/purging: Creating new prompts II

While attempting to be exhaustive, the list of prompts created in the first
attempt was wide. It is more efficient to narrow down quickly to the required
topic. Specificity in the user prompt is one aspect, but context and example
instructions can have even stronger impact. While the details depend on the
model implementation, they should normally mapped to the system prompt.

Initiate a new session with the "Prompt Engineer" conversation. In the session
input buffer write:

```
We design a system prompt to make ChatGPT act as a Spanish teacher.
```

Submit this in normal mode with `<C-k>` to provide it as context. Only now we
submit input (use `<CR>` in normal mode after writing in the input buffer).

```
Suggest system prompts to help generating new vocabulary at level C1. Provide three options and only show the suggested system prompt.
```

The generate answer could look like:

```
Option 1:
System Prompt: "You are a Spanish teacher helping a student at level C1 expand their vocabulary. Start the conversation by discussing a topic related to travel and ask the student to share some specific vocabulary they would like to learn."

Option 2:
System Prompt: "As a Spanish teacher, you want to assist a student at level C1 in acquiring new vocabulary. Begin the conversation by asking the student to describe their favorite book or movie in Spanish and encourage them to identify any unfamiliar words or phrases they encountered."

Option 3:
System Prompt: "Imagine you are a Spanish teacher guiding a student at level C1 in their vocabulary development. Initiate the conversation by discussing the benefits of learning new words and ask the student to express their interest in a particular field or topic they would like to expand their vocabulary in."
```

Now this is much more helpful than what we obtained in the first attempt. We
will make an erroneous attempt at refining the third option, then revert that
part of the conversation and make a second attempt.

```
Continuing with Option 3, add instructions that vocabulary list have to always include CSV list for import into Anki.
```

We first want to remove the instruction to discuss the benefits of learning new
words, and only then want to add the Anki version. The best move here seems to
revert the conversation. Change into the output window and put at any position
in the last LLM response, then purge this message by `<C-p>` in normal mode.
The message will disappear. Move the cursor on the last input message and by
`p` prune it, which will mark it red (in default theming). In this way you can
later copy it back into the input buffer. You could also "deprune" it using
`<S-p>`.

We now provide the input

```
Continuing with Option 3, remove the instruction to discuss the benefits of learning new words.
```

In an example run, this yields

```
Option 3:
System Prompt: "Imagine you are a Spanish teacher guiding a student at level C1 in their vocabulary development. Initiate the conversation by asking the student to express their interest in a particular field or topic they would like to expand their vocabulary in."
```

Now change to the output buffer and yank the message that you have pruned and insert into the input buffer (or type from scratch):

```
Add instructions that vocabulary list have to always include CSV list for import into Anki.
```

The answer is quite satisfying:

```
Option 3:
System Prompt: "Imagine you are a Spanish teacher guiding a student at level C1 in their vocabulary development. Initiate the conversation by asking the student to express their interest in a particular field or topic they would like to expand their vocabulary in. Once they provide the topic, make sure to create a vocabulary list that includes a CSV file for easy import into Anki, a flashcard application."
```

One might feel tempted to instruct to remove the headline and quotes, but since
you are using an efficient text editor, just quickly make that change yourself
after pasting from register `l` into a work buffer.

### Instructions and examples: Creating vocabulary lists

We now use the previously obtained system prompt, but amend it by examples.
This particularly helpful when handling fixed formats like the CSV format that
we will request for import into Anki.

Starting a blank conversation, insert the prompt into the input buffer and
submit as instruction by `<C-i>` in normal mode:

```
Imagine you are a Spanish teacher guiding a student at level C1 in their vocabulary development. Initiate the conversation by asking the student to express their interest in a particular field or topic they would like to expand their vocabulary in. Once they provide the topic, make sure to create a vocabulary list that includes a CSV file for easy import into Anki, a flashcard application.
```

When providing examples, ideally all common variation are coverted. In the
example these are words with several translations and idiomatic expressions.
Tweak this example also to match the type of vocabulary that you would prefer
to see. You submit it as an example by `<C-e>`:

```
auricular; ear phones
ruborizarse; to blush
un micro; a local bus
ser corto de vista; to be short sighted
puño; fist, handle
```

To give the setup a try provide as input:

```
Suggest 20 words around typical Chilean food and drinks.
```

The answer displays some weakness that one can try to work out by refining the
prompt.

```
¡Claro! Aquí tienes una lista de 20 palabras relacionadas con la comida y las bebidas típicas chilenas:

1. Empanada; empanada
2. Completo; hot dog chileno
3. Pebre; salsa picante tradicional chilena
4. Chorrillana; plato de carne y papas fritas
5. Asado; barbecue
6. Caldillo de congrio; sopa de congrio
7. Mote con huesillo; bebida tradicional de mote y durazno deshidratado
8. Cazuela; guiso chileno
9. Curanto; plato típico de la Región de los Lagos
10. Sopaipilla; pan frito de masa de calabaza
11. Chicha; bebida alcohólica de maíz fermentado
12. Marraqueta; tipo de pan chileno
13. Porotos con rienda; plato de porotos con tallarines
14. Pastel de choclo; pastel de maíz
15. Pisco sour; cóctel chileno hecho con pisco
16. Pan amasado; pan casero chileno
17. Curanto en hoyo; curanto cocinado en un hoyo en la tierra
18. Chancho en piedra; salsa picante de tomate
19. Alfajor; dulce típico chileno
20. Chupe de mariscos; sopa de mariscos

Aquí tienes el archivo CSV para importarlo fácilmente en Anki:
\```
Empanada; empanada
Completo; hot dog chileno
Pebre; salsa picante tradicional chilena
Chorrillana; plato de carne y papas fritas
Asado; barbecue
Caldillo de congrio; sopa de congrio
Mote con huesillo; bebida tradicional de mote y durazno deshidratado
Cazuela; guiso chileno
Curanto; plato típico de la Región de los Lagos
Sopaipilla; pan frito de masa de calabaza
Chicha; bebida alcohólica de maíz fermentado
Marraqueta; tipo de pan chileno
Porotos con rienda; plato de porotos con tallarines
Pastel de choclo; pastel de maíz
Pisco sour; cóctel chileno hecho con pisco
Pan amasado; pan casero chileno
Curanto en hoyo; curanto cocinado en un hoyo en la tierra
Chancho en piedra; salsa picante de tomate
Alfajor; dulce típico chileno
Chupe de mariscos; sopa de mariscos
\```

Espero que esta lista te ayude a expandir tu vocabulario sobre la comida y bebidas chilenas. ¡Buena suerte!
```

Remember that it is possible to include initial conversations in the
configuration. You can see the respective section on details how to do this,
but here is a conversation entry that would provide the setup that we have
prepared:

```lua
["Spanish Teacher: Vocabulary"] = {
  {
    role = "Instruction",
    lines = {
         "Imagine you are a Spanish teacher guiding a student at level C1 in "
      .. "their vocabulary development. Initiate the conversation by asking the "
      .. "student to express their interest in a particular field or topic they "
      .. "would like to expand their vocabulary in. Once they provide the topic, "
      .. "make sure to create a vocabulary list that includes a CSV file for "
      .. "easy import into Anki, a flashcard application."
    },
  },
  {
    role = "Example",
    lines = {
      "auricular; ear phones",
      "ruborizarse; to blush",
      "un micro; a local bus",
      "ser corto de vista; to be short sighted",
      "puño; fist, handle",
    }
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

### `add_line_as_input_query_and_append`

In normal mode, add the current line as input for the current session, then
query the model for a response, and once this response is completed insert it
after the current line.

Bound by default to `<leader>aip`.

### `add_line_as_input_query_and_prepend`

Same as `add_line_as_input_query_and_append`, but insert the response before
the current lint.

Bound by default to `<leader>aiP`.

### `add_line_as_input_query_and_substitute`

Same as `add_line_as_input_query_and_append`, but delete the current line and
substitute the response once completely received.

Bound by default to `<leader>ais`.

## Local commands

Local commands are the ones awailable in the conversation and/or input buffer
of a session.

### `clear_interaction`

Delete the user input and the LLM responses of a session, but not the
instructions, the context, and the examples.

Bound by default to `<C-d>i`.

### `clear_conversation`

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

