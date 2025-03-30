# Next Steps

- when in visual mode highlight several messages, allow to purge all of them
- pruning in visual: prune messages touched by highlight

- in payload field add `"include_reasoning": true`; this might mean to specialize on OpenRouter interface

- config: don't open new windows except when asked explicitly

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
