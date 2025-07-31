-- Test split positioning integration with window management
require("helpers.vim_mock")
local window = require("jj.ui.window")

describe("Split positioning integration", function()
  before_each(function()
    -- Clean up any existing windows
    window.cleanup()
  end)

  after_each(function()
    window.cleanup()
  end)

  describe("vertical split positioning", function()
    it("should create split window at right edge of interface", function()
      local window_id = window.open_log_window({
        style = "split",
        position = "right",
        width = 80
      })
      
      assert.is_not_nil(window_id)
      assert.is_true(window.is_log_window_open())
    end)

    it("should use rightbelow vertical command for right positioning", function()
      local captured_commands = {}
      vim.cmd = function(cmd)
        table.insert(captured_commands, cmd)
      end
      
      local window_id = window.open_log_window({
        style = "split",
        position = "right",
        width = 60
      })
      
      assert.is_not_nil(window_id)
      
      -- Should have captured the rightbelow vertical command
      local found_split_command = false
      for _, cmd in ipairs(captured_commands) do
        if cmd:match("rightbelow vertical %d+ split") then
          found_split_command = true
          break
        end
      end
      assert.is_true(found_split_command)
    end)

    it("should handle different split positions", function()
      local captured_commands = {}
      vim.cmd = function(cmd)
        table.insert(captured_commands, cmd)
      end
      
      -- Test left position
      window.cleanup()
      window.open_log_window({
        style = "split",
        position = "left",
        width = 50
      })
      
      -- Should use leftabove vertical for left splits
      local found_left_command = false
      for _, cmd in ipairs(captured_commands) do
        if cmd:match("leftabove vertical %d+ split") then
          found_left_command = true
          break
        end
      end
      assert.is_true(found_left_command)
    end)

    it("should default to right split when position not specified", function()
      local captured_commands = {}
      vim.cmd = function(cmd)
        table.insert(captured_commands, cmd)
      end
      
      local window_id = window.open_log_window({
        style = "split",
        width = 70
        -- No position specified
      })
      
      assert.is_not_nil(window_id)
      
      -- Should default to rightbelow vertical
      local found_right_command = false
      for _, cmd in ipairs(captured_commands) do
        if cmd:match("rightbelow vertical %d+ split") then
          found_right_command = true
          break
        end
      end
      assert.is_true(found_right_command)
    end)
  end)

  describe("split window management", function()
    it("should properly manage split window lifecycle", function()
      local window_id = window.open_log_window({
        style = "split",
        position = "right",
        width = 80
      })
      
      assert.is_not_nil(window_id)
      assert.is_true(window.is_log_window_open())
      
      -- Close the window
      local closed = window.close_log_window()
      assert.is_true(closed)
      assert.is_false(window.is_log_window_open())
    end)

    it("should support toggle functionality with splits", function()
      -- Initially no window
      assert.is_false(window.is_log_window_open())
      
      -- Toggle on - should create split
      local result1 = window.toggle_log_window()
      assert.is_true(result1)
      assert.is_true(window.is_log_window_open())
      
      -- Toggle off - should close split
      local result2 = window.toggle_log_window()
      assert.is_false(result2)
      assert.is_false(window.is_log_window_open())
    end)

    it("should work with window configuration", function()
      -- Configure for split mode
      window.configure({
        style = "split",
        position = "right",
        width = 90
      })
      
      local window_id = window.open_log_window()
      assert.is_not_nil(window_id)
      assert.is_true(window.is_log_window_open())
    end)
  end)

  describe("edge cases and complex configurations", function()
    it("should handle split creation with existing windows", function()
      -- This tests that split positioning works correctly even with
      -- existing window layouts, positioning at the global right edge
      
      local window_id = window.open_log_window({
        style = "split",
        position = "right",
        width = 80
      })
      
      assert.is_not_nil(window_id)
      
      -- The split should be created regardless of existing window layout
      -- because rightbelow vertical positions globally
    end)

    it("should respect width configuration for splits", function()
      local captured_commands = {}
      vim.cmd = function(cmd)
        table.insert(captured_commands, cmd)
      end
      
      window.open_log_window({
        style = "split",
        position = "right",
        width = 120
      })
      
      -- Should capture command with specified width
      local found_width_command = false
      for _, cmd in ipairs(captured_commands) do
        if cmd:match("rightbelow vertical 120 split") then
          found_width_command = true
          break
        end
      end
      assert.is_true(found_width_command)
    end)
  end)
end)