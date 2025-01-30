local session = require("facilellm.session")


---@type FacileLLM.SessionId?
local active_completion_sessionid = nil
---@type function?(string[]): nil
local active_completion_callback = nil


---@param sessionid FacileLLM.SessionId
---@param callback function
local activate = function (sessionid, callback)
  active_completion_sessionid, active_completion_callback =  sessionid, callback
end

---@param sessionid FacileLLM.SessionId
---@param lines string[]
---@return nil
local set_completions = function (sessionid, lines)
  if active_completion_sessionid ~= sessionid then
    return
  end

  local callback
  callback, active_completion_sessionid, active_completion_callback =
    active_completion_callback, nil, nil
  ---@cast callback function

  local completion_tags = session.get_provider_config(sessionid).completion_tags
  if completion_tags == nil then
    callback()
  end
  ---@cast completion_tags FacileLLM.Config.CompletionTags

  local items = {}
  local match_string = completion_tags.completion_begin_tag .. "(.-)" .. completion_tags.completion_end_tag
  for c in string.gmatch(table.concat(lines, "\n"), match_string) do
    table.insert(items, {
      label = c,
      documentation = {
        kind = "markdown",
        value = "```" .. (vim.bo.ft or "") .. "\n" .. c .. "\n```",
      },
      kind = vim.lsp.protocol.CompletionItemKind.Text,
    })
  end

  callback({
    items = items,
    is_incomplete_forward = false,
    is_incomplete_backward = false,
  })
end


return {
  activate = activate,
  set_completions = set_completions,
}
