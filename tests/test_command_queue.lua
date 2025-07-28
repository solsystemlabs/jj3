-- Tests for command queuing system during refresh operations
require("helpers.vim_mock")

-- Mock state tracking
local mock_notifications = {}
local mock_command_executions = {}
local mock_refresh_operations = {}

-- Mock vim.notify to capture notifications
vim.notify = function(message, level)
  table.insert(mock_notifications, {
    message = message,
    level = level or vim.log.levels.INFO,
    timestamp = os.time()
  })
end

-- Mock command execution tracking
local function track_command_execution(command, success, output)
  table.insert(mock_command_executions, {
    command = command,
    success = success,
    output = output,
    timestamp = os.time()
  })
end

-- Mock refresh operation tracking
local function track_refresh_operation(type, success)
  table.insert(mock_refresh_operations, {
    type = type, -- "start" or "complete"
    success = success,
    timestamp = os.time()
  })
end

describe("Command Queue System", function()
  local lfs = require('lfs')
  local original_cwd

  before_each(function()
    original_cwd = lfs.currentdir()
    
    -- Use existing test directory
    local test_repo = require("helpers.test_repository")
    lfs.chdir(test_repo.test_repo_path)
    
    -- Reset state
    mock_notifications = {}
    mock_command_executions = {}
    mock_refresh_operations = {}
  end)

  after_each(function()
    lfs.chdir(original_cwd)
    
    -- Clean up command queue state
    local ok, command_queue = pcall(require, "jj.command_queue")
    if ok then
      command_queue.reset()
    end
  end)

  describe("queue initialization and basic operations", function()
    it("should initialize empty command queue", function()
      local command_queue = require("jj.command_queue")
      
      assert.is_true(command_queue.is_empty())
      assert.equals(0, command_queue.get_queue_size())
      assert.is_false(command_queue.is_refresh_active())
    end)

    it("should track refresh state correctly", function()
      local command_queue = require("jj.command_queue")
      
      command_queue.set_refresh_active(true)
      assert.is_true(command_queue.is_refresh_active())
      
      command_queue.set_refresh_active(false)
      assert.is_false(command_queue.is_refresh_active())
    end)

    it("should queue commands when refresh is active", function()
      local command_queue = require("jj.command_queue")
      
      command_queue.set_refresh_active(true)
      
      local queued = command_queue.queue_command("commit -m 'test'", function() end)
      assert.is_true(queued)
      assert.is_false(command_queue.is_empty())
      assert.equals(1, command_queue.get_queue_size())
    end)

    it("should not queue commands when refresh is not active", function()
      local command_queue = require("jj.command_queue")
      
      command_queue.set_refresh_active(false)
      
      local queued = command_queue.queue_command("commit -m 'test'", function() end)
      assert.is_false(queued)
      assert.is_true(command_queue.is_empty())
      assert.equals(0, command_queue.get_queue_size())
    end)
  end)

  describe("command execution blocking", function()
    it("should block new commands during active refresh", function()
      local command_queue = require("jj.command_queue")
      
      -- Start refresh
      command_queue.set_refresh_active(true)
      
      -- Try to execute command
      local should_execute = command_queue.should_execute_command("commit -m 'test'")
      assert.is_false(should_execute)
      
      -- Command should be queued instead
      local queued = command_queue.queue_command("commit -m 'test'", function() end)
      assert.is_true(queued)
    end)

    it("should allow commands when refresh is not active", function()
      local command_queue = require("jj.command_queue")
      
      command_queue.set_refresh_active(false)
      
      local should_execute = command_queue.should_execute_command("commit -m 'test'")
      assert.is_true(should_execute)
    end)

    it("should provide user feedback when commands are queued", function()
      local command_queue = require("jj.command_queue")
      
      command_queue.set_refresh_active(true)
      
      command_queue.queue_command("commit -m 'test'", function() end)
      
      -- Should notify user about queued command
      assert.is_true(#mock_notifications > 0)
      
      local found_queue_message = false
      for _, notification in ipairs(mock_notifications) do
        if notification.message:find("queued") or notification.message:find("pending") then
          found_queue_message = true
          break
        end
      end
      assert.is_true(found_queue_message)
    end)
  end)

  describe("queue processing after refresh completion", function()
    it("should execute queued commands after refresh completes", function()
      local command_queue = require("jj.command_queue")
      local executed_commands = {}
      
      -- Start refresh and queue commands
      command_queue.set_refresh_active(true)
      
      command_queue.queue_command("commit -m 'test1'", function()
        table.insert(executed_commands, "commit -m 'test1'")
      end)
      
      command_queue.queue_command("new -m 'test2'", function()
        table.insert(executed_commands, "new -m 'test2'")
      end)
      
      assert.equals(2, command_queue.get_queue_size())
      
      -- Complete refresh and process queue
      command_queue.set_refresh_active(false)
      command_queue.process_queue()
      
      -- Commands should have been executed
      assert.equals(2, #executed_commands)
      assert.equals("commit -m 'test1'", executed_commands[1])
      assert.equals("new -m 'test2'", executed_commands[2])
      assert.is_true(command_queue.is_empty())
    end)

    it("should execute commands in FIFO order", function()
      local command_queue = require("jj.command_queue")
      local execution_order = {}
      
      command_queue.set_refresh_active(true)
      
      -- Queue multiple commands
      for i = 1, 5 do
        command_queue.queue_command("command" .. i, function()
          table.insert(execution_order, "command" .. i)
        end)
      end
      
      command_queue.set_refresh_active(false)
      command_queue.process_queue()
      
      -- Verify FIFO order
      for i = 1, 5 do
        assert.equals("command" .. i, execution_order[i])
      end
    end)

    it("should provide feedback during queue processing", function()
      local command_queue = require("jj.command_queue")
      
      command_queue.set_refresh_active(true)
      command_queue.queue_command("commit -m 'test'", function() end)
      
      command_queue.set_refresh_active(false)
      command_queue.process_queue()
      
      -- Should notify about queue processing
      local has_processing_message = false
      for _, notification in ipairs(mock_notifications) do
        if notification.message:find("Processing") or notification.message:find("Executing") then
          has_processing_message = true
          break
        end
      end
      assert.is_true(has_processing_message)
    end)
  end)

  describe("error handling and edge cases", function()
    it("should handle queue processing errors gracefully", function()
      local command_queue = require("jj.command_queue")
      local successful_executions = {}
      
      command_queue.set_refresh_active(true)
      
      -- Queue command that will succeed
      command_queue.queue_command("good_command", function()
        table.insert(successful_executions, "good_command")
      end)
      
      -- Queue command that will fail
      command_queue.queue_command("bad_command", function()
        error("Simulated command failure")
      end)
      
      -- Queue another command that should still execute
      command_queue.queue_command("another_good_command", function()
        table.insert(successful_executions, "another_good_command")
      end)
      
      command_queue.set_refresh_active(false)
      command_queue.process_queue()
      
      -- Good commands should have executed despite the error
      assert.equals(2, #successful_executions)
      assert.equals("good_command", successful_executions[1])
      assert.equals("another_good_command", successful_executions[2])
      
      -- Should have error notification
      local has_error_message = false
      for _, notification in ipairs(mock_notifications) do
        if notification.level == vim.log.levels.ERROR then
          has_error_message = true
          break
        end
      end
      assert.is_true(has_error_message)
    end)

    it("should handle rapid consecutive commands properly", function()
      local command_queue = require("jj.command_queue")
      local executed_count = 0
      
      command_queue.set_refresh_active(true)
      
      -- Queue many commands rapidly
      for i = 1, 10 do
        command_queue.queue_command("rapid_command_" .. i, function()
          executed_count = executed_count + 1
        end)
      end
      
      assert.equals(10, command_queue.get_queue_size())
      
      command_queue.set_refresh_active(false)
      command_queue.process_queue()
      
      assert.equals(10, executed_count)
      assert.is_true(command_queue.is_empty())
    end)

    it("should clear queue when reset", function()
      local command_queue = require("jj.command_queue")
      
      command_queue.set_refresh_active(true)
      command_queue.queue_command("test1", function() end)
      command_queue.queue_command("test2", function() end)
      
      assert.equals(2, command_queue.get_queue_size())
      
      command_queue.reset()
      
      assert.is_true(command_queue.is_empty())
      assert.equals(0, command_queue.get_queue_size())
      assert.is_false(command_queue.is_refresh_active())
    end)

    it("should handle empty queue processing", function()
      local command_queue = require("jj.command_queue")
      
      -- Process empty queue should not error
      local success = pcall(function()
        command_queue.process_queue()
      end)
      
      assert.is_true(success)
    end)
  end)

  describe("queue statistics and monitoring", function()
    it("should provide queue statistics", function()
      local command_queue = require("jj.command_queue")
      
      command_queue.set_refresh_active(true)
      
      for i = 1, 3 do
        command_queue.queue_command("test" .. i, function() end)
      end
      
      local stats = command_queue.get_queue_stats()
      assert.equals(3, stats.queue_size)
      assert.is_true(stats.is_refresh_active)
      assert.is_number(stats.oldest_command_age)
    end)

    it("should track command queue history", function()
      local command_queue = require("jj.command_queue")
      
      command_queue.set_refresh_active(true)
      command_queue.queue_command("historical_command", function() end)
      
      command_queue.set_refresh_active(false)
      command_queue.process_queue()
      
      local history = command_queue.get_queue_history()
      assert.is_table(history)
      assert.is_true(#history > 0)
    end)
  end)

  describe("integration with auto-refresh", function()
    it("should integrate with auto-refresh start/completion", function()
      local command_queue = require("jj.command_queue")
      
      -- Mock refresh start
      command_queue.on_refresh_start()
      assert.is_true(command_queue.is_refresh_active())
      
      -- Queue command during refresh
      local queued = command_queue.queue_command("test_command", function() end)
      assert.is_true(queued)
      
      -- Mock refresh completion
      command_queue.on_refresh_complete()
      assert.is_false(command_queue.is_refresh_active())
    end)

    it("should handle refresh failure scenarios", function()
      local command_queue = require("jj.command_queue")
      
      command_queue.on_refresh_start()
      command_queue.queue_command("test_command", function() end)
      
      -- Mock refresh failure
      command_queue.on_refresh_error("Refresh failed")
      
      -- Queue should still be processed even if refresh failed
      assert.is_false(command_queue.is_refresh_active())
      
      -- Should have error notification
      local has_error_message = false
      for _, notification in ipairs(mock_notifications) do
        if notification.level == vim.log.levels.ERROR and notification.message:find("Refresh failed") then
          has_error_message = true
          break
        end
      end
      assert.is_true(has_error_message)
    end)
  end)
end)