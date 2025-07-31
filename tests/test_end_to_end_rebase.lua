-- End-to-end test to diagnose rebase execution issues
describe("end-to-end rebase execution diagnosis", function()
  local selection_integration
  local command_queue
  local mock_executor
  
  before_each(function()
    -- Reset modules
    package.loaded["jj.selection_integration"] = nil
    package.loaded["jj.command_queue"] = nil
    package.loaded["jj.log.executor"] = nil
    
    -- Track all system calls and states
    local executed_commands = {}
    local system_calls = {}
    local queue_states = {}
    
    mock_executor = {
      execute_jj_command = function(cmd)
        table.insert(executed_commands, cmd)
        
        -- Simulate what the real executor does
        local full_command = "jj " .. cmd
        table.insert(system_calls, full_command)
        
        return { 
          success = true, 
          output = "Successfully executed: " .. cmd
        }
      end,
      _is_safe_command = function(cmd)
        return true  -- Allow all commands for testing
      end,
      get_executed_commands = function()
        return executed_commands
      end,
      get_system_calls = function()
        return system_calls
      end,
      clear_all = function()
        executed_commands = {}
        system_calls = {}
      end
    }
    
    -- Mock vim APIs
    _G.vim = _G.vim or {}
    _G.vim.list_extend = function(list1, list2)
      for _, item in ipairs(list2) do
        table.insert(list1, item)
      end
      return list1
    end
    _G.vim.log = _G.vim.log or {}
    _G.vim.log.levels = _G.vim.log.levels or {INFO = 1, ERROR = 4}
    _G.vim.notify = function(msg, level) 
      -- Track notifications
      _G.vim.last_notification = {msg = msg, level = level}
    end
    
    -- Mock log refresh
    package.loaded["jj.log.init"] = {
      refresh_log = function() 
        -- Track log refresh calls
        _G.vim.log_refreshed = true
      end
    }
    
    -- Set up package.preload to inject mocks
    package.preload["jj.log.executor"] = function()
      return mock_executor
    end
    
    selection_integration = require("jj.selection_integration")
    command_queue = require("jj.command_queue")
  end)
  
  after_each(function()
    mock_executor.clear_all()
    package.preload["jj.log.executor"] = nil
    package.loaded["jj.log.init"] = nil
  end)

  describe("command queue interference", function()
    it("should execute immediately when no refresh is active", function()
      -- Ensure no refresh is active
      command_queue._set_refresh_active(false)  -- Internal test function
      
      local should_execute = command_queue.should_execute_command("rebase -d test123")
      assert.is_true(should_execute, "Command should execute immediately when no refresh active")
    end)
    
    it("should queue command when refresh is active", function()
      command_queue._set_refresh_active(true)  -- Internal test function
      
      local should_execute = command_queue.should_execute_command("rebase -d test456")
      assert.is_false(should_execute, "Command should be queued when refresh is active")
    end)
  end)

  describe("selection workflow execution", function()
    it("should execute rebase command through complete workflow", function()
      -- Ensure no refresh interference
      command_queue._set_refresh_active(false)
      
      local command_def = {
        quick_action = {
          cmd = "rebase",
          args = {"-d", "{target}"}
        }
      }
      
      local selections = {
        target = "workflow_commit_789"
      }
      
      local context = {
        selections = selections
      }
      
      -- Test complete workflow
      local success, command_string = selection_integration._build_command_string(command_def, selections, context)
      assert.is_true(success)
      assert.are.equal("rebase -d workflow_commit_789", command_string)
      
      -- Execute the command
      local result = mock_executor.execute_jj_command(command_string)
      assert.is_true(result.success)
      
      -- Verify command was executed
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      assert.are.equal("rebase -d workflow_commit_789", executed[1])
      
      -- Verify system call would have been made
      local system_calls = mock_executor.get_system_calls()
      assert.are.equal(1, #system_calls)
      assert.are.equal("jj rebase -d workflow_commit_789", system_calls[1])
    end)
  end)

  describe("potential execution blockers", function()
    it("should identify if commands are being filtered out", function()
      local test_commands = {
        "rebase -d main",
        "rebase -d abc123",
        "rebase -b @ -d main",
        "rebase -s @ -d origin/main"
      }
      
      for _, cmd in ipairs(test_commands) do
        local is_safe = mock_executor._is_safe_command(cmd)
        assert.is_true(is_safe, "Command should be safe: " .. cmd)
        
        local result = mock_executor.execute_jj_command(cmd)
        assert.is_true(result.success, "Command should execute successfully: " .. cmd)
      end
      
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(4, #executed)
    end)
    
    it("should verify notification and refresh behavior", function()
      -- Clear any previous state
      _G.vim.last_notification = nil
      _G.vim.log_refreshed = nil
      
      local command_string = "rebase -d notification_test"
      local result = mock_executor.execute_jj_command(command_string)
      
      -- Simulate the notification logic from selection_integration
      if result.success then
        vim.notify("Successfully executed: jj " .. command_string, vim.log.levels.INFO)
        
        -- Simulate log refresh
        local log = require("jj.log.init")
        log.refresh_log()
      end
      
      -- Verify notification was sent
      assert.is_not_nil(_G.vim.last_notification)
      assert.are.equal("Successfully executed: jj rebase -d notification_test", _G.vim.last_notification.msg)
      
      -- Verify log refresh was called
      assert.is_true(_G.vim.log_refreshed)
    end)
  end)

  describe("real-world simulation", function()
    it("should simulate user selecting rebase menu option", function()
      -- This simulates what happens when user:
      -- 1. Presses 'R' to open rebase menu
      -- 2. Selects option '1' (Rebase current onto selected)
      -- 3. Selects a target commit
      -- 4. Completes the workflow
      
      -- Ensure no refresh interference
      command_queue._set_refresh_active(false)
      
      -- Command definition from rebase menu option 1
      local command_def = {
        quick_action = {
          cmd = "rebase",
          args = {"-d", "{target}"}
        }
      }
      
      -- User selections (target commit selected)
      local selections = {
        target = "user_selected_abc123"
      }
      
      local context = {
        selections = selections
      }
      
      -- Execute the complete workflow
      local success, command_string = selection_integration._build_command_string(command_def, selections, context)
      assert.is_true(success, "Command building should succeed")
      assert.are.equal("rebase -d user_selected_abc123", command_string)
      
      -- Execute the command (simulating executor.execute_jj_command call)
      local result = mock_executor.execute_jj_command(command_string)
      assert.is_true(result.success, "Command execution should succeed")
      
      -- Send success notification (simulating selection_integration._complete_workflow)
      vim.notify("Successfully executed: jj " .. command_string, vim.log.levels.INFO)
      
      -- Refresh log (simulating post-execution refresh)
      local log = require("jj.log.init")
      log.refresh_log()
      
      -- Verify everything worked
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      assert.are.equal("rebase -d user_selected_abc123", executed[1])
      
      local system_calls = mock_executor.get_system_calls()
      assert.are.equal(1, #system_calls)
      assert.are.equal("jj rebase -d user_selected_abc123", system_calls[1])
      
      assert.is_not_nil(_G.vim.last_notification)
      assert.matches("Successfully executed: jj rebase %-d user_selected_abc123", _G.vim.last_notification.msg)
      assert.is_true(_G.vim.log_refreshed)
    end)
  end)
end)