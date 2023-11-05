---@alias RelTime {[1]: number, [2]: number}
---@alias FacileLLM.Timestamp {[1]: string, [2]: RelTime}

---@type FacileLLM.Timestamp[]
local timestamps = {}

---@param desc string
---@return nil
local timestamp = function (desc)
  table.insert(timestamps, {desc, vim.fn.reltime()})
end

---@return nil
local clear_timestamps = function ()
  timestamps = {}
end

---@return nil
local print_timestamps = function ()
  local prev_t = nil
  for _,desc_t in ipairs(timestamps) do
    local desc,t = unpack(desc_t)
    if prev_t then
      local diff_t = vim.fn.reltime(prev_t, t)
      print(desc .. ": " .. vim.fn.reltimestr(diff_t))
    end
    prev_t = t
  end
end


return {
  timestamp            = timestamp,
  clear_timestamps     = clear_timestamps,
  print_timestamps     = print_timestamps,
}
