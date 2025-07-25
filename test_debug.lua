-- Quick debug script to test show_log functionality
package.path = package.path .. ";tests/?.lua"
require("helpers.vim_mock")

-- Set up basic mocks
vim.fn = vim.fn or {}
vim.fn.getcwd = function() return "/Users/tayloreernisse/projects/jj3/tests/fixtures/complex-repo" end
vim.fn.isdirectory = function(path)
  local lfs = require('lfs')
  local attr = lfs.attributes(path)
  return (attr and attr.mode == "directory") and 1 or 0
end
vim.fn.fnamemodify = function(path, modifier)
  if modifier == ":h" then
    return path:match("^(.+)/[^/]*$") or "/"
  end
  return path
end
vim.fn.system = function(command)
  if command:match("command %-v jj") then
    return "/usr/local/bin/jj\n"
  elseif command:match("jj %-%-version") then
    return "jj 0.15.1\n"
  elseif command:match("jj.*log") then
    local test_repo = require("helpers.test_repository")
    return test_repo.load_snapshot("colored_log")
  end
  return ""
end

vim.v = vim.v or {}
vim.v.shell_error = 0

vim.notify = function(message, level)
  print("NOTIFY:", message, level)
end

vim.log = {
  levels = {
    ERROR = 1,
    WARN = 2,
    INFO = 3,
    DEBUG = 4
  }
}

-- Mock window/buffer operations
local next_buffer_id = 1
local next_window_id = 1
local mock_buffers = {}
local mock_windows = {}

vim.api = vim.api or {}
vim.api.nvim_create_buf = function(listed, scratch)
  local buffer_id = next_buffer_id
  next_buffer_id = next_buffer_id + 1
  mock_buffers[buffer_id] = {listed = listed, scratch = scratch, lines = {}, options = {}, name = ""}
  return buffer_id
end

vim.api.nvim_buf_set_name = function(buffer_id, name)
  if mock_buffers[buffer_id] then
    mock_buffers[buffer_id].name = name
  end
end

vim.api.nvim_buf_set_lines = function(buffer, start, end_line, strict_indexing, replacement)
  if mock_buffers[buffer] then
    mock_buffers[buffer].lines = replacement
  end
end

vim.api.nvim_buf_set_option = function(buffer_id, option, value)
  if mock_buffers[buffer_id] then
    if not mock_buffers[buffer_id].options then
      mock_buffers[buffer_id].options = {}
    end
    mock_buffers[buffer_id].options[option] = value
  end
end

vim.api.nvim_open_win = function(buffer_id, enter, config)
  local window_id = next_window_id
  next_window_id = next_window_id + 1
  mock_windows[window_id] = {buffer_id = buffer_id, config = config, enter = enter}
  return window_id
end

vim.api.nvim_win_is_valid = function(window_id)
  return mock_windows[window_id] ~= nil
end

vim.api.nvim_create_namespace = function(name) return 1 end
vim.api.nvim_buf_clear_namespace = function() end
vim.api.nvim_buf_add_highlight = function() end
vim.api.nvim_set_hl = function() end

-- Change to test repository
local lfs = require('lfs')
lfs.chdir("tests/fixtures/complex-repo")

-- Now test the integration
local log_integration = dofile("lua/jj/log/init.lua")

print("Testing show_log...")
local success = log_integration.show_log()
print("Result:", success)

print("Next buffer ID:", next_buffer_id)
print("Next window ID:", next_window_id)
print("Mock buffers:", vim.inspect(mock_buffers))
print("Mock windows:", vim.inspect(mock_windows))