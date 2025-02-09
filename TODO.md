# Next Steps

- in context template add file path, so that completion can work more properly when file context is given.

- facilellm hot and cold presets; try them; associate with conversation?

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
