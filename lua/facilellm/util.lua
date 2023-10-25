---@param relative string
---@param direction string
---@return string
local win_vsplit_modifier = function (relative, direction)
  if relative == "editor" then
    if direction == "right" then
      return "botright"
    elseif direction == "left" then
      return "topleft"
    else
      error("unknown split direction " .. direction)
    end
  elseif relative == "win" then
    if direction == "right" then
      return "rightbelow"
    elseif direction == "left" then
      return "leftabove"
    else
      error("unknown split direction " .. direction)
    end
  else
    error("unknown value for relative: " .. relative)
  end
end


return {
  win_vsplit_modifier  = win_vsplit_modifier,
}
