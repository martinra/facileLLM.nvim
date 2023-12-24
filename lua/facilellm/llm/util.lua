---@param params table
---@return string
local preview_params = function (params)
  local preview = ""
  
  if params.temperature then
    preview = preview .. "Temperature: " .. params.temperature .. "\n"
  end

  if params.top_p then
    preview = preview .. "top_p: " .. params.top_p .. "\n"
  end
  if params.top_k then
    preview = preview .. "top_k: " .. params.top_k .. "\n"
  end

  if params.presence_penalty then
    preview = preview .. "Presence penalty: " .. params.presence_penalty .. "\n"
  end
  if params.frequency_penalty then
    preview = preview .. "Frequency penalty: " .. params.frequency_penalty .. "\n"
  end

  if params.max_new_tokens then
    preview = preview .. "Maximal number of new tokens: " .. params.max_new_tokens .. "\n"
  end

  return preview
end


return {
  preview_params = preview_params,
}
