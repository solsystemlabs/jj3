-- Tests for auto-refresh functionality after jj commands
require("helpers.vim_mock")
local disposable_repo = require("helpers.disposable_repository")

-- Mock buffer operations and state tracking
local mock_buffers = {}
local mock_buffer_lines = {}
local mock_cursor_positions = {}
local mock_keymaps = {}
local mock_notifications = {}
local next_buffer_id = 1

-- Mock auto-refresh triggers
local mock_auto_refresh_triggers = {}
local mock_command_executions = {}

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

-- Mock command execution for testing
local function mock_jj_command_execution(command, success, output)
  table.insert(mock_command_executions, {
    command = command,
    success = success,
    output = output,
    timestamp = os.time()
  })
  
  -- Trigger auto-refresh if registered
  for _, trigger in ipairs(mock_auto_refresh_triggers) do
    if trigger.enabled then
      trigger.callback(command, success, output)
    end
  end
  
  -- Also trigger the auto-refresh module's command hooks
  local auto_refresh = require("jj.auto_refresh")
  auto_refresh.execute_command_hooks(command, success, output)
end

-- Register auto-refresh trigger for testing
local function register_auto_refresh_trigger(callback)
  local trigger = {
    callback = callback,
    enabled = true,
    id = #mock_auto_refresh_triggers + 1
  }
  table.insert(mock_auto_refresh_triggers, trigger)
  return trigger.id
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

local updated_log_lines = {
  "@    abcd1234 teernisse@visiostack.com 2025-07-28 16:00:00 newcommit",
  "├─╮  (new commit after command)",
  "│ │ ○  nkywompl teernisse@visiostack.com 2025-07-28 15:57:54 b34b2705",
  "│ │ │  (no description set)",
  "│ │ ○  yqtmtwnw teernisse@visiostack.com 2025-07-28 15:53:13 c8d5508a",
  "│ │ │  Fix navigation issues",
}

describe("Auto-Refresh System", function()
  local lfs = require('lfs')
  local original_cwd

  before_each(function()
    original_cwd = lfs.currentdir()
    
    -- Reset mocks
    mock_buffers = {}
    mock_buffer_lines = {}
    mock_cursor_positions = {}
    mock_keymaps = {}
    mock_notifications = {}
    mock_auto_refresh_triggers = {}
    mock_command_executions = {}
    next_buffer_id = 1
    
    -- Reset auto-refresh state
    local auto_refresh = require("jj.auto_refresh")
    auto_refresh.reset_auto_refresh_state()
    -- Disable throttling for testing
    auto_refresh.set_refresh_throttle(0)
  end)

  after_each(function()
    lfs.chdir(original_cwd)
    disposable_repo.cleanup_current_repo()
  end)

  describe("command execution hooks", function()
    it("should detect when jj commands complete successfully", function()
      local auto_refresh = require("jj.auto_refresh")
      local refresh_triggered = false
      local captured_command = nil
      
      -- Register a test callback
      auto_refresh.register_command_hook(function(command, success, output)
        refresh_triggered = true
        captured_command = command
      end)
      
      -- Mock a successful jj command execution
      mock_jj_command_execution("commit -m 'test commit'", true, "Working copy now at: abcd1234")
      
      assert.is_true(refresh_triggered)
      assert.equals("commit -m 'test commit'", captured_command)
    end)

    it("should detect when jj commands fail", function()
      local auto_refresh = require("jj.auto_refresh")
      local refresh_triggered = false
      local command_success = nil
      
      -- Register a test callback
      auto_refresh.register_command_hook(function(command, success, output)
        refresh_triggered = true
        command_success = success
      end)
      
      -- Mock a failed jj command execution
      mock_jj_command_execution("commit -m 'invalid'", false, "Error: no changes to commit")
      
      assert.is_true(refresh_triggered)
      assert.is_false(command_success)
    end)

    it("should allow multiple command hooks", function()
      local auto_refresh = require("jj.auto_refresh")
      local hook1_triggered = false
      local hook2_triggered = false
      
      -- Register multiple callbacks
      auto_refresh.register_command_hook(function(command, success, output)
        hook1_triggered = true
      end)
      
      auto_refresh.register_command_hook(function(command, success, output)
        hook2_triggered = true
      end)
      
      -- Mock command execution
      mock_jj_command_execution("new", true, "Working copy now at: newcommit")
      
      assert.is_true(hook1_triggered)
      assert.is_true(hook2_triggered)
    end)

    it("should allow disabling command hooks", function()
      local auto_refresh = require("jj.auto_refresh")
      local refresh_triggered = false
      
      -- Register and immediately disable
      local hook_id = auto_refresh.register_command_hook(function(command, success, output)
        refresh_triggered = true
      end)
      
      auto_refresh.disable_command_hook(hook_id)
      
      -- Mock command execution
      mock_jj_command_execution("new", true, "Working copy now at: newcommit")
      
      assert.is_false(refresh_triggered)
    end)
  end)

  describe("auto_refresh_after_command function", function()
    it("should refresh log window after successful jj commands", function()
      local auto_refresh = require("jj.auto_refresh")
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      local window_mock = {
        is_log_window_open = function() return true end,
        get_current_buffer = function() return buffer_id end,
        refresh_log_content = function(new_lines)
          mock_buffer_lines[buffer_id] = new_lines
          return true
        end
      }
      
      -- Test a command that should trigger refresh  
      -- First verify the command should trigger refresh
      assert.is_true(auto_refresh.should_trigger_refresh("commit -m 'test'", true))
      
      local success = auto_refresh.auto_refresh_after_command("commit -m 'test'", true, "success", window_mock)
      
      assert.is_true(success)
      -- Should notify user about auto-refresh
      assert.is_true(#mock_notifications > 0)
      
      -- Check that we have the expected auto-refresh messages
      local messages = {}
      for _, notification in ipairs(mock_notifications) do
        table.insert(messages, notification.message)
      end
      
      local has_start_message = false
      local has_completion_message = false
      
      for _, message in ipairs(messages) do
        if message:find("Auto%-refreshing after") then
          has_start_message = true
        elseif message:find("Auto%-refresh completed") then
          has_completion_message = true
        end
      end
      
      assert.is_true(has_start_message)
      assert.is_true(has_completion_message)
    end)

    it("should not refresh if no log window is open", function()
      local auto_refresh = require("jj.auto_refresh")
      
      local window_mock = {
        is_log_window_open = function() return false end
      }
      
      local success = auto_refresh.auto_refresh_after_command("commit -m 'test'", true, "success", window_mock)
      
      assert.is_false(success)
    end)

    it("should not refresh after failed commands by default", function()
      local auto_refresh = require("jj.auto_refresh")
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      local window_mock = {
        is_log_window_open = function() return true end,
        get_current_buffer = function() return buffer_id end
      }
      
      local success = auto_refresh.auto_refresh_after_command("commit -m 'invalid'", false, "error", window_mock)
      
      assert.is_false(success)
    end)

    it("should preserve cursor position during auto-refresh", function()
      local auto_refresh = require("jj.auto_refresh")
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      -- Set cursor to line 3
      mock_cursor_positions[1] = {3, 0}
      
      local window_mock = {
        is_log_window_open = function() return true end,
        get_current_buffer = function() return buffer_id end,
        get_buffer_line_count = function() return #updated_log_lines end,
        refresh_log_content = function(new_lines)
          mock_buffer_lines[buffer_id] = updated_log_lines
          return true
        end
      }
      
      auto_refresh.auto_refresh_after_command("new", true, "success", window_mock)
      
      -- Cursor should still be at line 3 (or closest valid position)
      assert.equals(3, mock_cursor_positions[1][1])
    end)

    it("should handle navigation state preservation", function()
      local auto_refresh = require("jj.auto_refresh")
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      local navigation_refreshed = false
      local window_mock = {
        is_log_window_open = function() return true end,
        get_current_buffer = function() return buffer_id end,
        refresh_log_content = function(new_lines)
          mock_buffer_lines[buffer_id] = updated_log_lines
          return true
        end,
        refresh_navigation = function()
          navigation_refreshed = true
          return true
        end
      }
      
      auto_refresh.auto_refresh_after_command("rebase", true, "success", window_mock)
      
      assert.is_true(navigation_refreshed)
    end)
  end)

  describe("integration with command execution workflow", function()
    it("should trigger auto-refresh for commit commands", function()
      -- This test will be implemented when we integrate with the actual command execution
      local auto_refresh = require("jj.auto_refresh")
      local refresh_count = 0
      
      auto_refresh.register_command_hook(function(command, success, output)
        if success and command:match("commit") then
          refresh_count = refresh_count + 1
        end
      end)
      
      -- Mock commit command execution
      mock_jj_command_execution("commit -m 'test commit'", true, "Working copy now at: abc123")
      
      assert.equals(1, refresh_count)
    end)

    it("should trigger auto-refresh for rebase commands", function()
      local auto_refresh = require("jj.auto_refresh")
      local refresh_count = 0
      
      auto_refresh.register_command_hook(function(command, success, output)
        if success and command:match("rebase") then
          refresh_count = refresh_count + 1
        end
      end)
      
      -- Mock rebase command execution
      mock_jj_command_execution("rebase -d main", true, "Rebased 3 commits")
      
      assert.equals(1, refresh_count)
    end)

    it("should trigger auto-refresh for abandon commands", function()
      local auto_refresh = require("jj.auto_refresh")
      local refresh_count = 0
      
      auto_refresh.register_command_hook(function(command, success, output)
        if success and command:match("abandon") then
          refresh_count = refresh_count + 1
        end
      end)
      
      -- Mock abandon command execution
      mock_jj_command_execution("abandon abc123", true, "Abandoned commit abc123")
      
      assert.equals(1, refresh_count)
    end)

    it("should trigger auto-refresh for new commands", function()
      local auto_refresh = require("jj.auto_refresh")
      local refresh_count = 0
      
      auto_refresh.register_command_hook(function(command, success, output)
        if success and command:match("^new") then
          refresh_count = refresh_count + 1
        end
      end)
      
      -- Mock new command execution
      mock_jj_command_execution("new", true, "Working copy now at: xyz789")
      
      assert.equals(1, refresh_count)
    end)

    it("should trigger auto-refresh for bookmark commands", function()
      local auto_refresh = require("jj.auto_refresh")
      local refresh_count = 0
      
      auto_refresh.register_command_hook(function(command, success, output)
        if success and command:match("bookmark") then
          refresh_count = refresh_count + 1
        end
      end)
      
      -- Mock bookmark command execution
      mock_jj_command_execution("bookmark create feature-x", true, "Created bookmark feature-x")
      
      assert.equals(1, refresh_count)
    end)
  end)

  describe("error handling and edge cases", function()
    it("should handle auto-refresh failures gracefully", function()
      local auto_refresh = require("jj.auto_refresh")
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      local window_mock = {
        is_log_window_open = function() return true end,
        get_current_buffer = function() return buffer_id end,
        refresh_log_content = function(new_lines)
          return false -- Simulate refresh failure
        end
      }
      
      local success = auto_refresh.auto_refresh_after_command("commit -m 'test'", true, "success", window_mock)
      
      assert.is_false(success)
      
      -- Should notify user about refresh failure
      local found_error_message = false
      for _, notification in ipairs(mock_notifications) do
        if notification.level == vim.log.levels.ERROR then
          found_error_message = true
          break
        end
      end
      assert.is_true(found_error_message)
    end)

    it("should not trigger auto-refresh for read-only commands", function()
      local auto_refresh = require("jj.auto_refresh")
      local refresh_triggered = false
      
      auto_refresh.register_command_hook(function(command, success, output)
        if auto_refresh.should_trigger_refresh(command, success) then
          refresh_triggered = true
        end
      end)
      
      -- Mock read-only commands
      mock_jj_command_execution("log", true, "log output")
      mock_jj_command_execution("show abc123", true, "commit details")
      mock_jj_command_execution("status", true, "status output")
      
      assert.is_false(refresh_triggered)
    end)

    it("should handle rapid consecutive commands properly", function()
      local auto_refresh = require("jj.auto_refresh")
      local refresh_count = 0
      
      auto_refresh.register_command_hook(function(command, success, output)
        if success then
          refresh_count = refresh_count + 1
        end
      end)
      
      -- Mock rapid command execution
      mock_jj_command_execution("commit -m 'commit 1'", true, "success")
      mock_jj_command_execution("commit -m 'commit 2'", true, "success")
      mock_jj_command_execution("commit -m 'commit 3'", true, "success")
      
      assert.equals(3, refresh_count)
    end)
  end)
end)