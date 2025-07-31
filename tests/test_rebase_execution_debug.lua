-- Debug test to understand why rebase commands aren't executing
describe("rebase execution debugging", function()
  local selection_integration
  local command_context
  local mock_executor
  
  before_each(function()
    -- Reset modules
    package.loaded["jj.selection_integration"] = nil
    package.loaded["jj.command_context"] = nil
    package.loaded["jj.log.executor"] = nil
    
    -- Track all commands that would be executed
    local executed_commands = {}
    mock_executor = {
      execute_jj_command = function(cmd)
        table.insert(executed_commands, cmd)
        return { 
          success = true, 
          output = "Successfully executed: " .. cmd
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
      -- Capture notifications for debugging
      _G.vim.last_notification = {msg = msg, level = level}
    end
    
    -- Set up package.preload to inject mocks
    package.preload["jj.log.executor"] = function()
      return mock_executor
    end
    
    selection_integration = require("jj.selection_integration")
    command_context = require("jj.command_context")
  end)
  
  after_each(function()
    mock_executor.clear_executed_commands()
    package.preload["jj.log.executor"] = nil
  end)

  describe("command building", function()
    it("should build rebase command string correctly", function()
      local command_def = {
        quick_action = {
          cmd = "rebase",
          args = {"-d", "{target}"}
        }
      }
      
      local selections = {
        target = "abc123def"
      }
      
      local context = {}
      
      local success, command_string = selection_integration._build_command_string(command_def, selections, context)
      
      assert.is_true(success)
      assert.are.equal("rebase -d abc123def", command_string)
    end)
    
    it("should substitute selections in phase 1", function()
      local args = {"-d", "{target}"}
      local selections = {
        target = "selected_commit_123"
      }
      
      local result = command_context.substitute_selections(args, selections)
      
      assert.are.same({"-d", "selected_commit_123"}, result)
    end)
    
    it("should handle unified substitution in phase 2", function()
      local args = {"-d", "selected_commit_123"}  -- Already substituted from phase 1
      local context = {
        commit_id = "current_456"
      }
      
      local result = command_context.substitute_final_placeholders(args, context)
      
      assert.are.same({"-d", "selected_commit_123"}, result)
    end)
  end)

  describe("selection workflow simulation", function()
    it("should simulate complete workflow execution", function()
      -- Simulate what happens when user completes selection
      local command_def = {
        quick_action = {
          cmd = "rebase",
          args = {"-d", "{target}"}
        }
      }
      
      local selections = {
        target = "workflow_target_789"
      }
      
      local context = {
        selections = selections
      }
      
      -- Test the command building process
      local success, command_string = selection_integration._build_command_string(command_def, selections, context)
      
      assert.is_true(success, "Command building failed")
      assert.are.equal("rebase -d workflow_target_789", command_string)
      
      -- Simulate executor call
      local result = mock_executor.execute_jj_command(command_string)
      
      assert.is_true(result.success)
      assert.matches("workflow_target_789", result.output)
      
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      assert.are.equal("rebase -d workflow_target_789", executed[1])
    end)
  end)

  describe("notification debugging", function()
    it("should show what notification would be displayed", function()
      local command_string = "rebase -d debug_commit_456"
      local result = {
        success = true,
        output = "Rebased successfully"
      }
      
      -- Simulate the current notification logic
      if result.success then
        vim.notify("Command executed successfully", vim.log.levels.INFO)
      else
        vim.notify("Command failed: " .. (result.error or "Unknown error"), vim.log.levels.ERROR)
      end
      
      -- Check what was notified
      assert.is_not_nil(_G.vim.last_notification)
      assert.are.equal("Command executed successfully", _G.vim.last_notification.msg)
      assert.are.equal(vim.log.levels.INFO, _G.vim.last_notification.level)
      
      -- This shows the problem - the notification doesn't include the command details
      assert.is_not.matches("rebase", _G.vim.last_notification.msg)
      assert.is_not.matches("debug_commit_456", _G.vim.last_notification.msg)
    end)
    
    it("should demonstrate improved notification with command details", function()
      local command_string = "rebase -d improved_commit_789"
      local result = {
        success = true,
        output = "Rebased successfully"
      }
      
      -- Simulate improved notification logic
      if result.success then
        vim.notify("Successfully executed: jj " .. command_string, vim.log.levels.INFO)
      else
        vim.notify("Command failed: jj " .. command_string .. " - " .. (result.error or "Unknown error"), vim.log.levels.ERROR)
      end
      
      -- Check improved notification
      assert.is_not_nil(_G.vim.last_notification)
      assert.matches("Successfully executed: jj rebase %-d improved_commit_789", _G.vim.last_notification.msg)
      assert.are.equal(vim.log.levels.INFO, _G.vim.last_notification.level)
    end)
  end)
end)