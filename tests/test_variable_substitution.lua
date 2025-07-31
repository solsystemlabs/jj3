-- Tests for unified variable substitution system
local helpers = require("tests.helpers.vim_mock")

describe("variable substitution system", function()
  local command_execution
  
  before_each(function()
    -- Reset modules
    package.loaded["jj.command_execution"] = nil
    package.loaded["jj.log.executor"] = nil
    package.loaded["jj.log.parser"] = nil
    
    -- Mock vim.fn.input
    _G.vim = _G.vim or {}
    _G.vim.fn = _G.vim.fn or {}
    _G.vim.fn.input = function(prompt)
      return "test input"
    end
    
    command_execution = require("jj.command_execution")
  end)

  describe("substitute_parameters", function()
    it("should substitute {commit_id} with provided context", function()
      local args = {"-d", "{commit_id}"}
      local context = {commit_id = "abc123"}
      
      local result = command_execution.substitute_parameters(args, context)
      
      assert.are.same({"-d", "abc123"}, result)
    end)
    
    it("should substitute {change_id} with provided context", function()
      local args = {"-r", "{change_id}"}
      local context = {change_id = "xyz789"}
      
      local result = command_execution.substitute_parameters(args, context)
      
      assert.are.same({"-r", "xyz789"}, result)
    end)
    
    it("should substitute {target} with provided context", function()
      local args = {"-d", "{target}"}
      local context = {target = "target123"}
      
      local result = command_execution.substitute_parameters(args, context)
      
      assert.are.same({"-d", "target123"}, result)
    end)
    
    it("should substitute multiple variables in one command", function()
      local args = {"-d", "{target}", "-r", "{commit_id}"}
      local context = {target = "target123", commit_id = "commit456"}
      
      local result = command_execution.substitute_parameters(args, context)
      
      assert.are.same({"-d", "target123", "-r", "commit456"}, result)
    end)
    
    it("should handle {multi_target} as array", function()
      local args = {"-d", "{multi_target}"}
      local context = {multi_target = {"target1", "target2", "target3"}}
      
      local result = command_execution.substitute_parameters(args, context)
      
      assert.are.same({"-d", "target1", "target2", "target3"}, result)
    end)
    
    it("should fallback {target} to {commit_id} when target missing", function()
      local args = {"-d", "{target}"}
      local context = {commit_id = "fallback123"}
      
      local result = command_execution.substitute_parameters(args, context)
      
      assert.are.same({"-d", "fallback123"}, result)
    end)
    
    it("should fallback {change_id} to {commit_id} when change_id missing", function()
      local args = {"-r", "{change_id}"}
      local context = {commit_id = "fallback456"}
      
      local result = command_execution.substitute_parameters(args, context)
      
      assert.are.same({"-r", "fallback456"}, result)
    end)
    
    it("should use @ as final fallback when context missing", function()
      local args = {"-d", "{target}", "-r", "{commit_id}"}
      local context = {}
      
      local result = command_execution.substitute_parameters(args, context)
      
      assert.are.same({"-d", "@", "-r", "@"}, result)
    end)
    
    it("should handle empty context gracefully", function()
      local args = {"-d", "{target}"}
      local context = nil
      
      local result = command_execution.substitute_parameters(args, context)
      
      assert.are.same({"-d", "@"}, result)
    end)
    
    it("should pass through non-variable arguments unchanged", function()
      local args = {"rebase", "-d", "{target}", "--no-edit"}
      local context = {target = "target123"}
      
      local result = command_execution.substitute_parameters(args, context)
      
      assert.are.same({"rebase", "-d", "target123", "--no-edit"}, result)
    end)
    
    it("should handle {user_input} by prompting user", function()
      -- Mock vim.fn.input to return test input
      vim.fn.input = function(prompt)
        return "test message"
      end
      
      local args = {"-m", "{user_input}"}
      local context = {}
      
      local result = command_execution.substitute_parameters(args, context)
      
      assert.are.same({"-m", "test message"}, result)
    end)
    
    it("should skip {user_input} when user provides empty input", function()
      -- Mock vim.fn.input to return empty string
      vim.fn.input = function(prompt)
        return ""
      end
      
      local args = {"-m", "{user_input}", "{commit_id}"}
      local context = {commit_id = "abc123"}
      
      local result = command_execution.substitute_parameters(args, context)
      
      -- Should skip the empty user input but keep other args
      assert.are.same({"-m", "abc123"}, result)
    end)
    
    it("should handle complex mixed variable scenarios", function()
      local args = {"new", "-m", "{user_input}", "--insert-before", "{target}", "{commit_id}"}
      local context = {target = "before123", commit_id = "current456"}
      
      -- Mock user input
      vim.fn.input = function(prompt)
        return "new commit message"
      end
      
      local result = command_execution.substitute_parameters(args, context)
      
      assert.are.same({"new", "-m", "new commit message", "--insert-before", "before123", "current456"}, result)
    end)
  end)
  
  describe("error handling", function()
    it("should validate malformed variable syntax gracefully", function()
      -- These should be treated as literal strings, not variables
      local args = {"{target", "target}", "{}", "{{target}}"}
      local context = {target = "target123"}
      
      local result = command_execution.substitute_parameters(args, context)
      
      -- Should pass through unchanged since they're not valid variable syntax
      assert.are.same({"{target", "target}", "{}", "{{target}}"}, result)
    end)
    
    it("should handle special characters in commit IDs", function()
      local args = {"-d", "{target}"}
      local context = {target = "commit-with-dashes_and_underscores.123"}
      
      local result = command_execution.substitute_parameters(args, context)
      
      assert.are.same({"-d", "commit-with-dashes_and_underscores.123"}, result)
    end)
  end)
end)