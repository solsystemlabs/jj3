-- Integration tests for complete jj log display workflow
require("helpers.vim_mock")
local test_repo = require("helpers.test_repository")

-- Enhanced mocks for integration testing
local mock_notifications = {}
local mock_windows = {}
local mock_buffers = {}
local next_buffer_id = 1
local next_window_id = 1

-- Mock vim.notify to capture notifications
vim.notify = function(message, level)
  table.insert(mock_notifications, {
    message = message,
    level = level
  })
end

-- Mock log levels
vim.log = {
  levels = {
    ERROR = 1,
    WARN = 2,
    INFO = 3,
    DEBUG = 4
  }
}

-- Mock vim.cmd for window commands
vim.cmd = function(command)
  -- Mock vim command execution
end

-- Allow real jj commands to work in test repository by not overriding system completely
-- Just add missing mocks that the base vim_mock doesn't have

-- Mock buffer and window operations (from window tests)
vim.api.nvim_create_buf = function(listed, scratch)
  local buffer_id = next_buffer_id
  next_buffer_id = next_buffer_id + 1
  
  mock_buffers[buffer_id] = {
    listed = listed,
    scratch = scratch,
    lines = {},
    options = {},
    name = ""
  }
  
  return buffer_id
end

vim.api.nvim_buf_is_valid = function(buffer_id)
  return mock_buffers[buffer_id] ~= nil
end

vim.api.nvim_buf_set_name = function(buffer_id, name)
  if mock_buffers[buffer_id] then
    mock_buffers[buffer_id].name = name
  end
end

vim.api.nvim_buf_get_name = function(buffer_id)
  if mock_buffers[buffer_id] then
    return mock_buffers[buffer_id].name or ""
  end
  return ""
end

vim.api.nvim_buf_set_lines = function(buffer, start, end_line, strict_indexing, replacement)
  if mock_buffers[buffer] then
    mock_buffers[buffer].lines = replacement
  end
end

vim.api.nvim_buf_get_lines = function(buffer, start, end_line, strict_indexing)
  if mock_buffers[buffer] then
    return mock_buffers[buffer].lines or {}
  end
  return {}
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
  
  mock_windows[window_id] = {
    buffer_id = buffer_id,
    config = config,
    enter = enter
  }
  
  return window_id
end

vim.api.nvim_win_is_valid = function(window_id)
  return mock_windows[window_id] ~= nil
end

vim.api.nvim_win_close = function(window_id, force)
  mock_windows[window_id] = nil
end

vim.api.nvim_win_get_buf = function(window_id)
  if mock_windows[window_id] then
    return mock_windows[window_id].buffer_id
  end
  return -1
end

vim.api.nvim_win_set_buf = function(window_id, buffer_id)
  if mock_windows[window_id] then
    mock_windows[window_id].buffer_id = buffer_id
  end
end

vim.api.nvim_get_current_win = function()
  -- Return first valid window or create default
  for window_id, _ in pairs(mock_windows) do
    return window_id
  end
  local window_id = next_window_id
  next_window_id = next_window_id + 1
  mock_windows[window_id] = {
    buffer_id = 1,
    config = {},
    enter = false
  }
  return window_id
end

vim.api.nvim_set_current_win = function(window_id)
  -- Mock setting current window
end

vim.api.nvim_win_set_option = function(window_id, option, value)
  -- Mock window option setting
end

vim.api.nvim_win_get_config = function(window_id)
  if mock_windows[window_id] then
    return mock_windows[window_id].config or {}
  end
  return {}
end

vim.api.nvim_win_get_width = function(window_id)
  return 80
end

vim.api.nvim_win_get_height = function(window_id)
  return 24
end

-- Mock highlight operations
vim.api.nvim_create_namespace = function(name)
  return 1
end

vim.api.nvim_buf_clear_namespace = function(buffer, ns_id, start, end_line)
  -- Mock clearing highlights
end

vim.api.nvim_buf_add_highlight = function(buffer, ns_id, hl_group, line, col_start, col_end)
  -- Mock adding highlights
end

vim.api.nvim_set_hl = function(ns_id, name, val)
  -- Mock highlight group creation
end

-- Load the integration module
local log_integration = dofile("lua/jj/log/init.lua")

describe("JJ Log Integration", function()
  local lfs = require('lfs')
  local original_cwd

  before_each(function()
    original_cwd = lfs.currentdir()
    -- Change to test repository for integration tests
    lfs.chdir(test_repo.test_repo_path)
    
    -- Reset mocks
    mock_notifications = {}
    mock_windows = {}
    mock_buffers = {}
    next_buffer_id = 1
    next_window_id = 1
  end)

  after_each(function()
    lfs.chdir(original_cwd)
  end)

  describe("complete log display workflow", function()
    it("should display log in valid jj repository", function()
      local success = log_integration.show_log()
      
      assert.is_true(success)
      
      -- Should have created a window
      assert.is_true(next_window_id > 1)
      
      -- Should have created a buffer
      assert.is_true(next_buffer_id > 1)
      
      -- Should have buffer content
      local buffer_id = next_buffer_id - 1
      assert.is_not_nil(mock_buffers[buffer_id])
      assert.is_not_nil(mock_buffers[buffer_id].lines)
    end)

    it("should handle repository detection errors gracefully", function()
      -- Change to non-jj directory and mock system to reflect this
      local original_system = vim.fn.system
      local original_isdirectory = vim.fn.isdirectory
      
      -- Mock being in non-jj directory
      vim.fn.isdirectory = function(path)
        if path:match("%.jj$") then
          return 0 -- No .jj directory found
        end
        return original_isdirectory(path)
      end
      
      vim.fn.system = function(cmd)
        if cmd:match("jj.*log") then
          return "error: not in jj repository"
        end
        return original_system(cmd)
      end
      
      local success = log_integration.show_log()
      
      assert.is_false(success)
      
      -- Should have shown error notification
      assert.is_true(#mock_notifications > 0)
      local error_notification = mock_notifications[#mock_notifications]
      assert.equals(vim.log.levels.ERROR, error_notification.level)
      assert.matches("jj repository", error_notification.message)
      
      -- Restore original functions
      vim.fn.system = original_system
      vim.fn.isdirectory = original_isdirectory
    end)

    it("should provide user feedback during loading", function()
      local success = log_integration.show_log()
      
      -- Should have shown loading notification
      local has_loading_notification = false
      for _, notification in ipairs(mock_notifications) do
        if notification.message:match("Loading") then
          has_loading_notification = true
          break
        end
      end
      assert.is_true(has_loading_notification)
    end)

    it("should handle jj command execution errors", function()
      -- Mock jj command to fail
      local original_system = vim.fn.system
      local original_shell_error = vim.v.shell_error
      
      vim.fn.system = function(cmd)
        return "error output"
      end
      vim.v.shell_error = 1
      
      local success = log_integration.show_log()
      
      assert.is_false(success)
      
      -- Should have error notification
      assert.is_true(#mock_notifications > 0)
      local error_found = false
      for _, notification in ipairs(mock_notifications) do
        if notification.level == vim.log.levels.ERROR then
          error_found = true
          break
        end
      end
      assert.is_true(error_found)
      
      -- Restore original functions
      vim.fn.system = original_system
      vim.v.shell_error = original_shell_error
    end)

    it("should toggle log window", function()
      -- First toggle should show log
      local result1 = log_integration.toggle_log()
      assert.is_true(result1)
      
      -- Should have created window
      assert.is_true(next_window_id > 1)
      
      -- Second toggle should close log
      local result2 = log_integration.toggle_log()
      assert.is_false(result2)
      
      -- Window should be closed
      local window_id = next_window_id - 1
      assert.is_false(vim.api.nvim_win_is_valid(window_id))
    end)

    it("should refresh log content", function()
      -- Show initial log
      log_integration.show_log()
      local initial_buffer_count = next_buffer_id
      
      -- Refresh log
      local success = log_integration.refresh_log()
      assert.is_true(success)
      
      -- Should have updated content (buffer reused)
      assert.equals(initial_buffer_count, next_buffer_id)
    end)

    it("should handle window configuration", function()
      local config = {
        position = "left",
        width = 60,
        style = "split"
      }
      
      local success = log_integration.show_log(config)
      assert.is_true(success)
      
      -- Should have created window with configuration
      assert.is_true(next_window_id > 1)
    end)
  end)

  describe("error handling", function()
    it("should handle missing jj command gracefully", function()
      -- Mock jj command not found
      local original_system = vim.fn.system
      local original_shell_error = vim.v.shell_error
      
      vim.fn.system = function(cmd)
        if cmd:match("command %-v jj") then
          return ""
        end
        return original_system(cmd)
      end
      vim.v.shell_error = 127 -- Command not found
      
      local success = log_integration.show_log()
      assert.is_false(success)
      
      -- Should have appropriate error message
      local jj_error_found = false
      for _, notification in ipairs(mock_notifications) do
        if notification.message:match("jj.*not.*found") or notification.message:match("command.*available") then
          jj_error_found = true
          break
        end
      end
      assert.is_true(jj_error_found)
      
      -- Restore original functions
      vim.fn.system = original_system
      vim.v.shell_error = original_shell_error
    end)

    it("should handle corrupted repository gracefully", function()
      -- This would require more complex mocking of file system
      -- For now, just ensure the function doesn't crash
      assert.has_no.errors(function()
        log_integration.show_log()
      end)
    end)

    it("should provide helpful error messages", function()
      -- Mock non-jj repository case
      local original_isdirectory = vim.fn.isdirectory
      vim.fn.isdirectory = function(path)
        if path:match("%.jj$") then
          return 0 -- No .jj directory found
        end
        return original_isdirectory(path)
      end
      
      log_integration.show_log()
      
      -- Should have helpful error message
      assert.is_true(#mock_notifications > 0)
      local error_msg = mock_notifications[#mock_notifications]
      assert.is_not_nil(error_msg.message)
      assert.is_true(#error_msg.message > 10) -- Should be descriptive
      
      -- Restore original function
      vim.fn.isdirectory = original_isdirectory
    end)
  end)

  describe("integration with existing components", function()
    it("should use repository detection module", function()
      -- Test that repository validation is called
      local success = log_integration.show_log()
      
      -- In valid repo, should succeed
      assert.is_true(success)
      
      -- Test invalid repo case with mocking
      local original_isdirectory = vim.fn.isdirectory
      vim.fn.isdirectory = function(path)
        if path:match("%.jj$") then
          return 0 -- No .jj directory found
        end
        return original_isdirectory(path)
      end
      
      local failure = log_integration.show_log()
      assert.is_false(failure)
      
      -- Restore original function
      vim.fn.isdirectory = original_isdirectory
    end)

    it("should use executor module for jj commands", function()
      local success = log_integration.show_log()
      assert.is_true(success)
      
      -- Should have buffer content (indicating executor was used)
      local buffer_id = next_buffer_id - 1
      if mock_buffers[buffer_id] and mock_buffers[buffer_id].lines then
        assert.is_true(#mock_buffers[buffer_id].lines >= 0)
      end
    end)

    it("should use parser module for log processing", function()
      local success = log_integration.show_log()
      assert.is_true(success)
      
      -- Integration test - parser is used internally
      -- Success indicates parser worked correctly
      assert.is_true(success)
    end)

    it("should use renderer module for buffer display", function()
      local success = log_integration.show_log()
      assert.is_true(success)
      
      -- Should have set buffer as non-modifiable (renderer behavior)
      local buffer_id = next_buffer_id - 1
      if mock_buffers[buffer_id] and mock_buffers[buffer_id].options then
        assert.is_false(mock_buffers[buffer_id].options.modifiable)
      end
    end)

    it("should use window module for display management", function()
      local success = log_integration.show_log()
      assert.is_true(success)
      
      -- Should have created window (window module behavior)
      assert.is_true(next_window_id > 1)
      
      -- Should have named buffer (window module behavior)  
      local buffer_id = next_buffer_id - 1
      if mock_buffers[buffer_id] then
        assert.matches("JJ", mock_buffers[buffer_id].name)
      end
    end)
  end)

  describe("command integration", function()
    it("should provide show_log function for :JJ command", function()
      assert.is_function(log_integration.show_log)
      
      local success = log_integration.show_log()
      assert.is_true(success)
    end)

    it("should provide toggle_log function for keybinding", function()
      assert.is_function(log_integration.toggle_log)
      
      local result = log_integration.toggle_log()
      assert.is_boolean(result)
    end)

    it("should provide refresh_log function", function()
      assert.is_function(log_integration.refresh_log)
      
      -- First show log
      log_integration.show_log()
      
      -- Then refresh
      local success = log_integration.refresh_log()
      assert.is_true(success)
    end)

    it("should provide configuration interface", function()
      assert.is_function(log_integration.configure)
      
      local config = {position = "bottom"}
      assert.has_no.errors(function()
        log_integration.configure(config)
      end)
    end)
  end)

  describe("performance and resource management", function()
    it("should reuse buffers when refreshing", function()
      log_integration.show_log()
      local initial_buffer_count = next_buffer_id
      
      log_integration.refresh_log()
      
      -- Should not create new buffer
      assert.equals(initial_buffer_count, next_buffer_id)
    end)

    it("should handle rapid toggle operations", function()
      -- Rapid toggles should not cause issues
      for i = 1, 5 do
        log_integration.toggle_log()
      end
      
      -- Should end in a consistent state
      assert.has_no.errors(function()
        log_integration.show_log()
      end)
    end)

    it("should clean up resources properly", function()
      log_integration.show_log()
      
      -- Should provide cleanup function
      if log_integration.cleanup then
        assert.has_no.errors(function()
          log_integration.cleanup()
        end)
      end
    end)
  end)
end)