-- Tests to verify that rebase commands never generate revset syntax errors
describe("rebase syntax error prevention", function()
  local command_execution
  local command_context
  local mock_executor
  
  before_each(function()
    -- Reset modules
    package.loaded["jj.command_execution"] = nil
    package.loaded["jj.command_context"] = nil
    
    -- Track all commands that would be executed
    local executed_commands = {}
    mock_executor = {
      execute_jj_command = function(cmd)
        table.insert(executed_commands, cmd)
        -- Simulate jj's behavior - it would fail with revset syntax error if {target} is literal
        if cmd:match("{[^}]+}") then
          return { 
            success = false,
            error = "Failed to parse revset: Syntax error\nCaused by:  --> 1:1\n  |\n1 | " .. cmd:match("{[^}]+}") .. "\n  | ^---\n  |\n  = expected <strict_identifier> or <expression>"
          }
        end
        return { success = true, output = "Command executed successfully" }
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
    _G.vim.fn = _G.vim.fn or {}
    _G.vim.fn.input = function(prompt)
      return "test input"
    end
    
    -- Set up package.preload to inject mocks
    package.preload["jj.log.executor"] = function()
      return mock_executor
    end
    
    command_execution = require("jj.command_execution")
    command_context = require("jj.command_context")
  end)
  
  after_each(function()
    mock_executor.clear_executed_commands()
    package.preload["jj.log.executor"] = nil
    -- Clear command registry between tests
    if command_execution then
      command_execution._clear_registry = function()
        -- This is a test helper - normally not exposed
        local command_execution_module = require("jj.command_execution")
        -- Reset the internal registry (access via debug if needed)
        package.loaded["jj.command_execution"] = nil
      end
    end
  end)

  describe("revset syntax error prevention", function()
    it("should never pass {target} literally to jj (original bug)", function()
      local rebase_def = {
        quick_action = {
          cmd = "rebase",
          args = {"-d", "{target}"},
          description = "Rebase onto target"
        }
      }
      command_execution.register_command("rebase", rebase_def)
      
      local context = {
        target = "abc123def",
        commit_id = "current456"
      }
      
      local result = command_execution.execute_command("rebase", "quick_action", context)
      
      -- Should succeed (not fail with revset syntax error)
      assert.is_true(result.success, "Command failed: " .. tostring(result.error))
      
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      
      -- Verify no literal {target} in executed command
      local executed_cmd = executed[1]
      assert.is_not.matches("{target}", executed_cmd)
      assert.are.equal("rebase -d abc123def", executed_cmd)
    end)
    
    it("should prevent {change_id} literal passage", function()
      local args = {"-r", "{change_id}"}
      local context = {change_id = "change123"}
      
      local result = command_execution.substitute_parameters(args, context)
      
      -- Should not contain literal {change_id}
      for _, arg in ipairs(result) do
        assert.is_not.matches("{change_id}", arg)
      end
      assert.are.same({"-r", "change123"}, result)
    end)
    
    it("should prevent {commit_id} literal passage", function()
      local args = {"{commit_id}"}
      local context = {commit_id = "commit456"}
      
      local result = command_execution.substitute_parameters(args, context)
      
      -- Should not contain literal {commit_id}
      for _, arg in ipairs(result) do
        assert.is_not.matches("{commit_id}", arg)
      end
      assert.are.same({"commit456"}, result)
    end)
    
    it("should prevent any unsubstituted variable from reaching jj", function()
      local variables = {"{target}", "{commit_id}", "{change_id}", "{user_input}"}
      
      for _, var in ipairs(variables) do
        local args = {"-d", var}
        local context = {
          target = "target123",
          commit_id = "commit456", 
          change_id = "change789"
        }
        
        local result = command_execution.substitute_parameters(args, context)
        
        -- Verify no literal variable remains
        for _, arg in ipairs(result) do
          assert.is_not.equal(var, arg, "Variable " .. var .. " was not substituted")
        end
      end
    end)
  end)

  describe("command_context prevention", function()
    it("should prevent variables through command_context system", function()
      local args = {"rebase", "-d", "{target}", "-s", "{commit_id}"}
      local context = {
        target = "context_target_789",
        commit_id = "context_commit_123"
      }
      
      local result = command_context.substitute_final_placeholders(args, context)
      
      -- Verify no literal variables remain
      for _, arg in ipairs(result) do
        assert.is_not.matches("{[^}]+}", arg)
      end
      
      assert.are.same({"rebase", "-d", "context_target_789", "-s", "context_commit_123"}, result)
    end)
  end)

  describe("error scenario simulation", function()
    it("should simulate the exact error that was reported", function()
      -- This test simulates what would happen if the bug still existed
      local rebase_def = {
        quick_action = {
          cmd = "rebase",
          args = {"-d", "{target}"},
          description = "Rebase onto target"
        }
      }
      command_execution.register_command("rebase_error_sim", rebase_def)
      
      local context = {
        target = "selected_commit_abc123"
      }
      
      local result = command_execution.execute_command("rebase_error_sim", "quick_action", context)
      
      -- Should succeed (the bug is fixed)
      assert.is_true(result.success)
      
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      
      -- The executed command should be valid jj syntax
      local executed_cmd = executed[1]
      assert.are.equal("rebase -d selected_commit_abc123", executed_cmd)
      
      -- Verify it doesn't match the error pattern that was reported
      assert.is_not.matches("rebase %-d {target}", executed_cmd)
    end)
    
    it("should demonstrate the fix across all execution paths", function()
      local test_cases = {
        {
          name = "direct substitution",
          test = function()
            local args = {"-d", "{target}"}
            local context = {target = "direct123"}
            return command_execution.substitute_parameters(args, context)
          end,
          expected = {"-d", "direct123"}
        },
        {
          name = "command_context substitution", 
          test = function()
            local args = {"-d", "{target}"}
            local context = {target = "context456"}
            return command_context.substitute_final_placeholders(args, context)
          end,
          expected = {"-d", "context456"}
        }
      }
      
      for _, case in ipairs(test_cases) do
        local result = case.test()
        
        -- Verify no literal variables
        for _, arg in ipairs(result) do
          assert.is_not.matches("{[^}]+}", arg, case.name .. " failed - literal variable found")
        end
        
        -- Verify expected result
        assert.are.same(case.expected, result, case.name .. " failed - incorrect substitution")
      end
    end)
  end)

  describe("comprehensive validation", function()
    it("should validate all rebase command variations work", function()
      local rebase_variations = {
        {args = {"-d", "{target}"}, context = {target = "basic123"}, expected = "rebase -d basic123"},
        {args = {"-b", "@", "-d", "{target}"}, context = {target = "branch456"}, expected = "rebase -b @ -d branch456"},
        {args = {"-s", "{commit_id}", "-d", "{target}"}, context = {commit_id = "source789", target = "dest012"}, expected = "rebase -s source789 -d dest012"},
      }
      
      for i, variation in ipairs(rebase_variations) do
        mock_executor.clear_executed_commands()
        
        local rebase_def = {
          quick_action = {
            cmd = "rebase",
            args = variation.args,
            description = "Test rebase " .. i
          }
        }
        command_execution.register_command("rebase_test_" .. i, rebase_def)
        
        local result = command_execution.execute_command("rebase_test_" .. i, "quick_action", variation.context)
        
        assert.is_true(result.success, "Variation " .. i .. " failed")
        
        local executed = mock_executor.get_executed_commands()
        assert.are.equal(1, #executed)
        
        local executed_cmd = executed[1]
        assert.is_not.matches("{[^}]+}", executed_cmd, "Variation " .. i .. " has unsubstituted variable")
        assert.are.equal(variation.expected, executed_cmd, "Variation " .. i .. " incorrect command")
      end
    end)
  end)
end)