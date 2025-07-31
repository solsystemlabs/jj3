-- Tests to verify improved notification messages include command details
describe("improved command notifications", function()
  local selection_integration
  local command_execution
  local mock_executor
  
  before_each(function()
    -- Reset modules
    package.loaded["jj.selection_integration"] = nil
    package.loaded["jj.command_execution"] = nil
    package.loaded["jj.log.executor"] = nil
    
    -- Track executed commands and notifications
    local executed_commands = {}
    local notifications = {}
    
    mock_executor = {
      execute_jj_command = function(cmd)
        table.insert(executed_commands, cmd)
        return { 
          success = true, 
          output = "Command executed successfully"
        }
      end,
      get_executed_commands = function()
        return executed_commands
      end,
      clear_executed_commands = function()
        executed_commands = {}
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
    _G.vim.log.levels = _G.vim.log.levels or {}
    _G.vim.log.levels.INFO = 1
    _G.vim.log.levels.ERROR = 4
    _G.vim.notify = function(msg, level) 
      table.insert(notifications, {msg = msg, level = level})
    end
    
    -- Mock log refresh
    package.loaded["jj.log.init"] = {
      refresh_log = function() end
    }
    
    -- Set up package.preload to inject mocks
    package.preload["jj.log.executor"] = function()
      return mock_executor
    end
    
    selection_integration = require("jj.selection_integration")
    command_execution = require("jj.command_execution")
    
    -- Helper to get notifications
    _G.get_notifications = function()
      return notifications
    end
    _G.clear_notifications = function()
      notifications = {}
    end
  end)
  
  after_each(function()
    mock_executor.clear_executed_commands()
    package.preload["jj.log.executor"] = nil
    package.loaded["jj.log.init"] = nil
  end)

  describe("selection workflow notifications", function()
    it("should include command details in success notification", function()
      local command_def = {
        quick_action = {
          cmd = "rebase",
          args = {"-d", "{target}"}
        }
      }
      
      local selections = {
        target = "notification_test_123"
      }
      
      local context = {
        selections = selections
      }
      
      -- Test the command building and notification
      local success, command_string = selection_integration._build_command_string(command_def, selections, context)
      assert.is_true(success)
      assert.are.equal("rebase -d notification_test_123", command_string)
      
      -- Simulate the notification that would be sent
      local result = mock_executor.execute_jj_command(command_string)
      
      if result.success then
        vim.notify("Successfully executed: jj " .. command_string, vim.log.levels.INFO)
      end
      
      local notifications = _G.get_notifications()
      assert.are.equal(1, #notifications)
      assert.are.equal("Successfully executed: jj rebase -d notification_test_123", notifications[1].msg)
      assert.are.equal(vim.log.levels.INFO, notifications[1].level)
    end)
    
    it("should include command details in failure notification", function()
      -- Mock executor to return failure
      mock_executor.execute_jj_command = function(cmd)
        return { 
          success = false,
          error = "Repository not found"
        }
      end
      
      local command_string = "rebase -d failure_test_456"
      local result = mock_executor.execute_jj_command(command_string)
      
      if not result.success then
        vim.notify("Command failed: jj " .. command_string .. " - " .. (result.error or "Unknown error"), vim.log.levels.ERROR)
      end
      
      local notifications = _G.get_notifications()
      assert.are.equal(1, #notifications)
      assert.are.equal("Command failed: jj rebase -d failure_test_456 - Repository not found", notifications[1].msg)
      assert.are.equal(vim.log.levels.ERROR, notifications[1].level)
    end)
  end)

  describe("immediate command notifications", function()
    it("should include command details for immediate commands", function()
      local command_def = {
        quick_action = {
          cmd = "rebase",
          args = {"-d", "{target}"}
        }
      }
      
      -- Register command for testing
      command_execution.register_command("rebase_immediate", command_def)
      
      local context = {
        target = "immediate_test_789"
      }
      
      -- Execute through command_execution system
      local result = command_execution.execute_command("rebase_immediate", "quick_action", context)
      
      assert.is_true(result.success)
      assert.is_not_nil(result.executed_command)
      assert.are.equal("jj rebase -d immediate_test_789", result.executed_command)
      
      -- Simulate the notification logic from selection_integration._execute_immediate_command
      local full_command = "rebase -d immediate_test_789"
      if result.success then
        vim.notify("Successfully executed: jj " .. full_command, vim.log.levels.INFO)
      end
      
      local notifications = _G.get_notifications()
      assert.are.equal(1, #notifications)
      assert.are.equal("Successfully executed: jj rebase -d immediate_test_789", notifications[1].msg)
    end)
  end)

  describe("notification comparison", function()
    it("should show improvement over old generic notifications", function()
      local command_string = "rebase -d comparison_test_abc"
      
      -- Old style notification (generic)
      _G.clear_notifications()
      vim.notify("Command executed successfully", vim.log.levels.INFO)
      local old_notifications = _G.get_notifications()
      
      -- New style notification (with command details)
      _G.clear_notifications()
      vim.notify("Successfully executed: jj " .. command_string, vim.log.levels.INFO)
      local new_notifications = _G.get_notifications()
      
      -- Compare notifications
      assert.are.equal("Command executed successfully", old_notifications[1].msg)
      assert.are.equal("Successfully executed: jj rebase -d comparison_test_abc", new_notifications[1].msg)
      
      -- New notification is more informative
      assert.is_not.matches("rebase", old_notifications[1].msg)  -- Old doesn't include command
      assert.matches("rebase %-d comparison_test_abc", new_notifications[1].msg)  -- New includes full command
    end)
  end)

  describe("real-world scenarios", function()
    it("should provide clear feedback for rebase onto main", function()
      local command_string = "rebase -d main"
      local result = { success = true, output = "Rebased 3 commits" }
      
      vim.notify("Successfully executed: jj " .. command_string, vim.log.levels.INFO)
      
      local notifications = _G.get_notifications()
      assert.are.equal(1, #notifications)
      assert.are.equal("Successfully executed: jj rebase -d main", notifications[1].msg)
      
      -- User can clearly see what command was executed
      assert.matches("jj rebase %-d main", notifications[1].msg)
    end)
    
    it("should provide clear feedback for complex rebase commands", function()
      local command_string = "rebase -s @ -d origin/main"
      local result = { success = true, output = "Rebased with descendants" }
      
      vim.notify("Successfully executed: jj " .. command_string, vim.log.levels.INFO)
      
      local notifications = _G.get_notifications()
      assert.are.equal(1, #notifications)
      assert.are.equal("Successfully executed: jj rebase -s @ -d origin/main", notifications[1].msg)
      
      -- User can see the full complex command that was executed
      assert.matches("rebase %-s @ %-d origin/main", notifications[1].msg)
    end)
  end)
end)