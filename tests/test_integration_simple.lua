-- Simple integration test for interactive command routing
require("helpers.vim_mock")

describe("Interactive Command Integration", function()
  local interactive_detection
  
  before_each(function()
    interactive_detection = dofile("lua/jj/interactive_detection.lua")
    interactive_detection.reset_config()
  end)

  describe("end-to-end detection", function()
    it("should detect interactive commands correctly", function()
      -- Test always interactive
      assert.is_true(interactive_detection.is_interactive_command("split", {}))
      assert.is_true(interactive_detection.is_interactive_command("resolve", {}))
      assert.is_true(interactive_detection.is_interactive_command("diffedit", {}))
      
      -- Test conditional interactive
      assert.is_true(interactive_detection.is_interactive_command("describe", {}))
      assert.is_false(interactive_detection.is_interactive_command("describe", {"-m", "message"}))
      
      -- Test never interactive
      assert.is_false(interactive_detection.is_interactive_command("log", {}))
      assert.is_false(interactive_detection.is_interactive_command("status", {}))
    end)
    
    it("should handle user configuration", function()
      -- Test force interactive
      interactive_detection.set_user_config({
        force_interactive = {"log"}
      })
      assert.is_true(interactive_detection.is_interactive_command("log", {}))
      
      -- Reset and test force non-interactive
      interactive_detection.set_user_config({
        force_non_interactive = {"split"}
      })
      assert.is_false(interactive_detection.is_interactive_command("split", {}))
    end)
    
    it("should work with the main plugin architecture", function()
      -- Test that the detection module can be required properly
      local ok, detection = pcall(require, "jj.interactive_detection")
      assert.is_true(ok)
      assert.is_not_nil(detection.is_interactive_command)
    end)
  end)
end)