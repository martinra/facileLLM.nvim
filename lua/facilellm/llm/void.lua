---@param conv Conversation
---@param add_message function
---@param on_complete function
---@param _ table
---@return nil
local response_to = function (conv, add_message, on_complete, _)
  if #conv == 0 then
    add_message("Void", "The void tried to hear your message, but there is nothing to be heard.")
    on_complete()
    return
  end

  local lines = conv[#conv].lines

  add_message("Void", "The void heard your message.\n")
  vim.defer_fn(
    function()
      add_message("Void", "The echo of your message comes closer.\n")
      vim.defer_fn(
        function()
          add_message("Void", "Soon it will arrive.\n")
          vim.defer_fn(
            function()
              add_message("Void", lines)
              on_complete()
            end,
            2000)
        end,
        1000)
    end,
    500)
end

---@return table
local default_opts = function ()
  return {
    name = "The Void Mock LLM",
    params = {},
  }
end

---@param opts table
---@return LLM
local create = function (opts)
  opts = opts or {}
  opts = vim.tbl_extend("force", default_opts(), opts)

  ---@type LLM
  local llm = {
    name = opts.name,
    params = opts.params,
    response_to = response_to,
  }
  return llm
end


return {
  create = create,
}
