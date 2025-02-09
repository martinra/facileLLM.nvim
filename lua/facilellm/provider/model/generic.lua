local util = require("facilellm.util")


---@param lines string[]
---@return string[]
local expand_file_context = function (lines)
  local filenames = {}
  for _,line in ipairs(lines) do
    if string.sub(line, 1, 3) ~= "fd " then
      table.insert(filenames, line)
      goto continue_line
    end

    local cmd = "fd"
    local chunks = vim.split(line, "%s+")
    -- Skip the initial "fd" command
    for i = 2, #chunks do
      local chunk = chunks[i]
      if string.sub(chunk, 1, 1) ~= "-" or
        chunk == "-H" or chunk == "--hidden" or
        chunk == "-I" or chunk == "--no-ignore" or
        chunk == "-u" or chunk == "--unrestricted" or
        chunk == "--no-ignore-vcs" or
        chunk == "-s" or chunk == "--case-sensitive" or
        chunk == "-i" or chunk == "--ignore-case" or
        chunk == "--and" or
        chunk == "--max-results" or
        chunk == "-d" or chunk == "--max-depth" or
        chunk == "--min-depth" or
        chunk == "--exact-depth" or
        chunk == "-e" or chunk == "--extension" or
        chunk == "-E" or chunk == "--exclude" or
        chunk == "--ignore-file" or
        chunk == "-S" or chunk == "--size" or
        chunk == "--changed-within" or
        chunk == "--changed-before" or
        chunk == "-o" or chunk == "--owner" then
        cmd = cmd .. " " .. chunk
      else
        vim.api.nvim_err_writeln("Disallowed argument \"" .. chunk .. "\" in file context call to fd.")
        goto continue_chunk
      end

      ::continue_chunk::
    end

    local pipe = io.popen(cmd)
    if pipe ~= nil then
      for _, filename in ipairs(vim.split(pipe:read("*a"), "\n")) do
        table.insert(filenames, filename)
      end
      pipe:close()
    end

    ::continue_line::
  end

  return filenames
end

---@param msg FacileLLM.Message
---@param opts table?
---@return string
local convert_msg_minimal_roles = function (msg, opts)
  if msg.role == "Context" then
    return
    "Important context for this conversation:\n" ..
    '"""\n' ..
    table.concat(msg.lines, "\n") .. "\n" ..
    '"""\n' ..
    "Use this context to inform your responses. Refer to specific details when relevant."
  elseif msg.role == "FileContext" then
    ---@cast msg FacileLLM.FileContextMessage
    local content = ""
    for _,filename in ipairs(expand_file_context(msg.lines)) do
      local filetype, file_content = util.read_with_filetype(filename)
      if filetype ~= nil then
        content = content .. msg.filename_tag .. filename .. "\n"
        content = content .. msg.filetype_tag .. filetype .. "\n"
        content = content .. file_content .. "\n"
      end
    end

    return
    "Reference the following file contents in your responses:\n" ..
    '"""\n' ..
    content ..
    '"""\n' ..
    "When discussing code, refer to specific files and line numbers where appropriate."
  elseif msg.role == "Example" then
    return
    "Format your responses following this example:\n" ..
    '"""\n' ..
    table.concat(msg.lines, "\n") .. "\n" ..
    '"""\n' ..
    "Match the style, format and level of detail shown in this example."
  else
    return table.concat(msg.lines, "\n")
  end
end


return {
  convert_msg_minimal_roles = convert_msg_minimal_roles,
}
