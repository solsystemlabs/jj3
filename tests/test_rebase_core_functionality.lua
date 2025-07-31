-- Core functionality tests for rebase command with realistic scenarios
describe("rebase core functionality", function()
  local command_execution
  local mock_executor
  
  before_each(function()
    -- Reset modules
    package.loaded["jj.command_execution"] = nil
    package.loaded["jj.log.executor"] = nil
    
    -- Track executed commands
    local executed_commands = {}
    mock_executor = {
      execute_jj_command = function(cmd)
        table.insert(executed_commands, cmd)
        return { 
          success = true, 
          output = "Successfully rebased"
        }
      end,
      get_executed_commands = function()
        return executed_commands
      end,
      clear_executed_commands = function()
        executed_commands = {}
      end
    }
    
    -- Mock minimal vim APIs
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
  end)
  
  after_each(function()
    mock_executor.clear_executed_commands()
    package.preload["jj.log.executor"] = nil
  end)

  describe("core rebase substitution", function()
    it("should substitute {target} with real commit ID", function()
      -- Register a simple rebase command
      local rebase_def = {
        quick_action = {
          cmd = "rebase",
          args = {"-d", "{target}"},
          description = "Rebase onto target"
        }
      }
      command_execution.register_command("rebase", rebase_def)
      
      local context = {
        target = "abc123def456",
        commit_id = "current789"
      }
      
      local result = command_execution.execute_command("rebase", "quick_action", context)
      
      assert.is_true(result.success)
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      assert.are.equal("rebase -d abc123def456", executed[1])
    end)
    
    it("should handle the exact failing scenario from bug report", function()
      -- This is the exact command that was failing
      local rebase_def = {
        quick_action = {
          cmd = "rebase",
          args = {"-d", "{target}"},
          description = "Rebase current change onto selected commit"
        }
      }
      command_execution.register_command("rebase", rebase_def)
      
      -- Simulate user selecting a target commit
      local context = {
        target = "xyz789abc",  -- This would come from selection
        commit_id = "current123"
      }
      
      local result = command_execution.execute_command("rebase", "quick_action", context)
      
      assert.is_true(result.success)
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      
      -- The critical assertion: should NOT contain literal {target}
      assert.is_not.matches("{target}", executed[1])
      -- Should contain the actual target commit
      assert.matches("xyz789abc", executed[1])
      -- Should be the correct jj command
      assert.are.equal("rebase -d xyz789abc", executed[1])
    end)
    
    it("should handle menu option context", function()
      -- Register rebase command first (needed for menu option)
      local rebase_def = {
        quick_action = {
          cmd = "rebase",
          args = {"-d", "{target}"},
          description = "Rebase onto target"
        }
      }
      command_execution.register_command("rebase", rebase_def)
      
      local context = {
        cmd = "rebase",
        args = {"-d", "{target}"},
        target = "menu_selected_commit"
      }
      
      local result = command_execution.execute_command("rebase", "menu_option", context)
      
      assert.is_true(result.success)
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      assert.are.equal("rebase -d menu_selected_commit", executed[1])
    end)
    
    it("should fallback to commit_id when target missing", function()
      local rebase_def = {
        quick_action = {
          cmd = "rebase",
          args = {"-d", "{target}"},
          description = "Rebase onto target"
        }
      }
      command_execution.register_command("rebase", rebase_def)
      
      local context = {
        commit_id = "fallback456"
        -- no target provided
      }
      
      local result = command_execution.execute_command("rebase", "quick_action", context)
      
      assert.is_true(result.success)
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      assert.are.equal("rebase -d fallback456", executed[1])
    end)
    
    it("should use @ as final fallback", function()
      local rebase_def = {
        quick_action = {
          cmd = "rebase",
          args = {"-d", "{target}"},
          description = "Rebase onto target"
        }
      }
      command_execution.register_command("rebase", rebase_def)
      
      local context = {}  -- completely empty
      
      local result = command_execution.execute_command("rebase", "quick_action", context)
      
      assert.is_true(result.success)
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      assert.are.equal("rebase -d @", executed[1])
    end)
  end)

  describe("realistic commit ID patterns", function()
    it("should handle short commit hashes", function()
      local args = {"-d", "{target}"}
      local context = {target = "abc123"}
      
      local result = command_execution.substitute_parameters(args, context)
      
      assert.are.same({"-d", "abc123"}, result)
    end)
    
    it("should handle full commit hashes", function()
      local args = {"-d", "{target}"}
      local context = {target = "abc123def456789abcdef0123456789abcdef01234"}
      
      local result = command_execution.substitute_parameters(args, context)
      
      assert.are.same({"-d", "abc123def456789abcdef0123456789abcdef01234"}, result)
    end)
    
    it("should handle special jj references", function()
      local special_refs = {"@", "@-", "@+", "main", "origin/main", "HEAD"}
      
      for _, ref in ipairs(special_refs) do
        local args = {"-d", "{target}"}
        local context = {target = ref}
        
        local result = command_execution.substitute_parameters(args, context)
        
        assert.are.same({"-d", ref}, result)
      end
    end)
    
    it("should handle commit IDs with mixed case", function()
      local args = {"-d", "{target}"}
      local context = {target = "AbC123DeF"}
      
      local result = command_execution.substitute_parameters(args, context)
      
      assert.are.same({"-d", "AbC123DeF"}, result)
    end)
  end)

  describe("complex rebase scenarios", function()
    it("should handle rebase with multiple flags", function()
      local rebase_def = {
        quick_action = {
          cmd = "rebase",
          args = {"-b", "@", "-d", "{target}"},
          description = "Rebase branch onto target"
        }
      }
      command_execution.register_command("rebase_branch", rebase_def)
      
      local context = {
        target = "branch_target_123",
        commit_id = "current_456"
      }
      
      local result = command_execution.execute_command("rebase_branch", "quick_action", context)
      
      assert.is_true(result.success)
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      assert.are.equal("rebase -b @ -d branch_target_123", executed[1])
    end)
    
    it("should handle rebase with descendants", function()
      local rebase_def = {
        quick_action = {
          cmd = "rebase",
          args = {"-s", "{commit_id}", "-d", "{target}"},
          description = "Rebase with descendants"
        }
      }
      command_execution.register_command("rebase_descendants", rebase_def)
      
      local context = {
        target = "dest_target_789",
        commit_id = "source_123"
      }
      
      local result = command_execution.execute_command("rebase_descendants", "quick_action", context)
      
      assert.is_true(result.success)
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      assert.are.equal("rebase -s source_123 -d dest_target_789", executed[1])
    end)
  end)

  describe("error prevention", function()
    it("should never pass literal {target} to jj command", function()
      local test_cases = {
        {target = "real_commit", expected = "real_commit"},
        {target = "main", expected = "main"},
        {target = "@", expected = "@"},
        {commit_id = "fallback", expected = "fallback"},  -- no target
        {expected = "@"}  -- no target or commit_id
      }
      
      for i, case in ipairs(test_cases) do
        local args = {"-d", "{target}"}
        local result = command_execution.substitute_parameters(args, case)
        
        -- Critical: should never contain {target}
        for _, arg in ipairs(result) do
          assert.is_not.equal("{target}", arg, "Test case " .. i .. " failed")
        end
        
        -- Should contain expected value
        assert.are.equal(case.expected, result[2], "Test case " .. i .. " wrong substitution")
      end
    end)
    
    it("should validate the original error scenario is fixed", function()
      -- This recreates the exact error scenario:
      -- Command failed: jj rebase -d {target}
      
      local args = {"rebase", "-d", "{target}"}
      local context = {target = "selected_commit_abc123"}
      
      local result = command_execution.substitute_parameters(args, context)
      
      -- Build the command that would be executed
      local command_string = table.concat(result, " ")
      
      -- Should NOT contain literal {target} (which caused the original error)
      assert.is_not.matches("{target}", command_string)
      
      -- Should be a valid jj command
      assert.are.equal("rebase -d selected_commit_abc123", command_string)
    end)
  end)
end)