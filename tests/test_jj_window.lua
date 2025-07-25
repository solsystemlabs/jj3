-- Tests for jj window and buffer management functionality
require("helpers.vim_mock")
local test_repo = require("helpers.test_repository")

-- Mock window and buffer operations
local mock_windows = {}
local mock_buffers = {}
local mock_buffer_options = {}
local mock_window_options = {}
local next_buffer_id = 1
local next_window_id = 1

-- Mock vim.cmd for split window commands
vim.cmd = function(command)
  -- Mock vim command execution
end

-- Mock additional window sizing functions
vim.api.nvim_win_set_width = function(window_id, width)
  -- Mock window width setting
end

vim.api.nvim_win_set_height = function(window_id, height)  
  -- Mock window height setting
end

-- Mock buffer content operations (needed by renderer)
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

-- Mock highlight operations (needed by renderer)
vim.api.nvim_create_namespace = function(name)
  return 1 -- Return mock namespace ID
end

vim.api.nvim_buf_clear_namespace = function(buffer, ns_id, start, end_line)
  -- Mock clearing namespace highlights
end

vim.api.nvim_buf_add_highlight = function(buffer, ns_id, hl_group, line, col_start, col_end)
  -- Mock adding highlight
end

-- Enhanced vim mock for window/buffer operations
vim.api.nvim_create_buf = function(listed, scratch)
  local buffer_id = next_buffer_id
  next_buffer_id = next_buffer_id + 1
  
  mock_buffers[buffer_id] = {
    listed = listed,
    scratch = scratch,
    lines = {},
    options = {}
  }
  
  return buffer_id
end

vim.api.nvim_buf_is_valid = function(buffer_id)
  return mock_buffers[buffer_id] ~= nil
end

vim.api.nvim_buf_get_name = function(buffer_id)
  if mock_buffers[buffer_id] then
    return mock_buffers[buffer_id].name or ""
  end
  return ""
end

vim.api.nvim_buf_set_name = function(buffer_id, name)
  if mock_buffers[buffer_id] then
    mock_buffers[buffer_id].name = name
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

vim.api.nvim_win_get_config = function(window_id)
  if mock_windows[window_id] then
    return mock_windows[window_id].config or {}
  end
  return {}
end

vim.api.nvim_win_set_config = function(window_id, config)
  if mock_windows[window_id] then
    mock_windows[window_id].config = config
  end
end

vim.api.nvim_get_current_win = function()
  -- Return first valid window or create one
  for window_id, _ in pairs(mock_windows) do
    return window_id
  end
  -- Create a default window for testing
  local window_id = next_window_id
  next_window_id = next_window_id + 1
  mock_windows[window_id] = {
    buffer_id = 1, -- Default buffer
    config = {},
    enter = false
  }
  return window_id
end

vim.api.nvim_set_current_win = function(window_id)
  -- Mock setting current window
end

vim.api.nvim_win_get_width = function(window_id)
  return 80 -- Default width
end

vim.api.nvim_win_get_height = function(window_id)
  return 24 -- Default height
end

-- Override buffer option setting to track options
local original_buf_set_option = vim.api.nvim_buf_set_option
vim.api.nvim_buf_set_option = function(buffer_id, option, value)
  if not mock_buffer_options[buffer_id] then
    mock_buffer_options[buffer_id] = {}
  end
  mock_buffer_options[buffer_id][option] = value
  
  -- Call original if it exists
  if original_buf_set_option then
    original_buf_set_option(buffer_id, option, value)
  end
end

vim.api.nvim_win_set_option = function(window_id, option, value)
  if not mock_window_options[window_id] then
    mock_window_options[window_id] = {}
  end
  mock_window_options[window_id][option] = value
end

-- Load the window module from the plugin directory
local window = dofile("../lua/jj/ui/window.lua")

describe("JJ Window Management", function()
  local lfs = require('lfs')
  local original_cwd

  before_each(function()
    original_cwd = lfs.currentdir()
    -- Change to test repository for all tests
    lfs.chdir(test_repo.test_repo_path)
    
    -- Reset mocks
    mock_windows = {}
    mock_buffers = {}
    mock_buffer_options = {}
    mock_window_options = {}
    next_buffer_id = 1
    next_window_id = 1
  end)

  after_each(function()
    lfs.chdir(original_cwd)
  end)

  describe("buffer management", function()
    it("should create a new jj log buffer", function()
      local buffer_id = window.create_log_buffer()
      
      assert.is_not_nil(buffer_id)
      assert.is_number(buffer_id)
      assert.is_true(vim.api.nvim_buf_is_valid(buffer_id))
      
      -- Should be unlisted and scratch
      assert.is_not_nil(mock_buffers[buffer_id])
      assert.is_false(mock_buffers[buffer_id].listed)
      assert.is_true(mock_buffers[buffer_id].scratch)
    end)

    it("should set appropriate buffer options", function()
      local buffer_id = window.create_log_buffer()
      
      -- Should have set buffer options
      assert.is_not_nil(mock_buffer_options[buffer_id])
      assert.equals("nofile", mock_buffer_options[buffer_id].buftype)
      assert.equals("hide", mock_buffer_options[buffer_id].bufhidden)
      assert.is_false(mock_buffer_options[buffer_id].swapfile)
      assert.is_false(mock_buffer_options[buffer_id].modifiable)
    end)

    it("should reuse existing log buffer if valid", function()
      local buffer_id1 = window.create_log_buffer()
      local buffer_id2 = window.get_or_create_log_buffer()
      
      assert.equals(buffer_id1, buffer_id2)
    end)

    it("should create new buffer if previous is invalid", function()
      local buffer_id1 = window.create_log_buffer()
      
      -- Simulate buffer becoming invalid
      mock_buffers[buffer_id1] = nil
      
      local buffer_id2 = window.get_or_create_log_buffer()
      
      assert.is_not_nil(buffer_id2)
      assert.not_equals(buffer_id1, buffer_id2)
    end)

    it("should set buffer name correctly", function()
      local buffer_id = window.create_log_buffer()
      
      local name = vim.api.nvim_buf_get_name(buffer_id)
      assert.matches("JJ Log", name)
    end)
  end)

  describe("window management", function()
    it("should open log window with default configuration", function()
      local window_id = window.open_log_window()
      
      assert.is_not_nil(window_id)
      assert.is_number(window_id)
      assert.is_true(vim.api.nvim_win_is_valid(window_id))
      
      -- Should have opened with a buffer
      local buffer_id = vim.api.nvim_win_get_buf(window_id)
      assert.is_not_nil(buffer_id)
      assert.is_true(vim.api.nvim_buf_is_valid(buffer_id))
    end)

    it("should configure window with split positioning", function()
      local config = {
        position = "right",
        width = 60,
        height = 20
      }
      
      local window_id = window.open_log_window(config)
      
      assert.is_not_nil(window_id)
      
      -- Check window configuration
      local win_config = vim.api.nvim_win_get_config(window_id)
      assert.is_not_nil(win_config)
    end)

    it("should handle different window positions", function()
      local positions = {"left", "right", "top", "bottom"}
      
      for _, position in ipairs(positions) do
        local config = {position = position}
        local window_id = window.open_log_window(config)
        
        assert.is_not_nil(window_id, "Failed to create window for position: " .. position)
        assert.is_true(vim.api.nvim_win_is_valid(window_id))
        
        -- Clean up
        vim.api.nvim_win_close(window_id, true)
      end
    end)

    it("should set appropriate window options", function()
      local window_id = window.open_log_window()
      
      -- Should have set window options
      assert.is_not_nil(mock_window_options[window_id])
      assert.is_true(mock_window_options[window_id].wrap)  -- Text wrapping should be enabled
      assert.is_false(mock_window_options[window_id].spell)
      assert.equals("jj", mock_window_options[window_id].filetype)
    end)

    it("should enable text wrapping for long lines", function()
      local window_id = window.open_log_window()
      
      -- Verify text wrapping is specifically enabled
      assert.is_not_nil(mock_window_options[window_id])
      assert.is_true(mock_window_options[window_id].wrap)
      
      -- This ensures long log lines will wrap instead of being truncated
      -- when the window is too narrow to display the full content
    end)

    it("should create window using create_window function", function()
      local window_id = window.create_window()
      
      assert.is_not_nil(window_id)
      assert.is_number(window_id)
      assert.is_true(vim.api.nvim_win_is_valid(window_id))
    end)

    it("should create floating window directly", function()
      local buffer_id = window.setup_buffer()
      local config = {
        width = 80,
        height = 20,
        row = 5,
        col = 10,
        border = "rounded"
      }
      
      local window_id = window.create_float_window(buffer_id, config)
      
      assert.is_not_nil(window_id)
      assert.is_true(vim.api.nvim_win_is_valid(window_id))
    end)

    it("should create split window directly", function()
      local buffer_id = window.setup_buffer()
      local config = {
        position = "right",
        width = 60
      }
      
      local window_id = window.create_split_window(buffer_id, config)
      
      assert.is_not_nil(window_id)
      assert.is_true(vim.api.nvim_win_is_valid(window_id))
    end)

    it("should support floating window configuration", function()
      local config = {
        style = "floating",
        width = 100,
        height = 30,
        row = 5,
        col = 10
      }
      
      local window_id = window.open_log_window(config)
      
      assert.is_not_nil(window_id)
      assert.is_true(vim.api.nvim_win_is_valid(window_id))
      
      local win_config = vim.api.nvim_win_get_config(window_id)
      assert.is_not_nil(win_config)
    end)
  end)

  describe("window lifecycle", function()
    it("should close log window", function()
      local window_id = window.open_log_window()
      assert.is_true(vim.api.nvim_win_is_valid(window_id))
      
      window.close_log_window()
      
      -- Window should be closed
      assert.is_false(vim.api.nvim_win_is_valid(window_id))
    end)

    it("should toggle log window", function()
      -- First toggle should open
      local opened = window.toggle_log_window()
      assert.is_true(opened)
      
      -- Should have a valid window
      local window_id = window.get_log_window_id()
      assert.is_not_nil(window_id)
      assert.is_true(vim.api.nvim_win_is_valid(window_id))
      
      -- Second toggle should close
      local closed = window.toggle_log_window()
      assert.is_false(closed)
      
      -- Window should be closed
      assert.is_false(vim.api.nvim_win_is_valid(window_id))
    end)

    it("should handle window focus", function()
      local window_id = window.open_log_window()
      
      window.focus_log_window()
      
      -- Should not error (focus is mocked)
      assert.is_true(vim.api.nvim_win_is_valid(window_id))
    end)

    it("should get current log window state", function()
      -- Initially no window
      assert.is_false(window.is_log_window_open())
      
      -- Open window
      local window_id = window.open_log_window()
      assert.is_not_nil(window_id)
      assert.is_true(window.is_log_window_open())
      
      -- Close window
      local closed = window.close_log_window()
      assert.is_true(closed)
      assert.is_false(window.is_log_window_open())
    end)

    it("should work with alias functions", function()
      -- Test is_window_open alias
      assert.is_false(window.is_window_open())
      
      -- Test create_window alias
      local window_id = window.create_window()
      assert.is_not_nil(window_id)
      assert.is_true(window.is_window_open())
      
      -- Test toggle_window alias
      local closed = window.toggle_window()
      assert.is_false(closed)
      assert.is_false(window.is_window_open())
      
      -- Test close_window alias  
      window.create_window()
      assert.is_true(window.is_window_open())
      local closed2 = window.close_window()
      assert.is_true(closed2)
      assert.is_false(window.is_window_open())
    end)
  end)

  describe("configuration", function()
    it("should apply user configuration", function()
      local user_config = {
        position = "left",
        width = 50,
        height = 25,
        style = "split"
      }
      
      window.configure(user_config)
      local applied_config = window.get_configuration()
      
      assert.equals("left", applied_config.position)
      assert.equals(50, applied_config.width)
      assert.equals(25, applied_config.height)
      assert.equals("split", applied_config.style)
    end)

    it("should merge with default configuration", function()
      local user_config = {
        position = "bottom"
      }
      
      window.configure(user_config)
      local applied_config = window.get_configuration()
      
      assert.equals("bottom", applied_config.position)
      -- Should still have other defaults
      assert.is_not_nil(applied_config.width)
      assert.is_not_nil(applied_config.height)
    end)

    it("should validate configuration values", function()
      local invalid_config = {
        position = "invalid_position",
        width = -10,
        height = 0
      }
      
      -- Should handle invalid config gracefully
      assert.has_no.errors(function()
        window.configure(invalid_config)
      end)
      
      local applied_config = window.get_configuration()
      -- Should use default values for invalid settings
      assert.not_equals("invalid_position", applied_config.position)
      assert.is_true(applied_config.width > 0)
      assert.is_true(applied_config.height > 0)
    end)
  end)

  describe("integration with renderer", function()
    it("should render content to log window", function()
      local window_id = window.open_log_window()
      local raw_output = "@    nkywompl teernisse@visiostack.com 2025-07-24 15:57:54 b34b2705\n├─╮  (no description set)\n"
      
      local success = window.render_log_content(raw_output)
      
      assert.is_true(success)
      
      -- Buffer should have content
      local buffer_id = vim.api.nvim_win_get_buf(window_id)
      assert.is_not_nil(buffer_id)
    end)

    it("should handle rendering when window is closed", function()
      local raw_output = "test content"
      
      -- Should handle gracefully when no window is open
      local success = window.render_log_content(raw_output)
      assert.is_false(success)
    end)

    it("should clear log content", function()
      local window_id = window.open_log_window()
      
      -- First add some content
      window.render_log_content("test content")
      
      -- Then clear it  
      local success = window.clear_log_content()
      assert.is_true(success)
    end)
  end)

  describe("error handling", function()
    it("should handle buffer creation failures gracefully", function()
      -- Mock buffer creation failure
      local original_create_buf = vim.api.nvim_create_buf
      vim.api.nvim_create_buf = function(listed, scratch)
        return nil -- Simulate failure
      end
      
      local buffer_id = window.create_log_buffer()
      assert.is_nil(buffer_id)
      
      -- Restore original function
      vim.api.nvim_create_buf = original_create_buf
    end)

    it("should handle window creation failures gracefully", function()
      -- Mock both window creation functions to fail
      local original_open_win = vim.api.nvim_open_win
      local original_get_current_win = vim.api.nvim_get_current_win
      
      vim.api.nvim_open_win = function(buffer_id, enter, config)
        return nil -- Simulate failure
      end
      
      vim.api.nvim_get_current_win = function()
        return nil -- Simulate failure in split window creation too
      end
      
      local window_id = window.open_log_window({style = "floating"})
      assert.is_nil(window_id)
      
      -- Restore original functions
      vim.api.nvim_open_win = original_open_win
      vim.api.nvim_get_current_win = original_get_current_win
    end)

    it("should handle invalid window operations", function()
      -- Try to close non-existent window
      assert.has_no.errors(function()
        window.close_log_window()
      end)
      
      -- Try to focus non-existent window
      assert.has_no.errors(function()
        window.focus_log_window()
      end)
    end)
  end)
end)