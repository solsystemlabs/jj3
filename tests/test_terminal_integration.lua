-- Integration tests for terminal manager with executor system
require("helpers.vim_mock")

-- Add lua directory to package path
package.path = package.path .. ";lua/?.lua"

describe("Terminal Manager Integration", function()
  local executor
  local terminal_manager
  
  before_each(function()
    -- Clear require cache
    package.loaded["jj.log.executor"] = nil
    package.loaded["jj.terminal_manager"] = nil
    package.loaded["jj.interactive_detection"] = nil
    
    -- Load modules
    executor = require("jj.log.executor")
    terminal_manager = require("jj.terminal_manager")
  end)

  describe("executor integration", function()
    it("should route interactive commands to terminal manager", function()
      local terminal_created = false
      local terminal_command = nil
      
      -- Mock terminal manager
      local original_create = terminal_manager.create_terminal_window
      terminal_manager.create_terminal_window = function(command, config, callback)
        terminal_created = true
        terminal_command = command
        return {
          buffer_id = 100,
          window_id = 200,
          job_id = 300
        }
      end
      
      -- Execute an interactive command
      local result = executor.execute_jj_command("describe")
      
      assert.is_true(terminal_created)
      assert.are.equal("describe", terminal_command)
      assert.is_true(result.success)
      assert.is_true(result.interactive)
      assert.is_not_nil(result.terminal_info)
      assert.are.equal(100, result.terminal_info.buffer_id)
      assert.are.equal(200, result.terminal_info.window_id)
      assert.are.equal(300, result.terminal_info.job_id)
      
      -- Restore original
      terminal_manager.create_terminal_window = original_create
    end)
    
    it("should execute non-interactive commands normally", function()
      local terminal_created = false
      
      -- Mock terminal manager
      local original_create = terminal_manager.create_terminal_window
      terminal_manager.create_terminal_window = function(command, config, callback)
        terminal_created = true
        return {
          buffer_id = 100,
          window_id = 200,
          job_id = 300
        }
      end
      
      -- Execute a non-interactive command
      local result = executor.execute_jj_command("log --no-graph -r @")
      
      assert.is_false(terminal_created)
      assert.is_true(result.success)
      assert.is_nil(result.interactive)
      assert.is_nil(result.terminal_info)
      
      -- Restore original
      terminal_manager.create_terminal_window = original_create
    end)
    
    it("should handle terminal creation failure gracefully", function()
      -- Mock terminal manager to fail
      local original_create = terminal_manager.create_terminal_window
      terminal_manager.create_terminal_window = function(command, config, callback)
        return {
          error = "Mock terminal creation failure"
        }
      end
      
      -- Execute an interactive command
      local result = executor.execute_jj_command("describe")
      
      -- Should fall back to normal execution
      assert.is_true(result.success)
      assert.is_true(result.fallback)
      assert.is_nil(result.interactive)
      
      -- Restore original
      terminal_manager.create_terminal_window = original_create
    end)
    
    it("should handle missing terminal manager gracefully", function()
      -- Mock require to fail for terminal manager
      local original_require = require
      _G.require = function(module)
        if module == "jj.terminal_manager" then
          error("Module not found")
        end
        return original_require(module)
      end
      
      -- Execute an interactive command
      local result = executor.execute_jj_command("describe")
      
      -- Should fall back to normal execution
      assert.is_true(result.success)
      assert.is_true(result.fallback)
      assert.is_nil(result.interactive)
      
      -- Restore original require
      _G.require = original_require
    end)
  end)

  describe("async integration", function()
    it("should handle async interactive commands", function()
      local callback_called = false
      local callback_result = nil
      local terminal_callback = nil
      
      -- Mock terminal manager to capture callback
      local original_create = terminal_manager.create_terminal_window
      terminal_manager.create_terminal_window = function(command, config, callback)
        terminal_callback = callback
        return {
          buffer_id = 100,
          window_id = 200,
          job_id = 300
        }
      end
      
      -- Execute async interactive command
      executor.execute_async("describe", function(result)
        callback_called = true
        callback_result = result
      end)
      
      -- Simulate terminal completion
      if terminal_callback then
        terminal_callback(0) -- Success exit code
      end
      
      -- No need to wait - callback should be called immediately in test
      
      assert.is_true(callback_called)
      assert.is_not_nil(callback_result)
      assert.is_true(callback_result.success)
      assert.is_true(callback_result.interactive)
      assert.are.equal(0, callback_result.exit_code)
      
      -- Restore original
      terminal_manager.create_terminal_window = original_create
    end)
    
    it("should handle async terminal creation failure", function()
      local callback_called = false
      local callback_result = nil
      
      -- Mock terminal manager to fail
      local original_create = terminal_manager.create_terminal_window
      terminal_manager.create_terminal_window = function(command, config, callback)
        return {
          error = "Mock terminal creation failure"
        }
      end
      
      -- Execute async interactive command
      executor.execute_async("describe", function(result)
        callback_called = true
        callback_result = result
      end)
      
      -- No need to wait - callback should be called immediately in test
      
      assert.is_true(callback_called)
      assert.is_not_nil(callback_result)
      assert.is_true(callback_result.success) -- Should succeed via fallback
      assert.is_true(callback_result.fallback)
      
      -- Restore original
      terminal_manager.create_terminal_window = original_create
    end)
  end)

  describe("command completion handling", function()
    it("should trigger auto-refresh after interactive command completion", function()
      local auto_refresh_called = false
      local auto_refresh_command = nil
      local auto_refresh_success = nil
      
      -- Mock auto-refresh module
      package.loaded["jj.auto_refresh"] = {
        on_command_complete = function(command, success, output)
          auto_refresh_called = true
          auto_refresh_command = command
          auto_refresh_success = success
        end
      }
      
      local terminal_callback = nil
      
      -- Mock terminal manager
      local original_create = terminal_manager.create_terminal_window
      terminal_manager.create_terminal_window = function(command, config, callback)
        terminal_callback = callback
        return {
          buffer_id = 100,
          window_id = 200,
          job_id = 300
        }
      end
      
      -- Execute interactive command
      executor.execute_jj_command("describe")
      
      -- Simulate successful terminal completion
      if terminal_callback then
        terminal_callback(0) -- Success exit code
      end
      
      assert.is_true(auto_refresh_called)
      assert.are.equal("describe", auto_refresh_command)
      assert.is_true(auto_refresh_success)
      
      -- Restore original
      terminal_manager.create_terminal_window = original_create
      package.loaded["jj.auto_refresh"] = nil
    end)
    
    it("should handle command failure correctly", function()
      local auto_refresh_called = false
      local auto_refresh_success = nil
      
      -- Mock auto-refresh module
      package.loaded["jj.auto_refresh"] = {
        on_command_complete = function(command, success, output)
          auto_refresh_called = true
          auto_refresh_success = success
        end
      }
      
      local terminal_callback = nil
      
      -- Mock terminal manager
      local original_create = terminal_manager.create_terminal_window
      terminal_manager.create_terminal_window = function(command, config, callback)
        terminal_callback = callback
        return {
          buffer_id = 100,
          window_id = 200,
          job_id = 300
        }
      end
      
      -- Execute interactive command
      executor.execute_jj_command("describe")
      
      -- Simulate failed terminal completion
      if terminal_callback then
        terminal_callback(1) -- Error exit code
      end
      
      assert.is_true(auto_refresh_called)
      assert.is_false(auto_refresh_success)
      
      -- Restore original
      terminal_manager.create_terminal_window = original_create
      package.loaded["jj.auto_refresh"] = nil
    end)
  end)
end)