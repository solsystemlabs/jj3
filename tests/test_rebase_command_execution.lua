-- Tests for rebase command execution with proper variable substitution
describe("rebase command execution", function()
  local command_execution
  local default_commands
  local selection_integration
  local command_context
  local mock_executor
  
  before_each(function()
    -- Reset modules
    package.loaded["jj.command_execution"] = nil
    package.loaded["jj.default_commands"] = nil
    package.loaded["jj.selection_integration"] = nil
    package.loaded["jj.command_context"] = nil
    package.loaded["jj.log.executor"] = nil
    
    -- Mock executor to capture executed commands
    local executed_commands = {}
    mock_executor = {
      execute_jj_command = function(cmd)
        table.insert(executed_commands, cmd)
        return { success = true, output = "Rebase successful" }
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
      return "test commit message"
    end
    _G.vim.api = _G.vim.api or {}
    _G.vim.api.nvim_get_current_line = function()
      return "@ abc123 Test commit description"
    end
    _G.vim.log = _G.vim.log or {}
    _G.vim.log.levels = _G.vim.log.levels or {}
    _G.vim.log.levels.INFO = 1
    _G.vim.log.levels.ERROR = 4
    _G.vim.notify = function(msg, level) 
      -- Mock notification
    end
    
    -- Set up package.preload to inject mocks
    package.preload["jj.log.executor"] = function()
      return mock_executor
    end
    
    command_execution = require("jj.command_execution")
    default_commands = require("jj.default_commands")
    selection_integration = require("jj.selection_integration")
    command_context = require("jj.command_context")
  end)
  
  after_each(function()
    mock_executor.clear_executed_commands()
    package.preload["jj.log.executor"] = nil
  end)

  describe("command_execution rebase", function()
    it("should substitute {target} in rebase command", function()
      -- Register rebase command
      local rebase_def = {
        quick_action = {
          cmd = "rebase",
          args = {"-d", "{target}"},
          description = "Rebase onto target"
        }
      }
      command_execution.register_command("rebase", rebase_def)
      
      local context = {
        target = "xyz789",
        commit_id = "abc123"
      }
      
      local result = command_execution.execute_command("rebase", "quick_action", context)
      
      assert.is_true(result.success)
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      assert.are.equal("rebase -d xyz789", executed[1])
    end)
    
    it("should fallback to commit_id when target is missing", function()
      local rebase_def = {
        quick_action = {
          cmd = "rebase",
          args = {"-d", "{target}"},
          description = "Rebase onto target"
        }
      }
      command_execution.register_command("rebase", rebase_def)
      
      local context = {
        commit_id = "fallback123"
        -- no target provided
      }
      
      local result = command_execution.execute_command("rebase", "quick_action", context)
      
      assert.is_true(result.success)
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      assert.are.equal("rebase -d fallback123", executed[1])
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
      
      local context = {}  -- empty context
      
      local result = command_execution.execute_command("rebase", "quick_action", context)
      
      assert.is_true(result.success)
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      assert.are.equal("rebase -d @", executed[1])
    end)
  end)

  describe("default_commands rebase", function()
    it("should execute rebase with target substitution", function()
      local context = {
        target = "target456",
        commit_id = "current123"
      }
      
      local result = default_commands.execute_with_confirmation("rebase", context)
      
      assert.is_true(result.success)
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      -- Should substitute {target} from default rebase command definition
      assert.matches("rebase %-d target456", executed[1])
    end)
    
    it("should handle rebase with multiple arguments", function()
      local context = {
        target = "dest789",
        commit_id = "source456"
      }
      
      -- Test a more complex rebase scenario
      local result = default_commands.execute_with_confirmation("rebase", context)
      
      assert.is_true(result.success)
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      assert.matches("rebase %-d dest789", executed[1])
    end)
  end)

  describe("selection_integration rebase", function()
    it("should handle immediate rebase command with substitution", function()
      -- Mock command context to return rebase as immediate command
      local rebase_def = {
        command_type = require("jj.types").CommandTypes.IMMEDIATE,
        quick_action = {
          cmd = "rebase",
          args = {"-d", "{target}"},
          description = "Immediate rebase"
        }
      }
      
      local bufnr = 1
      local context = {
        target = "immediate123"
      }
      
      -- We need to test the _execute_immediate_command path
      local result = selection_integration._execute_immediate_command(rebase_def, bufnr)
      
      assert.is_true(result.success)
      assert.is_false(result.requires_selection)
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      -- The substitution should have happened via the unified system
      assert.matches("rebase %-d", executed[1])
    end)
  end)

  describe("command_context rebase substitution", function()
    it("should substitute variables through command_context system", function()
      local args = {"rebase", "-d", "{target}", "-s", "{commit_id}"}
      local context = {
        target = "context_target",
        commit_id = "context_commit"
      }
      
      local result = command_context.substitute_final_placeholders(args, context)
      
      assert.are.same({"rebase", "-d", "context_target", "-s", "context_commit"}, result)
    end)
    
    it("should handle mixed variable types in rebase commands", function()
      local args = {"-d", "{target}", "-m", "{user_input}"}
      local context = {
        target = "mixed_target"
      }
      
      local result = command_context.substitute_final_placeholders(args, context)
      
      assert.are.same({"-d", "mixed_target", "-m", "test commit message"}, result)
    end)
  end)

  describe("edge cases", function()
    it("should handle special characters in commit IDs", function()
      local args = {"-d", "{target}"}
      local context = {
        target = "commit-with-dashes_123.abc"
      }
      
      local result = command_execution.substitute_parameters(args, context)
      
      assert.are.same({"-d", "commit-with-dashes_123.abc"}, result)
    end)
    
    it("should not substitute malformed variable syntax", function()
      local args = {"-d", "{target", "target}", "{invalid_var}"}
      local context = {
        target = "real_target"
      }
      
      local result = command_execution.substitute_parameters(args, context)
      
      -- Only properly formed {target} should be substituted
      -- Malformed ones should be passed through as literals
      assert.are.same({"-d", "{target", "target}", "{invalid_var}"}, result)
    end)
    
    it("should handle empty target gracefully", function()
      local args = {"-d", "{target}"}
      local context = {
        target = ""  -- empty target
      }
      
      local result = command_execution.substitute_parameters(args, context)
      
      -- Empty target should still be used (not fallback to @)
      assert.are.same({"-d", ""}, result)
    end)
  end)
  
  describe("multi_target scenarios", function()
    it("should expand {multi_target} into multiple arguments", function()
      local args = {"new", "-m", "merge commit", "{multi_target}"}
      local context = {
        multi_target = {"parent1", "parent2", "parent3"}
      }
      
      local result = command_execution.substitute_parameters(args, context)
      
      assert.are.same({"new", "-m", "merge commit", "parent1", "parent2", "parent3"}, result)
    end)
    
    it("should fallback multi_target to single target", function()
      local args = {"new", "{multi_target}"}
      local context = {
        target = "single_target"
        -- no multi_target provided
      }
      
      local result = command_execution.substitute_parameters(args, context)
      
      assert.are.same({"new", "single_target"}, result)
    end)
  end)
end)