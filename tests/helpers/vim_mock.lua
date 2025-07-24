-- Mock vim APIs for testing
local M = {}

-- Mock vim global
_G.vim = {
  api = {
    nvim_create_user_command = function(name, fn, opts)
      -- Mock implementation
    end,
  },
  keymap = {
    set = function(mode, lhs, rhs, opts)
      -- Mock implementation
    end,
  },
  deepcopy = function(tbl)
    -- Simple deep copy implementation for testing
    if type(tbl) ~= 'table' then
      return tbl
    end
    local copy = {}
    for k, v in pairs(tbl) do
      copy[k] = vim.deepcopy(v)
    end
    return copy
  end,
  tbl_deep_extend = function(behavior, ...)
    -- Simple merge implementation for testing
    local result = {}
    for i = 1, select('#', ...) do
      local tbl = select(i, ...)
      if type(tbl) == 'table' then
        for k, v in pairs(tbl) do
          result[k] = v
        end
      end
    end
    return result
  end,
}

return M