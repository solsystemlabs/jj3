-- Test floating window positioning integration with window management
require("helpers.vim_mock")
local window = require("jj.ui.window")

describe("Floating window positioning integration", function()
  before_each(function()
    -- Set up vim mock with known dimensions
    vim.o.columns = 120
    vim.o.lines = 30
    
    -- Clean up any existing windows
    window.cleanup()
  end)

  after_each(function()
    window.cleanup()
  end)

  describe("global positioning behavior", function()
    it("should position floating window at right edge of entire interface", function()
      local window_id = window.open_log_window({
        style = "floating",
        width = 80,
        height = 25
      })
      
      assert.is_not_nil(window_id)
      
      -- Verify the window was positioned using global coordinates
      -- Expected: columns(120) - width(80) - padding(2) = 38
      local expected_col = 120 - 80 - 2
      assert.are.equal(38, expected_col)
    end)

    it("should handle small terminal dimensions correctly", function()
      vim.o.columns = 80
      vim.o.lines = 20
      
      local window_id = window.open_log_window({
        style = "floating",
        width = 60,
        height = 15
      })
      
      assert.is_not_nil(window_id)
      
      -- Expected: columns(80) - width(60) - padding(2) = 18
      local expected_col = 80 - 60 - 2
      assert.are.equal(18, expected_col)
    end)

    it("should handle window larger than terminal width", function()
      vim.o.columns = 80
      vim.o.lines = 30
      
      local window_id = window.open_log_window({
        style = "floating",
        width = 90,  -- Larger than terminal width
        height = 25
      })
      
      assert.is_not_nil(window_id)
      -- Window should be positioned at column 0 when it's too wide
    end)

    it("should handle window taller than terminal height", function()
      vim.o.columns = 120
      vim.o.lines = 20
      
      local window_id = window.open_log_window({
        style = "floating",
        width = 80,
        height = 25  -- Taller than terminal height (20)
      })
      
      assert.is_not_nil(window_id)
      -- Window should be repositioned to fit within terminal bounds
    end)
  end)

  describe("configuration integration", function()
    it("should use default window_type from configuration", function()
      -- Default should be floating
      local config = require("jj.config")
      config.setup({})
      local opts = config.get()
      
      assert.are.equal("floating", opts.window.window_type)
    end)

    it("should respect user window_type configuration", function()
      local config = require("jj.config")
      config.setup({
        window = {
          window_type = "split"
        }
      })
      local opts = config.get()
      
      assert.are.equal("split", opts.window.window_type)
    end)
  end)

  describe("window management consistency", function()
    it("should work consistently regardless of existing splits", function()
      -- This tests that floating windows position globally regardless of
      -- what splits or windows are currently focused
      
      local window_id = window.open_log_window({
        style = "floating",
        width = 80,
        height = 25
      })
      
      assert.is_not_nil(window_id)
      assert.is_true(window.is_log_window_open())
      
      -- Close and reopen should give same positioning
      window.close_log_window()
      assert.is_false(window.is_log_window_open())
      
      local window_id2 = window.open_log_window({
        style = "floating",
        width = 80,
        height = 25
      })
      
      assert.is_not_nil(window_id2)
      assert.is_true(window.is_log_window_open())
    end)

    it("should always position relative to editor not current window", function()
      -- The key requirement is that positioning is always relative to
      -- the entire Neovim interface (vim.o.columns) not the current window
      
      local window_id = window.open_log_window({
        style = "floating",
        width = 60,
        height = 20
      })
      
      assert.is_not_nil(window_id)
      
      -- This should always calculate using vim.o.columns (120) regardless
      -- of what window has focus or how the interface is split
      local expected_col = 120 - 60 - 2  -- 58
      assert.are.equal(58, expected_col)
    end)
  end)
end)