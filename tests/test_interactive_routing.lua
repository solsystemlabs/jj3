-- Tests for interactive command routing integration
require("helpers.vim_mock")
local test_repo = require("helpers.test_repository")

describe("Interactive Command Routing", function()
  local executor
  local lfs = require('lfs')
  local original_cwd

  before_each(function()
    original_cwd = lfs.currentdir()
    lfs.chdir(test_repo.test_repo_path)
    
    -- Load the executor module
    executor = dofile("lua/jj/log/executor.lua")
  end)

  after_each(function()
    lfs.chdir(original_cwd)
  end)

  describe("command parsing", function()
    it("should parse simple commands correctly", function()
      local result = executor._parse_command("describe")
      assert.are.equal("describe", result.cmd)
      assert.are.same({}, result.args)
    end)

    it("should parse commands with arguments", function()
      local result = executor._parse_command("describe -m 'commit message'")
      assert.are.equal("describe", result.cmd)
      assert.are.same({"-m", "'commit", "message'"}, result.args)
    end)

    it("should handle empty commands", function()
      local result = executor._parse_command("")
      assert.are.equal("", result.cmd)
      assert.are.same({}, result.args)
    end)

    it("should handle nil commands", function()
      local result = executor._parse_command(nil)
      assert.are.equal("", result.cmd)
      assert.are.same({}, result.args)
    end)
  end)

  describe("interactive detection integration", function()
    it("should detect interactive commands through routing", function()
      local is_interactive = executor._should_use_interactive_mode("split", {})
      assert.is_true(is_interactive)
    end)

    it("should detect non-interactive commands", function()
      local is_interactive = executor._should_use_interactive_mode("log", {})
      assert.is_false(is_interactive)
    end)

    it("should handle conditional commands", function()
      local is_interactive_without_flags = executor._should_use_interactive_mode("describe", {})
      assert.is_true(is_interactive_without_flags)
      
      local is_interactive_with_message = executor._should_use_interactive_mode("describe", {"-m", "message"})
      assert.is_false(is_interactive_with_message)
    end)

    it("should handle missing interactive detection module gracefully", function()
      -- Mock require to fail for interactive_detection
      local original_require = require
      _G.require = function(module)
        if module == "jj.interactive_detection" then
          error("Module not found")
        end
        return original_require(module)
      end
      
      local is_interactive = executor._should_use_interactive_mode("split", {})
      assert.is_false(is_interactive)
      
      -- Restore original require
      _G.require = original_require
    end)
  end)

  describe("command execution routing", function()
    it("should route interactive commands through fallback", function()
      local result = executor.execute_jj_command("split")
      
      -- Should succeed (fallback to normal execution)
      assert.is_true(result.success)
      -- Should have interactive_fallback flag
      assert.is_true(result.interactive_fallback)
    end)

    it("should execute non-interactive commands normally", function()
      local result = executor.execute_jj_command("log --no-graph -r @")
      
      -- Should succeed
      assert.is_true(result.success)
      -- Should not have interactive_fallback flag
      assert.is_nil(result.interactive_fallback)
    end)

    it("should handle async interactive commands", function()
      local callback_called = false
      local callback_result = nil
      
      executor.execute_async("split", function(result)
        callback_called = true
        callback_result = result
      end)
      
      -- Wait a bit for async execution
      vim.wait(100)
      
      assert.is_true(callback_called)
      assert.is_not_nil(callback_result)
      assert.is_true(callback_result.interactive_fallback)
    end)

    it("should preserve existing error handling", function()
      local result = executor.execute_jj_command("invalid-command")
      
      -- Should fail
      assert.is_false(result.success)
      assert.is_not_nil(result.error)
    end)
  end)

  describe("backward compatibility", function()
    it("should not break existing command execution", function()
      -- Test that existing functionality continues to work
      local result = executor.execute_jj_command("log --no-graph -r @")
      assert.is_true(result.success)
      assert.is_not_nil(result.output)
    end)

    it("should preserve template-based execution", function()
      local result = executor.execute_minimal_log()
      assert.is_true(result.success)
      assert.is_not_nil(result.output)
    end)

    it("should maintain async execution compatibility", function()
      local callback_called = false
      
      executor.execute_async("log --no-graph -r @", function(result)
        callback_called = true
        assert.is_true(result.success)
      end)
      
      vim.wait(100)
      assert.is_true(callback_called)
    end)
  end)
end)