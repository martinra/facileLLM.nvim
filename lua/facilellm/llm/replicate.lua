-- Replicate
-- Description at https://replicate.com/docs/reference/http

local job = require("plenary.job")
local llm_util = require("facilellm.llm.util")


local schedule_prediction = {}

---@param url string
---@param api_key string
---@param cancelled {[1]: boolean}
---@param add_message function
---@param on_complete function
---@param prompt_conversion FacileLLM.LLM.PromptConversion
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
      vim.schedule(function ()
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

    local output = prompt_conversion.output_to_string(json.output)
    nmb_received_chars = nmb_received_chars or 0
    add_message(string.sub(output, nmb_received_chars+1))

    if json.status == "succeeded" then
      on_complete()
    else
      vim.schedule(function ()
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

  local data = {
    version = opts.replicate_version,
    input = opts.prompt_conversion.conversation_to_input(conversation, opts.params),
  }

  ---@diagnostic disable-next-line missing-fields
  local curl_job = job:new({
    command = "curl",
    args = {
      "--silent", "--show-error", "--no-buffer",
      opts.url,
      "-H", "Content-Type: application/json",
      "-H", "Authorization: Token " .. opts.api_key,
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

    if not json.urls or not json.urls.get or not json.urls.cancel then
      vim.schedule(function ()
        vim.notify("Replicate API response does not provide url:\n" .. vim.inspect(json),
                   vim.log.levels.ERROR)
      end)
      on_complete()
      return
    end
    prediction_url_cancel = json.urls.cancel

    if cancelled[1] then
      schedule_prediction.cancel(prediction_url_cancel, opts.api_key)
    else
      add_message("")
      vim.schedule(function ()
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
    cancelled[1] = true
  end
end

---@return table
local default_opts = function ()
  return {
    name = "Replicate Unspecified Model",
    url = "https://api.replicate.com/v1/predictions",
    get_api_key = function ()
      return vim.ui.input("API key for api.replicate.com: ")
    end,
    params = {},

    ---@type string?
    replicate_model_name = nil,
    ---@type string?
    replicate_version = nil,
    ---@type FacileLLM.LLM.PromptConversion?
    prompt_conversion = nil,
  }
end

---@param opts table
---@return FacileLLM.LLM
local create = function (opts)
  opts = opts or {}
  opts = vim.tbl_deep_extend("force", default_opts(), opts)

  if not opts.prompt_conversion then
    error("Replicate API rerquires model conversion")
  end

  -- We expose name and model parameters to the caller for later
  -- modification.
  ---@type FacileLLM.LLM
  local llm = {
    name = opts.name,
    params = opts.params,
    response_to = function (conversation, add_message, on_complete)
      return response_to(conversation, add_message, on_complete, opts)
    end,
  }
  return llm
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

  preview = preview .. llm_util.preview_params(opts.params)

  return preview
end


return {
  create = create,
  preview = preview,
}
