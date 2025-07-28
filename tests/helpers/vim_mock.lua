-- Mock vim APIs for testing
local M = {}
local lfs = require('lfs')

-- Mock vim global
_G.vim = {
  api = {
    nvim_create_user_command = function(name, fn, opts)
      -- Mock implementation
      vim.user_commands = vim.user_commands or {}
      vim.user_commands[name] = {fn = fn, opts = opts}
    end,
    nvim_create_autocmd = function(event, opts)
      -- Mock autocmd creation
      return 1 -- Mock autocmd ID
    end,
    nvim_set_hl = function(ns_id, name, val)
      -- Mock highlight group creation
    end,
    nvim_create_namespace = function(name)
      -- Mock namespace creation
      return 1 -- Return mock namespace ID
    end,
    nvim_buf_clear_namespace = function(buffer, ns_id, start, end_line)
      -- Mock clearing namespace highlights
    end,
    nvim_buf_add_highlight = function(buffer, ns_id, hl_group, line, col_start, col_end)
      -- Mock adding highlight
    end,
    nvim_get_hl_by_name = function(name, rgb)
      -- Mock highlight group retrieval
      local mock_highlights = {
        Normal = {foreground = 0xFFFFFF, background = 0x000000},
        Comment = {foreground = 0x808080},
        String = {foreground = 0x00FF00},
        Number = {foreground = 0x0000FF},
        Function = {foreground = 0xFF00FF}
      }
      return mock_highlights[name] or {}
    end,
  },
  keymap = {
    set = function(mode, lhs, rhs, opts)
      -- Mock implementation
    end,
  },
  fn = {
    getcwd = function()
      return lfs.currentdir()
    end,
    isdirectory = function(path)
      local attr = lfs.attributes(path)
      return (attr and attr.mode == "directory") and 1 or 0
    end,
    fnamemodify = function(path, modifier)
      if modifier == ":h" then
        -- Return parent directory
        return path:match("^(.+)/[^/]*$") or path
      end
      return path
    end,
    system = function(cmd)
      local handle = io.popen(cmd .. "; echo $?")
      local full_result = handle:read("*all")
      handle:close()
      
      -- Extract exit code from last line
      local lines = {}
      for line in full_result:gmatch("[^\n]*") do
        if line ~= "" then
          table.insert(lines, line)
        end
      end
      
      local exit_code = tonumber(lines[#lines]) or 0
      vim.v.shell_error = exit_code
      
      -- Return everything except the exit code
      table.remove(lines, #lines)
      return table.concat(lines, "\n")
    end,
    jobstart = function(cmd, opts)
      -- Mock async job execution
      local output = vim.fn.system(cmd)
      local exit_code = vim.v.shell_error
      
      -- Simulate async behavior
      if opts and opts.on_exit then
        opts.on_exit(nil, exit_code)
      end
      
      return 1 -- Mock job ID
    end,
    shellescape = function(str)
      -- Simple shell escaping for testing
      return "'" .. str:gsub("'", "'\"'\"'") .. "'"
    end,
  },
  v = {
    shell_error = 0,
  },
  wait = function(ms)
    -- Mock implementation - just sleep briefly
    local start = os.clock()
    while os.clock() - start < (ms / 1000) do
      -- busy wait
    end
  end,
  loop = {
    now = function()
      return os.clock() * 1000 -- return milliseconds
    end
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
  tbl_extend = function(behavior, ...)
    -- Simple extend implementation for testing
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
  list_extend = function(list, items)
    for _, item in ipairs(items) do
      table.insert(list, item)
    end
    return list
  end,
  trim = function(str)
    if not str then return "" end
    return str:match("^%s*(.-)%s*$")
  end,
  split = function(str, sep, opts)
    if not str then return {} end
    opts = opts or {}
    local result = {}
    
    if opts.plain then
      -- Plain text split - handle null bytes and other special chars
      local start = 1
      while true do
        local found = str:find(sep, start, true)
        if not found then
          table.insert(result, str:sub(start))
          break
        end
        table.insert(result, str:sub(start, found - 1))
        start = found + #sep
      end
    else
      -- Pattern split
      for part in str:gmatch("([^" .. sep .. "]+)") do
        table.insert(result, part)
      end
    end
    
    return result
  end,
  notify = function(message, level)
    -- Mock notification
  end,
  log = {
    levels = {
      ERROR = 1,
      WARN = 2,  
      INFO = 3,
      DEBUG = 4
    }
  },
  user_commands = {},
}

-- Helper functions for mocking specific vim functions in tests
function M.mock_vim_fn_input(return_value)
  vim.fn.input = function(prompt)
    return return_value or ""
  end
end

function M.mock_current_line(line_content)
  vim.api.nvim_get_current_line = function()
    return line_content or ""
  end
end

return M