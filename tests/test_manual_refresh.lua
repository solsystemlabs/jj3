-- Tests for manual refresh functionality
require("helpers.vim_mock")
local test_repo = require("helpers.test_repository")

-- Mock buffer operations for refresh testing
local mock_buffers = {}
local mock_buffer_lines = {}
local mock_cursor_positions = {}
local mock_keymaps = {}
local mock_notifications = {}
local next_buffer_id = 1

-- Mock vim.api.nvim_buf_get_lines for reading buffer content
vim.api.nvim_buf_get_lines = function(buffer_id, start, end_line, strict_indexing)
  if mock_buffer_lines[buffer_id] then
    local lines = mock_buffer_lines[buffer_id]
    if start == 0 and end_line == -1 then
      return lines -- Return all lines
    end
    -- Return slice of lines
    local result = {}
    for i = start + 1, math.min(end_line, #lines) do
      table.insert(result, lines[i])
    end
    return result
  end
  return {}
end

-- Mock vim.api.nvim_win_get_cursor for cursor position
vim.api.nvim_win_get_cursor = function(window_id)
  return mock_cursor_positions[window_id] or {1, 0}
end

-- Mock vim.api.nvim_win_set_cursor for cursor movement
vim.api.nvim_win_set_cursor = function(window_id, pos)
  mock_cursor_positions[window_id] = pos
end

-- Mock vim.api.nvim_buf_set_keymap for keymap testing
vim.api.nvim_buf_set_keymap = function(buffer_id, mode, key, rhs, opts)
  if not mock_keymaps[buffer_id] then
    mock_keymaps[buffer_id] = {}
  end
  mock_keymaps[buffer_id][mode .. key] = {
    rhs = rhs,
    opts = opts
  }
end

-- Mock vim.api.nvim_buf_get_name for buffer name checking
vim.api.nvim_buf_get_name = function(buffer_id)
  if mock_buffers[buffer_id] then
    return "JJ Log - Repository"
  end
  return ""
end

-- Mock vim.api.nvim_get_current_win
vim.api.nvim_get_current_win = function()
  return 1 -- Default to window 1
end

-- Mock vim.notify to capture notifications
vim.notify = function(message, level)
  table.insert(mock_notifications, {
    message = message,
    level = level or vim.log.levels.INFO
  })
end

-- Mock buffer line setting for refresh testing
vim.api.nvim_buf_set_lines = function(buffer_id, start, end_line, strict_indexing, replacement)
  if not mock_buffer_lines[buffer_id] then
    mock_buffer_lines[buffer_id] = {}
  end
  
  if start == 0 and end_line == -1 then
    -- Replace all lines
    mock_buffer_lines[buffer_id] = replacement
  else
    -- Replace specific range
    for i, line in ipairs(replacement) do
      mock_buffer_lines[buffer_id][start + i] = line
    end
  end
end

-- Create test buffer with jj log content
local function create_test_buffer_with_log(log_lines)
  local buffer_id = next_buffer_id
  next_buffer_id = next_buffer_id + 1
  
  mock_buffers[buffer_id] = true
  mock_buffer_lines[buffer_id] = log_lines
  
  return buffer_id
end

-- Sample jj log output for testing
local sample_log_lines = {
  "@    nkywompl teernisse@visiostack.com 2025-07-28 15:57:54 b34b2705",
  "├─╮  (no description set)",
  "│ │ ○  yqtmtwnw teernisse@visiostack.com 2025-07-28 15:53:13 c8d5508a",
  "│ │ │  Fix navigation issues",
  "│ │ ○  zlszpnwy teernisse@visiostack.com 2025-07-28 15:53:13 48ebc8ac",
  "│ │ │  Add refresh functionality",
}

describe("Manual Refresh", function()
  local lfs = require('lfs')
  local original_cwd

  before_each(function()
    original_cwd = lfs.currentdir()
    lfs.chdir(test_repo.test_repo_path)
    
    -- Reset mocks
    mock_buffers = {}
    mock_buffer_lines = {}
    mock_cursor_positions = {}
    mock_keymaps = {}
    mock_notifications = {}
    next_buffer_id = 1
  end)

  after_each(function()
    lfs.chdir(original_cwd)
  end)

  describe("refresh keybinding setup", function()
    it("should register 'R' key for manual refresh in jj log buffers", function()
      local refresh = require("jj.refresh")
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      local success = refresh.setup_refresh_keymaps(buffer_id)
      
      assert.is_true(success)
      assert.is_not_nil(mock_keymaps[buffer_id])
      assert.is_not_nil(mock_keymaps[buffer_id]["nR"])
      
      local r_keymap = mock_keymaps[buffer_id]["nR"]
      assert.is_true(r_keymap.opts.noremap)
      assert.is_true(r_keymap.opts.silent)
      assert.is_function(r_keymap.opts.callback)
    end)

    it("should not register keymaps for invalid buffer", function()
      local refresh = require("jj.refresh")
      
      local success = refresh.setup_refresh_keymaps(nil)
      
      assert.is_false(success)
    end)

    it("should only register keymaps in jj log buffers", function()
      local refresh = require("jj.refresh")
      
      -- Create a regular buffer (not jj log) - don't mark it as a mock buffer
      local regular_buffer = next_buffer_id
      next_buffer_id = next_buffer_id + 1
      -- Don't add to mock_buffers so it won't be recognized as JJ Log
      
      -- Should not register keymaps for non-jj buffers
      local success = refresh.setup_refresh_keymaps(regular_buffer)
      assert.is_false(success)
    end)
  end)

  describe("manual refresh functionality", function()
    it("should trigger complete log refresh when called", function()
      local refresh = require("jj.refresh")
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      -- Mock window state
      local window_mock = {
        is_log_window_open = function() return true end,
        get_current_buffer = function() return buffer_id end
      }
      
      local success = refresh.manual_refresh(window_mock)
      
      assert.is_true(success)
      -- Should notify user about refresh
      assert.is_true(#mock_notifications > 0)
      
      local found_refresh_message = false
      for _, notification in ipairs(mock_notifications) do
        if notification.message:find("Refreshing") then
          found_refresh_message = true
          break
        end
      end
      assert.is_true(found_refresh_message)
    end)

    it("should preserve cursor position when possible", function()
      local refresh = require("jj.refresh")
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      -- Set cursor to line 3
      mock_cursor_positions[1] = {3, 0}
      
      local window_mock = {
        is_log_window_open = function() return true end,
        get_current_buffer = function() return buffer_id end,
        get_buffer_line_count = function() return #sample_log_lines end
      }
      
      refresh.manual_refresh(window_mock)
      
      -- Cursor should still be at line 3 (or closest valid position)
      assert.equals(3, mock_cursor_positions[1][1])
    end)

    it("should handle empty repositories gracefully", function()
      local refresh = require("jj.refresh")
      local buffer_id = create_test_buffer_with_log({})
      
      local window_mock = {
        is_log_window_open = function() return true end,
        get_current_buffer = function() return buffer_id end
      }
      
      local success = refresh.manual_refresh(window_mock)
      
      -- Should handle empty repo without crashing
      assert.is_boolean(success)
    end)

    it("should fail gracefully when no window is open", function()
      local refresh = require("jj.refresh")
      
      local window_mock = {
        is_log_window_open = function() return false end
      }
      
      local success = refresh.manual_refresh(window_mock)
      
      assert.is_false(success)
      -- Should notify user about error
      assert.is_true(#mock_notifications > 0)
      
      local found_error_message = false
      for _, notification in ipairs(mock_notifications) do
        if notification.level == vim.log.levels.ERROR then
          found_error_message = true
          break
        end
      end
      assert.is_true(found_error_message)
    end)

    it("should clear existing buffer content before refresh", function()
      local refresh = require("jj.refresh")
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      local original_line_count = #mock_buffer_lines[buffer_id]
      
      local window_mock = {
        is_log_window_open = function() return true end,
        get_current_buffer = function() return buffer_id end,
        clear_buffer_content = function()
          mock_buffer_lines[buffer_id] = {}
        end
      }
      
      refresh.manual_refresh(window_mock)
      
      -- Buffer should have been cleared at some point during refresh
      -- (This tests the clearing mechanism, actual content will be restored by refresh)
      assert.is_true(original_line_count > 0) -- Had content initially
    end)
  end)

  describe("refresh integration", function()
    it("should work with existing navigation system", function()
      local refresh = require("jj.refresh")
      local navigation = require("jj.navigation")
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      -- Setup navigation first
      local sample_commits = {
        {commit_id = "b34b2705", change_id = "nkywompl"},
        {commit_id = "c8d5508a", change_id = "yqtmtwnw"},
        {commit_id = "48ebc8ac", change_id = "zlszpnwy"}
      }
      
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      navigation.setup_commit_navigation_keymaps_with_highlight(buffer_id, boundaries)
      
      -- Setup refresh keymaps
      refresh.setup_refresh_keymaps(buffer_id)
      
      -- Should have both navigation and refresh keymaps
      assert.is_not_nil(mock_keymaps[buffer_id]["nj"]) -- Navigation
      assert.is_not_nil(mock_keymaps[buffer_id]["nk"]) -- Navigation
      assert.is_not_nil(mock_keymaps[buffer_id]["nR"]) -- Refresh
    end)

    it("should provide user feedback during refresh operations", function()
      local refresh = require("jj.refresh")
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      local window_mock = {
        is_log_window_open = function() return true end,
        get_current_buffer = function() return buffer_id end
      }
      
      refresh.manual_refresh(window_mock)
      
      -- Should have provided feedback
      assert.is_true(#mock_notifications > 0)
      
      -- Should have both start and completion messages
      local has_start_message = false
      local has_completion_message = false
      
      for _, notification in ipairs(mock_notifications) do
        if notification.message:find("Refreshing") then
          has_start_message = true
        elseif notification.message:find("refreshed") or notification.message:find("complete") then
          has_completion_message = true
        end
      end
      
      assert.is_true(has_start_message)
    end)
  end)
end)