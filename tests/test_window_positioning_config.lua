-- Test window positioning configuration
require("helpers.vim_mock")
local config = require("jj.config")

describe("Window positioning configuration", function()
  before_each(function()
    -- Reset config to defaults before each test
    config.setup({})
  end)

  describe("window_type configuration option", function()
    it("should default to floating when not specified", function()
      local opts = config.get()
      assert.are.equal("floating", opts.window.window_type)
    end)

    it("should accept floating as valid window_type", function()
      config.setup({
        window = {
          window_type = "floating"
        }
      })
      local opts = config.get()
      assert.are.equal("floating", opts.window.window_type)
    end)

    it("should accept split as valid window_type", function()
      config.setup({
        window = {
          window_type = "split"
        }
      })
      local opts = config.get()
      assert.are.equal("split", opts.window.window_type)
    end)

    it("should reject invalid window_type values", function()
      config.setup({
        window = {
          window_type = "invalid"
        }
      })
      local opts = config.get()
      -- Should fall back to default
      assert.are.equal("floating", opts.window.window_type)
    end)

    it("should handle nil window_type gracefully", function()
      config.setup({
        window = {
          window_type = nil
        }
      })
      local opts = config.get()
      assert.are.equal("floating", opts.window.window_type)
    end)
  end)

  describe("configuration validation", function()
    it("should preserve other window options when setting window_type", function()
      config.setup({
        window = {
          window_type = "split",
          position = "left",
          size = 60
        }
      })
      local opts = config.get()
      assert.are.equal("split", opts.window.window_type)
      assert.are.equal("left", opts.window.position)
      assert.are.equal(60, opts.window.size)
    end)

    it("should merge with existing defaults properly", function()
      config.setup({
        window = {
          window_type = "floating"
        }
      })
      local opts = config.get()
      -- Should preserve default values
      assert.are.equal("floating", opts.window.window_type)
      assert.are.equal("right", opts.window.position)
      assert.are.equal(50, opts.window.size)
    end)
  end)
end)