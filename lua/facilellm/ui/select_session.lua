local ui_common = require("facilellm.ui.common")

local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")
local sorters = require("telescope.sorters")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")


---@type FacileLLM.SessionId?
local recent_sessionid = nil


---@param sessionid FacileLLM.SessionId
---@return nil
local delete = function (sessionid)
  if recent_sessionid == sessionid then
    recent_sessionid = nil
  end
end

---@param sessionid FacileLLM.SessionId
---@return nil
local touch = function (sessionid)
  recent_sessionid = sessionid
end

---@param winid WinId
---@return nil
local touch_window = function (winid)
  local sessionid = ui_common.win_get_session(winid)
  if sessionid then
    touch(sessionid)
  end
end

-- By most recent we mean the session that most recently was interacted with
-- as indicated by the touch command.
---@return FacileLLM.SessionId?
local get_most_recent = function ()
  return recent_sessionid
end

---@param session_names table<FacileLLM.SessionId, string>
---@param callback function(FacileLLM.SessionId): nil
---@param title string?
---@return nil
local select_session = function (session_names, callback, title)
  local sessionids = {}
  for id,_ in pairs(session_names) do
    table.insert(sessionids,id)
  end

  pickers.new({}, {
    prompt_title = title or "Select a session",
    finder = finders.new_table {
      results = sessionids,
      entry_maker = function(sessionid)
        return {
          value   = sessionid,
          display = session_names[sessionid],
          ordinal = session_names[sessionid],
        }
      end
    },
    sorter = sorters.get_generic_fuzzy_sorter(),
    attach_mappings = function (prompt_bufnr)
      actions.select_default:replace(function ()
        actions.close(prompt_bufnr)
        ---@type number sessionid 
        local sessionid = actions_state.get_selected_entry().value
        callback(sessionid)
      end)
      return true
    end,
  }):find()
end

---@param models FacileLLM.LLMConfig[]
---@param callback function(FacileLLM.LLMConfig): nil
---@param title string?
---@return nil
local select_model = function (models, callback, title)
  pickers.new({}, {
    prompt_title = title or "Select an LLM model",
    finder = finders.new_table {
      results = models,
      entry_maker = function(model)
        return {
          value   = model,
          display = model.name,
          ordinal = model.name,
        }
      end
    },
    sorter = sorters.get_generic_fuzzy_sorter(),
    attach_mappings = function (prompt_bufnr)
      actions.select_default:replace(function ()
        actions.close(prompt_bufnr)
        ---@type FacileLLM.LLMConfig model
        local model_config = actions_state.get_selected_entry().value
        callback(model_config)
      end)
      return true
    end,
  }):find()
end


return {
  delete = delete,
  touch = touch,
  touch_window = touch_window,
  get_most_recent = get_most_recent,
  select_session = select_session,
  select_model = select_model,
}
