# Next Steps

- for nvim-cmp
  `---@field as_completion function?(FacileLLM.Message): nil`
- for git patches
  `---@field as_git_cherry_pick function?(FacileLLM.Message): string`

- prompt templates:
  - create current completion model; bind aic to that model
- use config conversations to extend template in front
- file context list
- clear conversation but not context or instruction extends to this
- return patch; apply to new git branch if neogit is present; cherry pick
- facilellm hot and cold presets; try them; associate with conversation?

- rethink example and context roles

- move class descriptions to top of files

- when several prompts of the same kind follow each other, fuse them

- conversation history option and then restore
  - limit on size
  - via tree?

- config: don't open new windows except when asked explicitly

- pruning in visual: prune messages touched by highlight

- enable loading a session via visual mode

- shortcut for changing model in session

- consider llama.vim

## interactions

- standard input-output:
  - show window initially
  - on focus open window
  - usual register with possible preprocessing
- completion via register
  - don't show window
  - on focus only swap interaction provider
  - registers with multiple matching
  - fold input
- completion via nvim-cmp
  - don't show window
  - on focus only swap interaction provider
  - completions with multiple matching
  - fold input
- git branch and cherry-pick on project

## user stories

- vocabulary extraction
  - first scan, then mark, then extract via AI
- proofread EN document
  - verify the prompt for efficiency
- Latex proofread
  - sometimes replaces shortcuts, give instrutions/example against this
- comment and explain code
- generate ideas, brief
- generate ideas, extensive
- find error in code
- generate code
