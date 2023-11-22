local config = require("facilellm.config")
local conversation = require("facilellm.session.conversation")
local llm = require("facilellm.llm")
local session = require("facilellm.session")
local ui_common = require("facilellm.ui.common")
local ui_render = require("facilellm.ui.render")

local available_telescope, _ = pcall(require, "telescope")
local _, pickers = pcall(require, "telescope.pickers")
local _, actions = pcall(require, "telescope.actions")
local _, actions_state = pcall(require, "telescope.actions.state")
local _, finders = pcall(require, "telescope.finders")
local _, sorters = pcall(require, "telescope.sorters")
local _, previewers = pcall(require, "telescope.previewers")


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
    pickers.new({
      layout_strategy = "vertical",
    }, {
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
      previewer = previewers.new_buffer_previewer({
        title = "Session preview",
        define_preview = function(self, entry)
          local bufnr = self.state.bufnr
          if not bufnr then
            return
          end

          ---@type FacileLLM.SessionId
          local sessionid = entry.value

          local conv = session.get_conversation(sessionid)
          local lines = ui_render.preview_conversation(conv)

          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        end,
      }),
      attach_mappings = function (prompt_bufnr)
        actions.select_default:replace(function ()
          actions.close(prompt_bufnr)
          ---@type FacileLLM.SessionId
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
    pickers.new({
      layout_strategy = "vertical",
    }, {
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
      previewer = previewers.new_buffer_previewer({
        title = "LLM Model Preview",
        define_preview = function(self, entry)
          local bufnr = self.state.bufnr
          if not bufnr then
            return
          end

          ---@type FacileLLM.Config.LLM
          local model_config = entry.value

          local preview = llm.preview(model_config.implementation, model_config.opts)
          preview = preview or "Model preview not available.\n"
          local lines = vim.split(preview, "\n", {keepempty = true})
          table.insert(lines, 1, "")
          table.insert(lines, 1, "# Model")

          local conv = conversation.create(model_config.conversation)
          if conv ~= {} then
            table.insert(lines, "# Initial Conversation")
            table.insert(lines, "")
            for _,l in pairs(ui_render.preview_conversation(conv)) do
              table.insert(lines, l)
            end
          end

          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        end,
      }),
      attach_mappings = function (prompt_bufnr)
        actions.select_default:replace(function ()
          actions.close(prompt_bufnr)
          ---@type FacileLLM.Config.LLM
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

---@param conversations table<FacileLLM.ConversationName, FacileLLM.Conversation>
---@param callback function(FacileLLM.Conversation): nil
---@param prompt string?
---@return nil
local select_conversation = function (conversations, callback, prompt)
  local names = {}
  for name,_ in pairs(conversations) do
    table.insert(names,name)
  end

  prompt = prompt or "Select a conversation"
  if config.opts.interface.telescope and available_telescope then
    pickers.new({
      layout_strategy = "vertical",
    }, {
      prompt_title = prompt,
      finder = finders.new_table {
        results = names,
        entry_maker = function(name)
          return {
            value   = name,
            display = name,
            ordinal = name,
          }
        end
      },
      sorter = sorters.get_generic_fuzzy_sorter(),
      previewer = previewers.new_buffer_previewer({
        title = "Initial conversation preview",
        define_preview = function(self, entry)
          local bufnr = self.state.bufnr
          if not bufnr then
            return
          end

          ---@type FacileLLM.ConversationName
          local name = entry.value
          local conv = conversation.create(conversations[name])
          local lines = ui_render.preview_conversation(conv)

          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        end,
      }),
      attach_mappings = function (prompt_bufnr)
        actions.select_default:replace(function ()
          actions.close(prompt_bufnr)
          ---@type FacileLLM.ConversationName
          local name = actions_state.get_selected_entry().value
          callback(conversations[name])
        end)
        return true
      end,
    }):find()
  else
    vim.ui.select( names,
      {
        prompt = prompt,
        format_item = function (name)
          return name
        end,
      },
      function (name)
        if name ~= nil then
          callback(conversations[name])
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
  select_conversation = select_conversation,
}
