-- Replicate
-- Description at https://replicate.com/docs/reference/http

local job = require("plenary.job")
local provider_util = require("facilellm.provider.util")

local log = require("structlog")
log.configure({
  facilellm_replicate = {
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
        sink = log.sinks.File("./facilellm_replicate.log"),
      },
    },
  },
})


local schedule_prediction = {}

---@param url string
---@param cancelled {[1]: boolean}
---@param stream_curl_job {}
---@param add_message function
---@param on_complete function
---@return nil
schedule_prediction.stream = function (url, cancelled, stream_curl_job, add_message, on_complete)
  local first_message_added = false
  local last_event_was_output = false
  local last_event_was_error = false
  local previous_was_data = false
  local on_stdout = function (_, str)
    if cancelled[1] then
      return
    end

    local lines = vim.split(str, "\n")
    for _,line in ipairs(lines) do
      if string.sub(line, 1,7) == "event: " then
        if string.sub(line, 8) == "output" then
          last_event_was_output = true
          last_event_was_error = false
        else
          last_event_was_output = false
          if string.sub(line, 8) == "error" then
            last_event_was_error = true
          elseif string.sub(line, 8) == "done" then
            last_event_was_error = false
            stream_curl_job[1]:_shutdown()
          end
        end
        previous_was_data = false
      elseif string.sub(line, 1,6) == "data: " then
        if last_event_was_output then
          if previous_was_data and first_message_added then
            -- We only add newlines after text was received to avoid a
            -- situtation where the LLM response starts with blank lines.
            add_message("\n")
          end
          local msg = string.sub(line, 7)
          if msg ~= "" then
            add_message(msg)
            first_message_added = true
          end
        elseif last_event_was_error then
          vim.schedule(function ()
            vim.notify("Error on Replicate API:\n" .. string.sub(line, 7), vim.log.levels.ERROR)
          end)
        end
        previous_was_data = true
      end
    end
  end

  ---@diagnostic disable-next-line missing-fields
  local curl_job = job:new({
      command = "curl",
      args = {
        "--silent", "--show-error", "--no-buffer",
        url,
        "-H", "Accept: text/event-stream",
        "-H", "Cache-Control: no-store"
      },
      on_stdout = on_stdout
    })
  stream_curl_job[1] = curl_job

  curl_job:after(function ()
    on_complete()
  end)
  curl_job:after_failure(function (_, code, _)
      if code == nil then
        return
      end
      local stderr_text = curl_job:stderr_result()
      vim.schedule(function ()
        vim.notify("Error on Replicate API:\n" .. vim.inspect(stderr_text), vim.log.levels.ERROR)
      end)
    end)

  curl_job:start()

  return function ()
    curl_job:_shutdown()
    cancelled[1] = true
  end
end

---@param url string
---@param api_key string
---@param cancelled {[1]: boolean}
---@param add_message function
---@param on_complete function
---@param prompt_conversion FacileLLM.Provider.PromptConversion
---@param nmb_received_chars integer?
---@return nil
schedule_prediction.get = function (url, api_key, cancelled, add_message, on_complete, prompt_conversion, nmb_received_chars)
  ---@diagnostic disable-next-line missing-fields
  local curl_job = job:new({
    command = "curl",
    args = {
      "--silent", "--show-error", "--no-buffer",
      url,
      "-H", "Authorization: Token " .. api_key,
    },
    enabled_recording = true,
  })

  curl_job:after(function ()
    if cancelled[1] then
      return
    end

    local stdout_texts = curl_job:result()
    local flag, json = pcall(vim.json.decode, table.concat(stdout_texts, ""))
    if not flag then
      vim.schedule(function ()
        vim.notify("Could not parse Replicate API response:\n" .. vim.inspect(stdout_texts),
                   vim.log.levels.ERROR)
      end)
      on_complete()
      return
    end
    if json.error and json.error ~= vim.NIL then
      vim.schedule(function ()
        vim.notify("Replicate API response signals error:\n" .. vim.inspect(json.error),
                   vim.log.levels.ERROR)
      end)
      on_complete()
      return
    end

    if not json.status then
      vim.schedule(function ()
        vim.notify("Replicate API response does not incldue status:\n" .. vim.inspect(json),
                   vim.log.levels.ERROR)
      end)
      on_complete()
      return
    end

    if json.status == "failed" then
      vim.schedule(function ()
        vim.notify("Replicate API response indicates failure:\n" .. vim.inspect(json),
                   vim.log.levels.ERROR)
      end)
      on_complete()
      return
   elseif json.status == "cancelled" then
      if cancelled[1] then
        return
      end
      vim.schedule(function ()
        vim.notify("Replicate API response indicates unexpected cancellation:\n" .. vim.inspect(json),
                  vim.log.levels.ERROR)
      end)
      on_complete()
      return

    elseif json.status == "starting" then
      vim.defer_fn(function ()
        schedule_prediction.get(url, api_key, cancelled,
          add_message, on_complete, prompt_conversion)
      end, 300)
      return
    elseif json.status ~= "processing" and json.status ~= "succeeded" then
      vim.schedule(function ()
        vim.notify("Replicate API response indicates unexpected status:\n" .. vim.inspect(json),
                   vim.log.levels.ERROR)
      end)
      on_complete()
      return
    end

    if not json.output then
      vim.schedule(function ()
        vim.notify("Replicate API response does not contain output:\n" .. vim.inspect(json),
                   vim.log.levels.ERROR)
     end)
      on_complete()
      return
    end

    local lines = vim.split(table.concat(json.output, ""), "\n")
    for _,line in ipairs(lines) do
      if string.match(line, "^%s*$") then
        table.remove(lines, 1)
      else
        lines[1] = string.gsub(line, "^%s*(.-)$", "%1")
        break
      end
    end
    local output = table.concat(lines, "\n")

    nmb_received_chars = nmb_received_chars or 0
    add_message(string.sub(output, nmb_received_chars+1))

    if json.status == "succeeded" then
      on_complete()
    else
      vim.defer_fn(function ()
        schedule_prediction.get(url, api_key, cancelled,
          add_message, on_complete, prompt_conversion, string.len(output))
      end, 200)
    end
  end)

  curl_job:after_failure(function ()
    local stderr_text = curl_job:stderr_result()
    vim.schedule(function ()
      vim.notify("Error on Replicate API:\n" .. stderr_text, vim.log.levels.ERROR)
    end)
    on_complete()
  end)

  curl_job:start()
end

---@param url string?
---@param api_key string
---@return nil
schedule_prediction.cancel = function (url, api_key)
  if not url then
    return
  end
  ---@diagnostic disable-next-line missing-fields
  job:new({
    command = "curl",
    args = {
      "--silent", "--show-error", "--no-buffer",
      url,
      "-H", "Authorization: Token " .. api_key,
    },
    enabled_recording = true,
  }):start()
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

  local prediction_url_cancel
  local cancelled = { false }
  local stream_curl_job = {}

  local data = {
    version = opts.replicate_version,
    input = opts.prompt_conversion.convert_conv_to_prompt(conversation, opts.params),
    stream = opts.stream,
  }

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
    enabled_recording = true,
  })

  curl_job:after(function ()
    local stdout_texts = curl_job:result()
    local flag, json = pcall(vim.json.decode, table.concat(stdout_texts, ""))
    if not flag then
      vim.schedule(function ()
        vim.notify("Could not parse Replicate API response:\n" .. vim.inspect(stdout_texts),
                   vim.log.levels.ERROR)
      end)
      on_complete()
      return
    end
    if json.error and json.error ~= vim.NIL then
      vim.schedule(function ()
        vim.notify("Replicate API response signals error:\n" .. vim.inspect(json.error),
                   vim.log.levels.ERROR)
      end)
      on_complete()
      return
    end

    if not json.urls or not json.urls.cancel or
       not (opts.stream and json.urls.stream or not opts.stream and json.urls.get) then
      vim.schedule(function ()
        vim.notify("Replicate API response does not provide required urls:\n" .. vim.inspect(json),
                   vim.log.levels.ERROR)
      end)
      on_complete()
      return
    end
    prediction_url_cancel = json.urls.cancel

    if cancelled[1] then
      schedule_prediction.cancel(prediction_url_cancel, opts.api_key)
    elseif opts.stream then
      add_message("")
      vim.defer_fn(function ()
        schedule_prediction.stream(json.urls.stream, cancelled, stream_curl_job,
          add_message, on_complete)
      end, 30)
    else
      add_message("")
      vim.defer_fn(function ()
        schedule_prediction.get(json.urls.get, opts.api_key, cancelled,
          add_message, on_complete, opts.prompt_conversion)
      end, 30)
    end
  end)

  curl_job:after_failure(function ()
    local stderr_text = curl_job:stderr_result()
    vim.schedule(function ()
      vim.notify("Error on Replicate API:\n" .. stderr_text, vim.log.levels.ERROR)
    end)
    on_complete()
  end)

  curl_job:start()

  return function ()
    schedule_prediction.cancel(prediction_url_cancel, opts.api_key)
    if opts.stream and stream_curl_job[1] then
      stream_curl_job[1]:_shutdown()
    end
    cancelled[1] = true
  end
end

---@return table
local default_opts = function ()
  return {
    name = "Replicate Unspecified Model",
    url = "https://api.replicate.com/v1/predictions",
    stream = true,
    get_api_key = function ()
      return vim.ui.input(
          { prompt = "API key for api.replicate.com: " },
          function () end
      )
    end,
    params = {},

    ---@type string?
    replicate_version = nil,
    ---@type string?
    replicate_model_name = nil,
    ---@type FacileLLM.Provider.PromptConversion?
    prompt_conversion = nil,
  }
end

---@param opts table
---@return FacileLLM.Provider
local create = function (opts)
  opts = opts or {}
  opts = vim.tbl_deep_extend("force", default_opts(), opts)

  if not opts.prompt_conversion then
    error("Replicate API requires model conversion")
  end

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

  if opts.replicate_model_name then
    preview = preview .. opts.replicate_model_name .. "\n"
  else
    preview = preview .. "Unknown\n"
  end
  if opts.replicate_version then
    preview = preview .. "Version: " .. opts.replicate_version .. "\n"
  end
  if opts.url == "https://api.replicate.com/v1/predictions"
    or string.sub(opts.url,1,36) == "https://api.replicate.com/v1/models/" then
    preview = preview .. "via Replicate\n"
  else
    preview = preview .. "via Replicate API at " .. opts.url .. "\n"
  end

  preview = preview .. provider_util.preview_params(opts.params)

  return preview
end


return {
  create = create,
  preview = preview,
}
