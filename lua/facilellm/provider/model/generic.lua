local util = require("facilellm.util")


---@param msg FacileLLM.Message
---@param opts table?
---@return string
local convert_msg_minimal_roles = function (msg, opts)
  if msg.role == "Context" then
    return
    "The conversation will be based on the following context:\n" ..
    '"""\n' ..
    table.concat(msg.lines, "\n") .. "\n" ..
    '"""'
  elseif msg.role == "FileContext" then
    ---@cast msg FacileLLM.FileContextMessage
    local content = ""
    for _,line in ipairs(msg.lines) do
      local filetype, file_content = util.read_with_filetype(line)
      if filetype ~= nil then
        content = content .. msg.filetype_tag .. filetype .. "\n"
        content = content .. file_content .. "\n"
      end
    end

    return
    "The conversation will be based on the content of the following files:\n" ..
    '"""\n' ..
    content ..
    '"""'
  elseif msg.role == "Example" then
    return
    "This is an example of how you should respond:\n" ..
    '"""\n' ..
    table.concat(msg.lines, "\n") .. "\n" ..
    '"""'
  else
    return table.concat(msg.lines, "\n")
  end
end


return {
  convert_msg_minimal_roles = convert_msg_minimal_roles,
}
