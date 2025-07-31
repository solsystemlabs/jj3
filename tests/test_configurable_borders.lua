-- Test configurable borders and title functionality
require("helpers.vim_mock")
local window = require("jj.ui.window")
local config = require("jj.config")

describe("Configurable borders and title", function()
  before_each(function()
    -- Reset configuration
    config.setup({})
    window.cleanup()
  end)

  after_each(function()
    window.cleanup()
  end)

  describe("default border configuration", function()
    it("should use left border only by default", function()
      local opts = config.get()
      -- Default should have left border only
      assert.are.same({"", "", "", "│", "", "", "", ""}, opts.window.border)
      assert.is_nil(opts.window.title)
    end)

    it("should apply default left border to floating window", function()
      local window_id = window.open_log_window({
        style = "floating",
        width = 80
      })
      
      assert.is_not_nil(window_id)
      assert.is_true(window.is_log_window_open())
    end)
  end)

  describe("custom border configuration", function()
    it("should allow no borders", function()
      config.setup({
        window = {
          border = "none"
        }
      })
      
      local window_id = window.open_log_window({
        style = "floating",
        width = 80
      })
      
      assert.is_not_nil(window_id)
    end)

    it("should allow full borders", function()
      config.setup({
        window = {
          border = "single"
        }
      })
      
      local window_id = window.open_log_window({
        style = "floating",
        width = 80
      })
      
      assert.is_not_nil(window_id)
    end)

    it("should allow custom border array", function()
      config.setup({
        window = {
          border = {"┌", "─", "┐", "│", "┘", "─", "└", "│"}
        }
      })
      
      local window_id = window.open_log_window({
        style = "floating",
        width = 80
      })
      
      assert.is_not_nil(window_id)
    end)

    it("should allow partial borders", function()
      config.setup({
        window = {
          border = {"", "", "", "│", "", "─", "", ""}  -- Left and bottom only
        }
      })
      
      local window_id = window.open_log_window({
        style = "floating",
        width = 80
      })
      
      assert.is_not_nil(window_id)
    end)
  end)

  describe("title configuration", function()
    it("should allow custom title", function()
      config.setup({
        window = {
          title = "JJ Log",
          title_pos = "left"
        }
      })
      
      local opts = config.get()
      assert.are.equal("JJ Log", opts.window.title)
      assert.are.equal("left", opts.window.title_pos)
      
      local window_id = window.open_log_window({
        style = "floating",
        width = 80
      })
      
      assert.is_not_nil(window_id)
    end)

    it("should handle nil title correctly", function()
      config.setup({
        window = {
          title = nil  -- Explicitly no title
        }
      })
      
      local opts = config.get()
      assert.is_nil(opts.window.title)
      
      local window_id = window.open_log_window({
        style = "floating",
        width = 80
      })
      
      assert.is_not_nil(window_id)
    end)

    it("should support different title positions", function()
      config.setup({
        window = {
          title = "Repository Log",
          title_pos = "right"
        }
      })
      
      local window_id = window.open_log_window({
        style = "floating",
        width = 80
      })
      
      assert.is_not_nil(window_id)
    end)
  end)

  describe("configuration override", function()
    it("should allow runtime override of border config", function()
      config.setup({
        window = {
          border = {"", "", "", "│", "", "", "", ""}  -- Left only
        }
      })
      
      -- Override with user config
      local window_id = window.open_log_window({
        style = "floating",
        width = 80,
        border = "double"  -- Override to double border
      })
      
      assert.is_not_nil(window_id)
    end)

    it("should allow runtime override of title config", function()
      config.setup({
        window = {
          title = "Default Title"
        }
      })
      
      -- Override with user config
      local window_id = window.open_log_window({
        style = "floating",
        width = 80,
        title = "Custom Title"
      })
      
      assert.is_not_nil(window_id)
    end)
  end)

  describe("integration with existing functionality", function()
    it("should work with split windows (borders ignored)", function()
      config.setup({
        window = {
          window_type = "split",
          border = "single"  -- Should be ignored for splits
        }
      })
      
      local captured_commands = {}
      vim.cmd = function(cmd)
        table.insert(captured_commands, cmd)
      end
      
      local window_id = window.open_log_window()
      assert.is_not_nil(window_id)
      
      -- Should still create split (border config doesn't affect splits)
      local found_split_command = false
      for _, cmd in ipairs(captured_commands) do
        if cmd:match("rightbelow vertical %d+ split") then
          found_split_command = true
          break
        end
      end
      assert.is_true(found_split_command)
    end)

    it("should preserve other window configuration", function()
      config.setup({
        window = {
          window_type = "floating",
          size = 90,
          border = "single",
          title = "JJ3"
        }
      })
      
      local window_id = window.open_log_window()
      assert.is_not_nil(window_id)
      
      -- Should use configured size and other options
      local opts = config.get()
      assert.are.equal(90, opts.window.size)
      assert.are.equal("single", opts.window.border)
      assert.are.equal("JJ3", opts.window.title)
    end)
  end)
end)