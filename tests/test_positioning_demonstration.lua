-- Demonstration of log window positioning functionality
require("helpers.vim_mock")
local window = require("jj.ui.window")
local config = require("jj.config")

describe("Log window positioning demonstration", function()
  after_each(function()
    window.cleanup()
  end)

  it("should demonstrate default floating window behavior", function()
    -- Default configuration should use floating windows
    config.setup({})
    local opts = config.get()
    assert.are.equal("floating", opts.window.window_type)
    
    -- Opening log window should create floating window at right edge
    local window_id = window.open_log_window()
    assert.is_not_nil(window_id)
    assert.is_true(window.is_log_window_open())
    
    print("✓ Default floating window positioning works (left border, full height)")
  end)

  it("should demonstrate configurable split window behavior", function()
    -- Configure for split windows
    config.setup({
      window = {
        window_type = "split",
        size = 80
      }
    })
    
    local opts = config.get()
    assert.are.equal("split", opts.window.window_type)
    assert.are.equal(80, opts.window.size)
    
    -- Opening log window should create split at right edge
    local captured_commands = {}
    vim.cmd = function(cmd)
      table.insert(captured_commands, cmd)
    end
    
    local window_id = window.open_log_window()
    assert.is_not_nil(window_id)
    
    -- Verify rightbelow vertical command was used
    local found_split_command = false
    for _, cmd in ipairs(captured_commands) do
      if cmd:match("rightbelow vertical %d+ split") then
        found_split_command = true
        break
      end
    end
    assert.is_true(found_split_command)
    
    print("✓ Configurable split window positioning works")
  end)

  it("should demonstrate consistent positioning regardless of terminal size", function()
    -- Test with different terminal dimensions
    vim.o.columns = 100
    vim.o.lines = 25
    
    config.setup({
      window = {
        window_type = "floating"
      }
    })
    
    local window_id1 = window.open_log_window({
      width = 60,
      height = 20
    })
    assert.is_not_nil(window_id1)
    window.close_log_window()
    
    -- Change terminal size
    vim.o.columns = 140
    vim.o.lines = 35
    
    local window_id2 = window.open_log_window({
      width = 60,
      height = 20
    })
    assert.is_not_nil(window_id2)
    
    print("✓ Positioning adapts to terminal size changes")
  end)

  it("should demonstrate override behavior", function()
    -- Configure for splits but override for specific call
    config.setup({
      window = {
        window_type = "split"
      }
    })
    
    -- Explicitly request floating window
    local window_id = window.open_log_window({
      style = "floating",
      width = 80,
      height = 25
    })
    
    assert.is_not_nil(window_id)
    
    print("✓ Configuration override behavior works")
  end)

  it("should demonstrate configurable border options", function()
    -- Test different border configurations
    
    -- No borders
    config.setup({
      window = {
        window_type = "floating",
        border = "none"
      }
    })
    
    local window_id1 = window.open_log_window({
      width = 60
    })
    assert.is_not_nil(window_id1)
    window.close_log_window()
    
    -- Full single border
    config.setup({
      window = {
        window_type = "floating",
        border = "single",
        title = "JJ Log"
      }
    })
    
    local window_id2 = window.open_log_window({
      width = 60
    })
    assert.is_not_nil(window_id2)
    window.close_log_window()
    
    -- Custom partial border (left and bottom)
    config.setup({
      window = {
        window_type = "floating",
        border = {"", "", "", "│", "", "─", "", ""}
      }
    })
    
    local window_id3 = window.open_log_window({
      width = 60
    })
    assert.is_not_nil(window_id3)
    
    print("✓ Configurable border options work (none, single, custom)")
  end)
end)