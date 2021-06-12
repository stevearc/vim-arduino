local themes = require('telescope.themes')
local actions = require('telescope.actions')
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values

local M = {}

local entry_maker = function(item)
  return {
    display = item.label or item.value,
    ordinal = item.label or item.value,
    value = item.value,
  }
end

M.choose = function(title, items, callback)
  local opts = themes.get_dropdown{
    previewer = false,
  }
  pickers.new(opts, {
    prompt_title = title,
    finder = finders.new_table {
      results = items,
      entry_maker = entry_maker,
    },
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = actions.get_selected_entry()
        actions.close(prompt_bufnr)
        if type(callback) == "string" then
          vim.call(callback, selection.value)
        else
          callback(selection.value)
        end
      end)

      return true
    end
  }):find()
end

return M
