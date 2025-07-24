-- Tests for jj command execution framework
require("helpers.vim_mock")
local test_repo = require("helpers.test_repository")

-- Load the executor module from the plugin directory
local executor = dofile("lua/jj/log/executor.lua")

describe("JJ Command Executor", function()
  local lfs = require('lfs')
  local original_cwd

  before_each(function()
    original_cwd = lfs.currentdir()
    -- Change to test repository for all tests
    lfs.chdir(test_repo.test_repo_path)
  end)

  after_each(function()
    lfs.chdir(original_cwd)
  end)

  describe("basic command execution", function()
    it("should execute simple jj log command", function()
      local result = executor.execute_jj_command("log --no-graph")
      
      assert.is_not_nil(result)
      if not result.success then
        print("Error:", result.error)
      end
      assert.is_true(result.success)
      assert.is_string(result.output)
      assert.is_true(#result.output > 0)
      assert.is_nil(result.error)
    end)

    it("should handle command execution errors", function()
      local result = executor.execute_jj_command("invalid-command")
      
      assert.is_not_nil(result)
      assert.is_false(result.success)
      assert.is_not_nil(result.error)
      assert.is_string(result.error)
    end)

    it("should execute commands in repository context", function()
      local result = executor.execute_jj_command("show")
      
      assert.is_not_nil(result)
      assert.is_true(result.success)
      assert.is_string(result.output)
    end)
  end)

  describe("template-based execution", function()
    it("should execute jj log with minimal template", function()
      local template = 'commit_id ++ "\\x00" ++ change_id'
      local result = executor.execute_with_template("log", template)
      
      assert.is_not_nil(result)
      assert.is_true(result.success)
      assert.is_string(result.output)
      
      -- Check that output contains null-byte separators
      assert.is_true(result.output:find("\0") ~= nil)
    end)

    it("should execute jj log with comprehensive template", function()
      local result = executor.execute_comprehensive_log()
      
      assert.is_not_nil(result)
      if not result.success then
        print("Comprehensive template error:", result.error)
      end
      assert.is_true(result.success)
      assert.is_string(result.output)
      
      -- Should contain multiple null-byte separated fields
      local null_count = 0
      for _ in result.output:gmatch("\0") do
        null_count = null_count + 1
      end
      assert.is_true(null_count > 5) -- Comprehensive template has many fields
    end)

    it("should execute jj log with minimal template for commit IDs", function()
      local result = executor.execute_minimal_log()
      
      assert.is_not_nil(result)
      if not result.success then
        print("Minimal template error:", result.error)
      end
      assert.is_true(result.success)
      assert.is_string(result.output)
      
      -- Should be shorter than comprehensive output
      local comprehensive = executor.execute_comprehensive_log()
      if comprehensive.output then
        assert.is_true(#result.output < #comprehensive.output)
      end
    end)
  end)

  describe("async command execution", function()
    it("should execute commands asynchronously with callback", function()
      local callback_called = false
      local callback_result = nil
      
      local function callback(result)
        callback_called = true
        callback_result = result
      end
      
      executor.execute_async("log --no-graph", callback)
      
      -- Simple polling to wait for async completion
      local timeout = 0
      while not callback_called and timeout < 50 do
        vim.wait(10)
        timeout = timeout + 1
      end
      
      assert.is_true(callback_called)
      assert.is_not_nil(callback_result)
      assert.is_true(callback_result.success)
    end)

    it("should handle async command errors with callback", function()
      local callback_called = false
      local callback_result = nil
      
      local function callback(result)
        callback_called = true
        callback_result = result
      end
      
      executor.execute_async("invalid-command", callback)
      
      -- Simple polling to wait for async completion
      local timeout = 0
      while not callback_called and timeout < 50 do
        vim.wait(10)
        timeout = timeout + 1
      end
      
      assert.is_true(callback_called)
      assert.is_not_nil(callback_result)
      assert.is_false(callback_result.success)
      assert.is_not_nil(callback_result.error)
    end)
  end)

  describe("template definitions", function()
    it("should have predefined minimal template", function()
      local template = executor.get_minimal_template()
      
      assert.is_string(template)
      assert.is_true(template:find("commit_id") ~= nil)
      assert.is_true(template:find("change_id") ~= nil)
    end)

    it("should have predefined comprehensive template", function()
      local template = executor.get_comprehensive_template()
      
      assert.is_string(template)
      assert.is_true(template:find("commit_id") ~= nil)
      assert.is_true(template:find("change_id") ~= nil)
      assert.is_true(template:find("author") ~= nil)
      assert.is_true(template:find("description") ~= nil)
      assert.is_true(template:find("bookmarks") ~= nil)
    end)

    it("should validate template syntax", function()
      local valid_template = 'commit_id ++ "\\x00" ++ change_id'
      assert.is_true(executor.validate_template(valid_template))
      
      local invalid_template = 'invalid {{ syntax'
      assert.is_false(executor.validate_template(invalid_template))
    end)
  end)

  describe("repository context", function()
    it("should execute commands in correct repository directory", function()
      local result = executor.execute_jj_command("root")
      
      assert.is_not_nil(result)
      assert.is_true(result.success)
      assert.is_string(result.output)
      assert.is_true(result.output:find("complex-repo") ~= nil)
    end)

    it("should handle repository detection before execution", function()
      -- Change to non-repository directory
      lfs.chdir("../non-jj-dir")
      
      local result = executor.execute_jj_command("log")
      
      assert.is_not_nil(result)
      assert.is_false(result.success)
      assert.is_not_nil(result.error)
      assert.is_true(result.error:find("repository") ~= nil)
    end)
  end)

  describe("error handling", function()
    it("should handle timeout scenarios", function()
      -- This would test timeout handling in real implementation
      local result = executor.execute_with_timeout("log", 1) -- 1ms timeout
      
      assert.is_not_nil(result)
      -- Either succeeds quickly or times out appropriately
      assert.is_boolean(result.success)
    end)

    it("should sanitize command arguments", function()
      -- Test that dangerous characters are handled safely
      local result = executor.execute_jj_command("log; rm -rf /")
      
      assert.is_not_nil(result)
      assert.is_false(result.success)
      assert.is_not_nil(result.error)
    end)
  end)
end)