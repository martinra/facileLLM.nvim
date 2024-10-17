# Next Steps

- better config of general models

- facilellm hot and cold presets; try them; associate with conversation?
- prompt templates
- function to fill several registers

- user story with repeated pruning/purging to keep promt empty
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

- config: don't open new windows except when asked explicitly

- pruning in visual: prune messages touched by highlight

- enable loading a session via visual mode

- shortcut for changing model in session

# LLM Integration

- llamacpp interface

  `./main -t 10 -m ../../ai_models/llama-2-13b-guanaco-qlora.Q6_K.gguf -p "A poem about the beauty of the sea in fall:\n" -e 2> /dev/null`
  generates
  ```
   A poem about the beauty of the sea in fall:
  "Sea Poem" by Mary Oliver 
  ```
  This starts with a blank then repeats the prompt. This should be stripped
  while receiving.

- `vast.ai`
  does not seem to provide api directly
  example of interfacing via python
  `https://colab.research.google.com/github/experienced-dev/notebooks/blob/master/2023_07_08_mpt-30b-chat_langchain_vastai.ipynb#scrollTo=iR-QaAl4UanU`

- PaLM integration
  - In beta at the moment
  - `https://developers.generativeai.google/guide/palm_api_overview#curl_1`
  - `https://developers.generativeai.google/api/python/google/generativeai/chat`
  - `https://developers.generativeai.google/api/python/google/generativeai/types/ChatResponse`
  - `https://makersuite.google.com/app/home`
    At the moment limited to 50/mo requests in the free tier. Possibly need
    more to test implementation.

- Mistral API integration
  In beta at the moment

# Features discarded in first implementation

- annotate generating model
- autoprune, configurable per model
