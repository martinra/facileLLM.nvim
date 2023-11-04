local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")
local sorters = require("telescope.sorters")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")


---@type nil | number
local recent_sessionid = nil


---@param sessionid number
---@return nil
local delete = function (sessionid)
  if recent_sessionid == sessionid then
    recent_sessionid = nil
  end
end

---@param sessionid number
---@return nil
local touch = function (sessionid)
  recent_sessionid = sessionid
end

-- By most recent we mean the session that most recently was interacted with
-- as indicated by the touch command.
---@return nil | number sessionid
local get_most_recent = function ()
  return recent_sessionid
end

---@param sessions table<number,string>
---@param callback function(number): nil
---@return nil
local select_session = function (sessions, callback)
  local sessionids = {}
  for id,_ in pairs(sessions) do
    table.insert(sessionids,id)
  end

  pickers.new({}, {
    prompt_title = "Select a session",
    finder = finders.new_table {
      results = sessionids,
      entry_maker = function(sessionid)
        return {
          value   = sessionid,
          display = sessions[sessionid],
          ordinal = sessions[sessionid],
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

---@param models LLMConfig[]
---@param callback function(number): nil
---@return nil
local select_model = function (models, callback)
  pickers.new({}, {
    prompt_title = "Select an LLM model",
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
        ---@type LLMConfig model
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
  get_most_recent = get_most_recent,
  select_session = select_session,
  select_model = select_model,
}
