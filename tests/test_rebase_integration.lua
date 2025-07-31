-- Integration tests for rebase functionality with realistic commit IDs
describe("rebase integration with realistic commit scenarios", function()
  local command_execution
  local default_commands
  local keybindings
  local selection_integration
  local mock_executor
  
  before_each(function()
    -- Reset modules
    package.loaded["jj.command_execution"] = nil
    package.loaded["jj.default_commands"] = nil
    package.loaded["jj.keybindings"] = nil
    package.loaded["jj.selection_integration"] = nil
    package.loaded["jj.log.executor"] = nil
    
    -- Track executed commands
    local executed_commands = {}
    mock_executor = {
      execute_jj_command = function(cmd)
        table.insert(executed_commands, cmd)
        return { 
          success = true, 
          output = "Successfully rebased " .. cmd:match("rebase %-d (%S+)") or "unknown"
        }
      end,
      get_executed_commands = function()
        return executed_commands
      end,
      clear_executed_commands = function()
        executed_commands = {}
      end
    }
    
    -- Mock vim APIs with realistic behavior
    _G.vim = _G.vim or {}
    _G.vim.fn = _G.vim.fn or {}
    _G.vim.fn.input = function(prompt)
      if prompt:match("Commit description") then
        return "Updated commit message"
      end
      return "default input"
    end
    _G.vim.fn.confirm = function(msg, choices, default)
      return 1  -- Always confirm for testing
    end
    _G.vim.api = _G.vim.api or {}
    _G.vim.api.nvim_get_current_line = function()
      return "◉ abc123def Current commit message"
    end
    _G.vim.log = _G.vim.log or {}
    _G.vim.log.levels = _G.vim.log.levels or {}
    _G.vim.log.levels.INFO = 1
    _G.vim.log.levels.ERROR = 4
    _G.vim.notify = function(msg, level) end
    _G.vim.deepcopy = function(obj)
      -- Simple deep copy implementation for testing
      if type(obj) ~= "table" then return obj end
      local copy = {}
      for k, v in pairs(obj) do
        copy[k] = _G.vim.deepcopy(v)
      end
      return copy
    end
    _G.vim.tbl_deep_extend = function(behavior, ...)
      local result = {}
      for _, tbl in ipairs({...}) do
        for k, v in pairs(tbl) do
          result[k] = v
        end
      end
      return result
    end
    
    -- Set up package.preload to inject mocks
    package.preload["jj.log.executor"] = function()
      return mock_executor
    end
    
    command_execution = require("jj.command_execution")
    default_commands = require("jj.default_commands")
    keybindings = require("jj.keybindings")
    selection_integration = require("jj.selection_integration")
    
    -- Register default commands
    default_commands.register_all_defaults()
  end)
  
  after_each(function()
    mock_executor.clear_executed_commands()
    package.preload["jj.log.executor"] = nil
  end)

  describe("realistic commit ID scenarios", function()
    it("should handle typical jj commit IDs (short hash)", function()
      local context = {
        target = "xyz789a",
        commit_id = "abc123d"
      }
      
      local result = command_execution.execute_command("rebase", "quick_action", context)
      
      assert.is_true(result.success)
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      assert.are.equal("rebase -d xyz789a", executed[1])
    end)
    
    it("should handle full commit IDs", function()
      local context = {
        target = "xyz789abcdef0123456789abcdef0123456789ab",
        commit_id = "abc123def4567890abcdef0123456789abcdef01"
      }
      
      local result = command_execution.execute_command("rebase", "quick_action", context)
      
      assert.is_true(result.success)
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      assert.are.equal("rebase -d xyz789abcdef0123456789abcdef0123456789ab", executed[1])
    end)
    
    it("should handle commit IDs with mixed case", function()
      local context = {
        target = "AbC123DeF",
        commit_id = "XyZ789AbC"
      }
      
      local result = command_execution.execute_command("rebase", "quick_action", context)
      
      assert.is_true(result.success)
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      assert.are.equal("rebase -d AbC123DeF", executed[1])
    end)
  end)

  describe("rebase menu options", function()
    it("should execute basic rebase option with target substitution", function()
      local context = {
        cmd = "rebase",
        args = {"-d", "{target}"},
        target = "menu_target_123"
      }
      
      local result = command_execution.execute_command("rebase", "menu_option", context)
      
      assert.is_true(result.success)
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      assert.are.equal("rebase -d menu_target_123", executed[1])
    end)
    
    it("should execute branch rebase option", function()
      local context = {
        cmd = "rebase",
        args = {"-b", "@", "-d", "{target}"},
        target = "branch_target_456"
      }
      
      local result = command_execution.execute_command("rebase", "menu_option", context)
      
      assert.is_true(result.success)
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      assert.are.equal("rebase -b @ -d branch_target_456", executed[1])
    end)
    
    it("should execute descendants rebase option", function()
      local context = {
        cmd = "rebase",
        args = {"-s", "@", "-d", "{target}"},
        target = "descendants_target_789"
      }
      
      local result = command_execution.execute_command("rebase", "menu_option", context)
      
      assert.is_true(result.success)
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      assert.are.equal("rebase -s @ -d descendants_target_789", executed[1])
    end)
  end)

  describe("default_commands integration", function()
    it("should execute rebase through default_commands system", function()
      local context = {
        target = "default_target_abc",
        commit_id = "current_commit_def"
      }
      
      local result = default_commands.execute_with_confirmation("rebase", context)
      
      assert.is_true(result.success)
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      assert.matches("rebase %-d default_target_abc", executed[1])
    end)
  end)

  describe("error scenarios", function()
    it("should handle command execution failures gracefully", function()
      -- Mock executor to return failure
      mock_executor.execute_jj_command = function(cmd)
        return { 
          success = false, 
          error = "Failed to rebase: merge conflict"
        }
      end
      
      local context = {
        target = "conflict_target",
        commit_id = "current_commit"
      }
      
      local result = command_execution.execute_command("rebase", "quick_action", context)
      
      assert.is_false(result.success)
      assert.matches("Failed to rebase", result.error)
    end)
    
    it("should validate that {target} is not passed literally", function()
      local context = {
        target = "real_target_789"
      }
      
      local result = command_execution.execute_command("rebase", "quick_action", context)
      
      assert.is_true(result.success)
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      
      -- Critical test: ensure {target} is NOT in the executed command
      assert.is_not.matches("{target}", executed[1])
      assert.matches("real_target_789", executed[1])
    end)
  end)

  describe("edge cases", function()
    it("should handle special commit references", function()
      local special_refs = {"@", "@-", "@+", "main", "origin/main"}
      
      for _, ref in ipairs(special_refs) do
        mock_executor.clear_executed_commands()
        
        local context = {
          target = ref,
          commit_id = "current_abc"
        }
        
        local result = command_execution.execute_command("rebase", "quick_action", context)
        
        assert.is_true(result.success, "Failed for reference: " .. ref)
        local executed = mock_executor.get_executed_commands()
        assert.are.equal(1, #executed)
        assert.are.equal("rebase -d " .. ref, executed[1])
      end
    end)
    
    it("should handle empty target gracefully", function()
      local context = {
        target = "",  -- empty target
        commit_id = "fallback_commit"
      }
      
      local result = command_execution.execute_command("rebase", "quick_action", context)
      
      assert.is_true(result.success)
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      -- Empty target should be used as-is (not fallback)
      assert.are.equal("rebase -d ", executed[1])
    end)
    
    it("should use fallback when no target provided", function()
      local context = {
        commit_id = "fallback_commit_123"
        -- no target provided
      }
      
      local result = command_execution.execute_command("rebase", "quick_action", context)
      
      assert.is_true(result.success)
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      assert.are.equal("rebase -d fallback_commit_123", executed[1])
    end)
  end)

  describe("real-world simulation", function()
    it("should simulate the exact failing scenario from the bug report", function()
      -- This simulates the exact scenario that was failing:
      -- User presses 'r' for rebase, selects a target, but {target} wasn't substituted
      
      local context = {
        target = "selected_commit_abc123",
        commit_id = "current_working_def456"
      }
      
      -- Simulate the command that was failing
      local result = command_execution.execute_command("rebase", "quick_action", context)
      
      assert.is_true(result.success)
      local executed = mock_executor.get_executed_commands()
      assert.are.equal(1, #executed)
      
      -- The critical fix: should NOT contain literal {target}
      assert.is_not.matches("{target}", executed[1])
      -- Should contain the actual target commit ID
      assert.matches("selected_commit_abc123", executed[1])
      -- Should be a valid jj command
      assert.are.equal("rebase -d selected_commit_abc123", executed[1])
    end)
  end)
end)