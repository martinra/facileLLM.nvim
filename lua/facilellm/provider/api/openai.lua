-- OpenAI API, not restricted to their product.

local job = require("plenary.job")
local provider_util = require("facilellm.provider.util")
local message = require("facilellm.session.message")
local util = require("facilellm.util")


local log = require("structlog")
log.configure({
  facilellm_openai = {
    pipelines = {
      {
        level = log.level.INFO,
        processors = {
          log.processors.Timestamper("%H:%M:%S"),
        },
        formatter = log.formatters.Format(
          "%s [%s] %s: %-30s",
          { "timestamp", "level", "logger_name", "msg" }
        ),
        sink = log.sinks.File("./facilellm_openai.log"),
      },
    },
  },
})


---@alias FacileLLM.API.OpenAI.MsgRole ("system"| "assistant"| "user")

---@class FacileLLM.API.OpenAI.Message
---@field role FacileLLM.API.OpenAI.MsgRole
---@field content string

---@alias OpenAIConversation FacileLLM.API.OpenAI.Message[]

---@class FacileLLM.API.OpenAI.StdOutRecord
---@field lines string[]
---@field json_records table[] Start and end position of a valid json recond in lines


---@param role FacileLLM.MsgRole
---@return FacileLLM.API.OpenAI.MsgRole
local convert_role_to_openai = function (role)
  if role == "Instruction" then
    return "system"
  elseif role == "Context" then
    return "system"
  elseif role == "Example" then
    return "system"
  elseif role == "LLM" then
    return "assistant"
  elseif role == "Input" then
    return "user"
  else
    error("unknown role " .. role)
  end
end

---@param msg FacileLLM.Message
---@return FacileLLM.API.OpenAI.Message
local convert_msg_to_openai = function (msg)
  local msg_openai = {
    role = convert_role_to_openai(msg.role),
    content = table.concat(msg.lines, "\n"),
  }
  if msg.role == "Context" then
    msg_openai.content =
      "The conversation will be based on the following context:\n" ..
      '"""\n' ..
      msg_openai.content .. "\n" ..
      '"""'
    elseif msg.role == "Example" then
    msg_openai.content =
      "This is an example of how you should respond:\n" ..
      '"""\n' ..
      msg_openai.content .. "\n" ..
      '"""'
  end
  return msg_openai
end

---@param role FacileLLM.API.OpenAI.MsgRole
---@return FacileLLM.MsgRole
local convert_role_from_openai = function (role)
  if role == "assistant" then
    return "LLM"
  end
  vim.schedule(vim.notify,
    "Warning in OpenAI API:\n" .. "Unexpected role " .. role .. ".\n",
    vim.log.levels.WARN
  )

  if role == "user" then
    return "Input"
  elseif role == "system" then
    return "Instruction"
  else
    error("unknown role " .. role)
  end
end

---@param stdout_record FacileLLM.API.OpenAI.StdOutRecord
---@param data string
local append_to_stdout_record = function (stdout_record, data)
  if string.len(data) == 0 then
    return

  -- NOTE: We here assume that stdout does not break along the data prefixes.
  elseif string.sub(data, 1,6) ~= "data: " then
    vim.schedule(vim.notify,
        "Error in OpenAI API:\n" .. "Received string not prefixed by data.\n" .. data,
        vim.log.levels.ERROR
      )

  else
    if data ~= "data: [DONE]" then
      table.insert(stdout_record.lines, string.sub(data,7))
    end
  end
end

---@param stdout_record FacileLLM.API.OpenAI.StdOutRecord
---@return nil | table
local parse_json_record = function (stdout_record)
  local concat_lines = ""
  for ix,line in pairs(stdout_record.lines) do
    concat_lines = concat_lines .. line
    local flag, json = pcall(vim.json.decode, concat_lines)
    if flag then
      for _ = 1,ix do
        table.remove(stdout_record.lines,1)
      end
      return json
    end
  end
end

---@param stdout_record FacileLLM.API.OpenAI.StdOutRecord
---@return table[] records A list of the newly decoded JSON records.
local parse_new_json_records = function (stdout_record)
  local new_records = {}
  while true do
    local json = parse_json_record(stdout_record)
    if json then
      -- NOTE: We assume that only one JSON record appears per line. Otherwise,
      -- here we need to check for the possibility that json is an array.
      table.insert(new_records, json)
      table.insert(stdout_record.json_records, json)
    else
      break
    end
  end
  return new_records
end

---@param stdout_record FacileLLM.API.OpenAI.StdOutRecord
---@return table? record The last valid JSON entries in the record.
local get_last_json_record = function (stdout_record)
  parse_new_json_records(stdout_record)
  return stdout_record.json_records[#stdout_record.json_records]
end

---@param conversation FacileLLM.Conversation
---@param add_message function
---@param on_complete function
---@param opts table
---@return function?
local response_to = function (conversation, add_message, on_complete, opts)
  if not opts.api_key then
    opts.api_key = opts.get_api_key()
    if opts.api_key == nil then
      vim.notify("Error on acquiring API key for " .. opts.name, vim.log.levels.ERROR)
      return
    end
  end

  ---@type FacileLLM.API.OpenAI.StdOutRecord
  local stdout_record = {
    lines = {},
    json_records = {},
  }

  local cancelled = { false }

  local receiving_llm = false
  local on_stdout = function (_, data)
    if cancelled[1] then
      return
    end

    append_to_stdout_record(stdout_record, data)
    local json_records = parse_new_json_records(stdout_record)
    for _,json in pairs(json_records) do
      local ok, delta = pcall(function ()
        return json.choices[1].delta
      end)
      if ok and delta.content then
        local role = delta.role and convert_role_from_openai(delta.role)
        if role == "LLM" or role == nil and receiving_llm then
          receiving_llm = true
          add_message(delta.content)
        else
          receiving_llm = false
        end
      end
    end
  end

  local data = util.deep_copy_values(opts.params)
  data.stream = true
  data.model = opts.openai_model
  -- TODO: this should be refactored as conversation_to_messages
  data.messages = {}
  for _,msg in ipairs(conversation) do
    if not message.isempty(msg) and not message.ispruned(msg) then
      table.insert(data.messages, convert_msg_to_openai(msg))
    end
  end

  ---@diagnostic disable-next-line missing-fields
  local curl_job = job:new({
      command = "curl",
      args = {
        "--silent", "--show-error", "--no-buffer",
        opts.url,
        "-H", "Content-Type: application/json",
        "-H", "Authorization: Bearer " .. opts.api_key,
        "-d", vim.json.encode(data),
      },
      on_stdout = on_stdout
    })

  curl_job:after(on_complete)
  curl_job:after_failure(function ()
      local stderr_text = curl_job:stderr_result()
      local stdout_json = get_last_json_record(stdout_record)
      local errmsg
      if stdout_json and stdout_json.error then
        errmsg = stderr_text .. "\n" .. stdout_json.error.message
      else
        errmsg = stderr_text
      end
      vim.schedule(function ()
        vim.notify("Error on OpenAI API:\n" .. errmsg, vim.log.levels.ERROR)
      end)
    end)

  curl_job:start()

  return function ()
    curl_job:_stop()
    cancelled[1] = true
  end
end

---@return table
local default_opts = function ()
  return {
    name = "OpenAI GPT",
    url = "https://api.openai.com/v1/chat/completions",
    get_api_key = function ()
      return vim.ui.input("API key for api.openai.com: ")
    end,
    openai_model = "gpt-3.5-turbo",
    params = {},
  }
end

---@param opts table
---@return FacileLLM.Provider
local create = function (opts)
  opts = opts or {}
  opts = vim.tbl_deep_extend("force", default_opts(), opts)

  -- We expose name and model parameters to the caller for later
  -- modification.

  ---@type FacileLLM.Provider
  local provider = {
    name = opts.name,
    params = opts.params,
    response_to = function (conversation, add_message, on_complete)
      return response_to(conversation, add_message, on_complete, opts)
    end,
  }
  return provider
end

---@param opts table
---@return string
local preview = function (opts)
  opts = opts or {}
  opts = vim.tbl_deep_extend("force", default_opts(), opts)

  local preview = ""

  if opts.url == "https://api.openai.com/v1/chat/completions" then
    preview = preview .. "OpenAI ChatGPT "
    if opts.openai_model == "gpt-3.5-turbo" then
      preview = preview .. "3.5-Turbo\n"
    else
      preview = preview .. "\n"
    end
  else
    preview = preview .. "OpenAI API at " .. opts.url .. "\n"
  end

  preview = preview .. provider_util.preview_params(opts.params)

  return preview
end


return {
  create = create,
  preview = preview,
}
