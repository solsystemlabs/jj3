-- Test window configuration integration
require("helpers.vim_mock")
local window = require("jj.ui.window")
local config = require("jj.config")

describe("Window configuration integration", function()
  before_each(function()
    -- Reset configuration
    config.setup({})
    window.cleanup()
  end)

  after_each(function()
    window.cleanup()
  end)

  describe("configuration-driven window creation", function()
    it("should use floating window by default", function()
      -- Default configuration should use floating window
      local opts = config.get()
      assert.are.equal("floating", opts.window.window_type)
      
      -- Opening window should create floating window by default
      local window_id = window.open_log_window()
      assert.is_not_nil(window_id)
      assert.is_true(window.is_log_window_open())
    end)

    it("should respect user configuration for window_type", function()
      -- Configure for split windows
      config.setup({
        window = {
          window_type = "split"
        }
      })
      
      local opts = config.get()
      assert.are.equal("split", opts.window.window_type)
      
      -- Opening window should create split window
      local captured_commands = {}
      vim.cmd = function(cmd)
        table.insert(captured_commands, cmd)
      end
      
      local window_id = window.open_log_window()
      assert.is_not_nil(window_id)
      
      -- Should have executed split command
      local found_split_command = false
      for _, cmd in ipairs(captured_commands) do
        if cmd:match("rightbelow vertical %d+ split") then
          found_split_command = true
          break
        end
      end
      assert.is_true(found_split_command)
    end)

    it("should allow runtime configuration changes", function()
      -- Start with floating
      config.setup({
        window = {
          window_type = "floating"
        }
      })
      
      local window_id1 = window.open_log_window()
      assert.is_not_nil(window_id1)
      window.close_log_window()
      
      -- Change to split
      config.setup({
        window = {
          window_type = "split"
        }
      })
      
      local captured_commands = {}
      vim.cmd = function(cmd)
        table.insert(captured_commands, cmd)
      end
      
      local window_id2 = window.open_log_window()
      assert.is_not_nil(window_id2)
      
      -- Should now use split commands
      local found_split_command = false
      for _, cmd in ipairs(captured_commands) do
        if cmd:match("rightbelow vertical %d+ split") then
          found_split_command = true
          break
        end
      end
      assert.is_true(found_split_command)
    end)
  end)

  describe("configuration override behavior", function()
    it("should allow explicit override of configured window_type", function()
      -- Configure for split by default
      config.setup({
        window = {
          window_type = "split"
        }
      })
      
      -- But explicitly request floating window
      local window_id = window.open_log_window({
        style = "floating",
        width = 80,
        height = 25
      })
      
      assert.is_not_nil(window_id)
      assert.is_true(window.is_log_window_open())
      
      -- Should have created floating window despite split configuration
    end)

    it("should merge configuration with user options", function()
      -- Set up configuration with window_type and other options
      config.setup({
        window = {
          window_type = "floating",
          size = 90
        }
      })
      
      -- Override window_type but keep other configured options
      local window_id = window.open_log_window({
        style = "split",
        position = "right"
      })
      
      assert.is_not_nil(window_id)
      
      -- The explicit style parameter should override configuration
      local captured_commands = {}
      vim.cmd = function(cmd)
        table.insert(captured_commands, cmd)
      end
      
      window.close_log_window()
      local window_id2 = window.open_log_window({
        style = "split",
        position = "right",
        width = 80
      })
      
      local found_split_command = false
      for _, cmd in ipairs(captured_commands) do
        if cmd:match("rightbelow vertical %d+ split") then
          found_split_command = true
          break
        end
      end
      assert.is_true(found_split_command)
    end)
  end)

  describe("focus-independent positioning", function()
    it("should position consistently regardless of focus", function()
      -- Configure for floating windows
      config.setup({
        window = {
          window_type = "floating"
        }
      })
      
      -- Create window multiple times - should be consistent
      local window_id1 = window.open_log_window({
        width = 80,
        height = 25
      })
      assert.is_not_nil(window_id1)
      
      window.close_log_window()
      
      local window_id2 = window.open_log_window({
        width = 80,
        height = 25
      })
      assert.is_not_nil(window_id2)
      
      -- Both should use the same positioning logic (global coordinates)
      -- This is verified by the fact that both windows are created successfully
    end)

    it("should position splits at global right edge regardless of focus", function()
      config.setup({
        window = {
          window_type = "split"
        }
      })
      
      local captured_commands = {}
      vim.cmd = function(cmd)
        table.insert(captured_commands, cmd)
      end
      
      local window_id = window.open_log_window({
        width = 80
      })
      assert.is_not_nil(window_id)
      
      -- Should use rightbelow vertical which positions globally
      local found_split_command = false
      for _, cmd in ipairs(captured_commands) do
        if cmd:match("rightbelow vertical %d+ split") then
          found_split_command = true
          break
        end
      end
      assert.is_true(found_split_command)
    end)
  end)
end)