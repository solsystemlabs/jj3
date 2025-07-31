-- Simple integration test to verify basic functionality
require("helpers.vim_mock")

-- Add lua directory to package path
package.path = package.path .. ";lua/?.lua"

describe("Simple Terminal Integration", function()
  it("should load terminal manager successfully", function()
    local ok, terminal_manager = pcall(require, "jj.terminal_manager")
    assert.is_true(ok)
    assert.is_not_nil(terminal_manager.create_terminal_window)
  end)
  
  it("should load executor successfully", function()
    local ok, executor = pcall(require, "jj.log.executor")
    assert.is_true(ok)
    assert.is_not_nil(executor.execute_jj_command)
  end)
  
  it("should detect interactive commands", function()
    local ok, interactive_detection = pcall(require, "jj.interactive_detection")
    assert.is_true(ok)
    assert.is_true(interactive_detection.is_interactive_command("describe", {}))
    assert.is_false(interactive_detection.is_interactive_command("log", {}))
  end)
end)