-- Full integration test for interactive command system
require("helpers.vim_mock")

-- Add lua directory to package path
package.path = package.path .. ";lua/?.lua"

describe("Full Interactive System Integration", function()
  local jj_init
  local config
  local interactive_detection
  
  before_each(function()
    -- Reset global state
    _G.vim.user_commands = {}
    
    -- Clear require cache to ensure fresh modules
    package.loaded["jj.config"] = nil
    package.loaded["jj.interactive_detection"] = nil
    package.loaded["jj.init"] = nil
    package.loaded["jj.default_commands"] = nil
    package.loaded["jj.command_execution"] = nil
    package.loaded["jj.keybindings"] = nil
    package.loaded["jj.commands"] = nil
    
    -- Load modules using require (same as init system)
    config = require("jj.config")
    interactive_detection = require("jj.interactive_detection")
    jj_init = require("jj.init")
    
    -- Reset configurations
    config.setup({})
    interactive_detection.reset_config()
  end)

  describe("configuration integration", function()
    it("should accept interactive configuration through setup", function()
      local user_config = {
        interactive = {
          force_interactive = {"log"},
          force_non_interactive = {"split"},
          custom_interactive_flags = {
            ["my-command"] = {"-e", "--edit"}
          }
        }
      }
      
      -- Setup should configure interactive detection
      jj_init.setup(user_config)
      
      -- Verify configuration was applied by testing actual behavior
      -- (since the init system loads modules separately, we test behavior rather than internal state)
      assert.is_true(interactive_detection.is_interactive_command("log", {})) -- Should be forced interactive
      assert.is_false(interactive_detection.is_interactive_command("split", {})) -- Should be forced non-interactive
      assert.is_true(interactive_detection.is_interactive_command("my-command", {"-e"})) -- Custom flag
    end)
    
    it("should work without interactive config", function()
      -- Setup without interactive config should not error
      jj_init.setup({
        window = { size = 80 }
      })
      
      -- Should still work with default detection
      assert.is_true(interactive_detection.is_interactive_command("split", {}))
      assert.is_false(interactive_detection.is_interactive_command("log", {}))
    end)
    
    it("should handle malformed interactive config gracefully", function()
      -- Setup with invalid interactive config
      jj_init.setup({
        interactive = "not a table"
      })
      
      -- Should still work with defaults
      assert.is_true(interactive_detection.is_interactive_command("split", {}))
    end)
  end)

  describe("plugin lifecycle", function()
    it("should maintain interactive detection through setup calls", function()
      -- First setup
      jj_init.setup({
        interactive = {
          force_interactive = {"log"}
        }
      })
      
      assert.is_true(interactive_detection.is_interactive_command("log", {}))
      
      -- Second setup should override
      jj_init.setup({
        interactive = {
          force_non_interactive = {"log"}
        }
      })
      
      assert.is_false(interactive_detection.is_interactive_command("log", {}))
    end)
    
    it("should preserve other config while setting interactive", function()
      jj_init.setup({
        window = { size = 100 },
        interactive = {
          force_interactive = {"status"}
        }
      })
      
      local current_config = config.get()
      assert.are.equal(100, current_config.window.size)
      assert.is_true(interactive_detection.is_interactive_command("status", {}))
    end)
  end)

  describe("real-world scenarios", function()
    it("should handle common user configurations", function()
      -- Simulate a user who wants describe to always be non-interactive
      -- and wants to add a custom command
      jj_init.setup({
        interactive = {
          force_non_interactive = {"describe"},
          custom_interactive_flags = {
            ["edit"] = {"-i", "--interactive"}
          }
        }
      })
      
      -- Verify describe is no longer interactive
      assert.is_false(interactive_detection.is_interactive_command("describe", {}))
      
      -- Verify custom command works
      assert.is_true(interactive_detection.is_interactive_command("edit", {"-i"}))
      assert.is_false(interactive_detection.is_interactive_command("edit", {}))
    end)
    
    it("should support power user configurations", function()
      -- Simulate a power user with complex requirements
      jj_init.setup({
        interactive = {
          force_interactive = {"status", "log"}, -- Make typically non-interactive commands interactive
          force_non_interactive = {"resolve"}, -- Make typically interactive command non-interactive
          custom_interactive_flags = {
            ["bookmark"] = {"--edit", "-e"},
            ["squash"] = {"--ask", "--confirm"} -- Custom flags for existing command
          }
        }
      })
      
      -- Test overrides
      assert.is_true(interactive_detection.is_interactive_command("status", {}))
      assert.is_true(interactive_detection.is_interactive_command("log", {}))
      assert.is_false(interactive_detection.is_interactive_command("resolve", {}))
      
      -- Test custom flags
      assert.is_true(interactive_detection.is_interactive_command("bookmark", {"--edit"}))
      assert.is_true(interactive_detection.is_interactive_command("squash", {"--ask"}))
      
      -- Original squash flags should still work
      assert.is_true(interactive_detection.is_interactive_command("squash", {"-i"}))
    end)
  end)
end)