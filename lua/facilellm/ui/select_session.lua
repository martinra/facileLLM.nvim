local config = require("facilellm.config")
local ui_common = require("facilellm.ui.common")

local available_actions, actions = pcall(require, "telescope.actions")
local available_actions_state, actions_state = pcall(require, "telescope.actions.state")
local available_sorters, sorters = pcall(require, "telescope.sorters")
local available_finders, finders = pcall(require, "telescope.finders")
local available_pickers, pickers = pcall(require, "telescope.pickers")

local available_telescope = available_actions
  and available_actions_state
  and available_sorters
  and available_finders
  and available_pickers


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
---@param prompt string?
---@return nil
local select_session = function (session_names, callback, prompt)
  local sessionids = {}
  for id,_ in pairs(session_names) do
    table.insert(sessionids,id)
  end

  prompt = prompt or "Select a session"
  if config.opts.interface.telescope and available_telescope then
    pickers.new({}, {
      prompt_title = prompt,
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
  else
    vim.ui.select( sessionids,
      {
        prompt = prompt,
        format_item = function (sessionid)
          return session_names[sessionid]
        end,
      },
      function (sessionid)
        if sessionid ~= nil then
          callback(sessionid)
        end
      end)
  end
end

---@param models FacileLLM.Config.LLM[]
---@param callback function(FacileLLM.Config.LLM): nil
---@param prompt string?
---@return nil
local select_model = function (models, callback, prompt)
  prompt = prompt or "Select an LLM model"
  if config.opts.interface.telescope and available_telescope then
    pickers.new({}, {
      prompt_title = prompt,
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
          ---@type FacileLLM.Config.LLM model
          local model_config = actions_state.get_selected_entry().value
          callback(model_config)
        end)
        return true
      end,
    }):find()
  else
    vim.ui.select( models,
      {
        prompt = prompt,
        format_item = function (model)
          return model.name
        end,
      },
      function (model)
        if model ~= nil then
          callback(model)
        end
      end)
  end
end


return {
  delete = delete,
  touch = touch,
  touch_window = touch_window,
  get_most_recent = get_most_recent,
  select_session = select_session,
  select_model = select_model,
}
