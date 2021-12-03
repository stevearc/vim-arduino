local M = {}

M.select_shim = function(title, items, callback)
  local opts = {
    prompt = title,
    format_item = function(item) return item.label or item.value end
  }
  vim.ui.select(items, opts, function(item)
    if item then
      vim.call(callback, item.value)
    end
  end)
end

return M
