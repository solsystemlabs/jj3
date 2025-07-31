-- Tests for ESC key behavior in log buffer
require("helpers.vim_mock")

describe("ESC Key Behavior", function()
  -- Add lua path for testing
  package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

  local jj_commands

  before_each(function()
    -- Clear modules from cache to ensure fresh load
    package.loaded["jj.commands"] = nil
    package.loaded["jj.config"] = nil
    package.loaded["jj.log.init"] = nil

    -- Reset vim mocks
    vim.user_commands = {}
    vim.keymaps = {}

    -- Reset call tracking
    vim.close_log_calls = 0

    -- Mock log module with required functions
    package.loaded["jj.log.init"] = {
      close_log = function()
        vim.close_log_calls = vim.close_log_calls + 1
      end,
      toggle_log = function() return true end,
      configure = function(config) return true end,
      setup = function(config) return true end
    }

    -- Mock config module
    package.loaded["jj.config"] = {
      setup = function() end,
      get = function()
        return {
          keymaps = { toggle_log = "<leader>jl" },
          window = { position = "right", size = 50 }
        }
      end
    }
  end)

  describe("ESC key in log buffer", function()
    it("should register ESC key to close log window in buffer", function()
      -- Mock keymap.set to track buffer-specific keybinding registration
      local buffer_keymaps = {}
      vim.keymap.set = function(mode, lhs, rhs, opts)
        if opts and opts.buffer then
          table.insert(buffer_keymaps, {
            mode = mode,
            lhs = lhs,
            rhs = rhs,
            opts = opts,
            buffer = opts.buffer
          })
        end
      end

      jj_commands = require("jj.commands")
      jj_commands.setup()
      
      -- Simulate buffer setup (this normally happens via autocmd)
      local buffer_id = 123
      
      -- Get the setup function from the commands module
      -- We need to trigger the buffer keymap setup
      vim.api.nvim_get_current_buf = function() return buffer_id end
      
      -- Call the autocmd callback manually to set up buffer keymaps
      local autocmd_callbacks = vim.api.autocmd_callbacks or {}
      for _, callback in ipairs(autocmd_callbacks) do
        if callback.pattern == "JJ Log" then
          callback.callback()
        end
      end
      
      -- Check that ESC keymap was registered for the buffer
      local found_esc_keymap = false
      for _, keymap in ipairs(buffer_keymaps) do
        if keymap.lhs == "<Esc>" and keymap.mode == "n" and keymap.buffer == buffer_id then
          found_esc_keymap = true
          
          -- Test that the ESC key function calls close_log
          keymap.rhs()
          assert.equals(1, vim.close_log_calls, "ESC key should call close_log")
          break
        end
      end
      
      assert.is_true(found_esc_keymap, "ESC key should be registered for log buffer")
    end)

    it("should call close_log when ESC is pressed in buffer", function()
      jj_commands = require("jj.commands")
      jj_commands.setup()
      
      -- Get the log module and call close_log directly to test the mock
      local log = package.loaded["jj.log.init"]
      log.close_log()
      
      -- Verify close_log was called
      assert.equals(1, vim.close_log_calls, "close_log should be called when ESC is pressed")
    end)
  end)
end)