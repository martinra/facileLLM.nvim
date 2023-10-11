-- OpenAI API, not restrict to their product.

local job = require("plenary.job")


---@class OpenAIMessage
---@field role string "system", "assistant", or "user"
---@field content string

---@alias OpenAIConversation OpenAIMessage[]

---@class OpenAIStdOutRecord
---@field lines string[]
---@field json_records table[] Start and end position of a valid json recond in lines


---@param role string
---@return string
local convert_role_to_openai = function (role)
  if role == "Context" then
    return "system"
  elseif role == "LLM" then
    return "assistant"
  elseif role == "Input" then
    return "user"
  else
    return role
  end
end

---@param role string
---@return string
local convert_role_from_openai = function (role)
  if role == "system" then
    return "Context"
  elseif role == "assistant" then
    return "LLM"
  elseif role == "user" then
    return "Input"
  else
    return role
  end
end

---@param stdout_record OpenAIStdOutRecord
---@param data string
local append_to_stdout_record = function (stdout_record, data)
  if string.len(data) == 0 then
    return

  -- NOTE: We here assume that stdout does not break along the data prefixes.
  elseif string.sub(data, 1,6) ~= "data: " then
    vim.schedule(vim.notify,
        "Error oi OpenAI API:\n" .. "Received string not prefixed by data.\n" .. data,
        vim.log.levels.ERROR
      )

  else
    if data ~= "data: [DONE]" then
      table.insert(stdout_record.lines, string.sub(data,7))
    end
  end
end

---@param stdout_record OpenAIStdOutRecord
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

---@param stdout_record OpenAIStdOutRecord
---@return table[] A list of the newly decoded JSON records.
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

---@param stdout_record OpenAIStdOutRecord
---@return nil | table The last valid JSON entries in the record.
local get_last_json_record = function (stdout_record)
  parse_new_json_records(stdout_record)
  return stdout_record.json_records[#stdout_record.json_records]
end

---@param conversation Conversation
---@param add_message function
---@param on_complete function
---@param opts table
---@return nil
local response_to = function (conversation, add_message, on_complete, opts)
  ---@type OpenAIStdOutRecord
  local stdout_record = {
    lines = {},
    json_records = {},
  }

  local on_stdout = function (_, data)
    append_to_stdout_record(stdout_record, data)
    local json_records = parse_new_json_records(stdout_record)
    for _,json in pairs(json_records) do
      local ok, delta = pcall(function ()
        return json.choices[1].delta
      end)
      if ok and delta.content then
        local role = delta.role and convert_role_from_openai(delta.role)
        add_message(role, delta.content)
      end
    end
  end

  local data = vim.tbl_deep_extend("force", {}, opts.params)
  data.stream = true
  data.model = opts.openai_model
  data.messages = {}
  for _,msg in ipairs(conversation) do
    table.insert(data.messages,
      {
        role = convert_role_to_openai(msg.role),
        content = table.concat(msg.lines, "\n"),
      })
  end

  if not opts.api_key then
    opts.api_key = opts.get_api_key()
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
      print("failure")
      local stderr_text = curl_job:stderr_result()
      local stdout_json = get_last_json_record(stdout_record)
      local errmsg
      if stdout_json and stdout_json.error then
        errmsg = stderr_text .. "\n" .. stdout_json.error.message
      else
        errmsg = stderr_text
      end
      vim.notify("Error on OpenAI API:\n" .. errmsg, vim.log.levels.ERROR)
    end)

  curl_job:start()
end

---@return table
local default_opts = function ()
  return {
    name = "OpenAI GPT 3.5-Turbo",
    url = "https://api.openai.com/v1/chat/completions",
    get_api_key = function ()
      error("Please, provide a key acquisition function in model options")
    end,
    openai_model = "gpt-3.5-turbo",
    params = {},
  }
end

---@param opts table
---@return LLM
local create = function (opts)
  opts = opts or {}
  opts = vim.tbl_extend("force", default_opts(), opts)

  -- TODO: Check that this works as intended.
  -- We expose name and model parameters to the caller for later
  -- modification.

  ---@type LLM
  local llm = {
    name = opts.name,
    params = opts.params,
    response_to = function (conversation, add_message, on_complete)
      response_to(conversation, add_message, on_complete, opts)
    end,
  }
  return llm
end


return {
  create = create,
}
