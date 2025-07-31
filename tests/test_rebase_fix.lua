-- Integration test to verify the rebase {target} substitution fix
describe("rebase command substitution fix", function()
  local command_execution
  local command_context
  
  before_each(function()
    -- Reset modules
    package.loaded["jj.command_execution"] = nil
    package.loaded["jj.command_context"] = nil
    
    -- Mock vim APIs
    _G.vim = _G.vim or {}
    _G.vim.fn = _G.vim.fn or {}
    _G.vim.fn.input = function(prompt)
      return "test message"
    end
    
    command_execution = require("jj.command_execution")
    command_context = require("jj.command_context")
  end)

  it("should substitute {target} in unified substitution system", function()
    local args = {"rebase", "-d", "{target}"}
    local context = {target = "abc123"}
    
    local result = command_execution.substitute_parameters(args, context)
    
    assert.are.same({"rebase", "-d", "abc123"}, result)
  end)
  
  it("should substitute {target} through command_context system", function()
    local args = {"rebase", "-d", "{target}"}
    local context = {target = "xyz789"}
    
    -- This uses the unified system now
    local result = command_context.substitute_final_placeholders(args, context)
    
    assert.are.same({"rebase", "-d", "xyz789"}, result)
  end)
  
  it("should fallback {target} to {commit_id} when target missing", function()
    local args = {"-d", "{target}"}
    local context = {commit_id = "fallback456"}
    
    local result = command_execution.substitute_parameters(args, context)
    
    assert.are.same({"-d", "fallback456"}, result)
  end)
  
  it("should use @ as final fallback when both target and commit_id missing", function()
    local args = {"-d", "{target}"}
    local context = {}
    
    local result = command_execution.substitute_parameters(args, context)
    
    assert.are.same({"-d", "@"}, result)
  end)
  
  it("should handle the exact rebase scenario from the error report", function()
    -- This is the exact command that was failing: jj rebase -d {target}
    local args = {"-d", "{target}"}
    local context = {target = "commit_abc123"}
    
    local result = command_execution.substitute_parameters(args, context)
    
    -- Should NOT return {target} literally
    assert.are.same({"-d", "commit_abc123"}, result)
    
    -- Verify no literal {target} remains
    for _, arg in ipairs(result) do
      assert.is_not.equal("{target}", arg)
    end
  end)
end)