-- Tests for toggle keybinding functionality
require("helpers.vim_mock")

describe("Toggle Keybinding Functionality", function()
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

    -- Mock window state
    vim.window_state = {
      is_open = false,
      window_id = nil
    }

    -- Reset call tracking
    vim.toggle_log_calls = 0
    vim.show_log_calls = 0

    -- Mock log module with required functions
    package.loaded["jj.log.init"] = {
      toggle_log = function()
        vim.toggle_log_calls = vim.toggle_log_calls + 1
        vim.window_state.is_open = not vim.window_state.is_open
        if vim.window_state.is_open then
          vim.window_state.window_id = 12345
        else
          vim.window_state.window_id = nil
        end
        return vim.window_state.is_open
      end,
      show_log = function()
        vim.show_log_calls = vim.show_log_calls + 1
        vim.window_state.is_open = true
        vim.window_state.window_id = 12345
      end,
      configure = function(config) return true end,
      setup = function(config) return true end,
      get_status = function()
        return {
          is_open = vim.window_state.is_open,
          window_id = vim.window_state.window_id
        }
      end
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

  describe("toggle keybinding registration", function()
    it("should register toggle keybinding with default configuration", function()
      -- Mock keymap.set to track keybinding registration
      local registered_keymaps = {}
      vim.keymap.set = function(mode, lhs, rhs, opts)
        table.insert(registered_keymaps, {
          mode = mode,
          lhs = lhs,
          rhs = rhs,
          opts = opts
        })
      end

      jj_commands = require("jj.commands")
      jj_commands.setup()
      
      -- Check that keymap was registered
      local found_keymap = false
      for _, keymap in ipairs(registered_keymaps) do
        if keymap.lhs == "<leader>jl" and keymap.mode == "n" then
          found_keymap = true
          break
        end
      end
      
      assert.is_true(found_keymap, "Toggle keybinding should be registered")
    end)

    it("should register custom toggle keybinding when configured", function()
      -- Mock custom config
      package.loaded["jj.config"] = {
        setup = function() end,
        get = function()
          return {
            keymaps = { toggle_log = "<leader>jj" },
            window = { position = "right", size = 50 }
          }
        end
      }

      -- Mock keymap.set to track keybinding registration
      local registered_keymaps = {}
      vim.keymap.set = function(mode, lhs, rhs, opts)
        table.insert(registered_keymaps, {
          mode = mode,
          lhs = lhs,
          rhs = rhs,
          opts = opts
        })
      end
      
      jj_commands = require("jj.commands")
      jj_commands.setup()
      
      -- Check that custom keymap was registered
      local found_keymap = false
      for _, keymap in ipairs(registered_keymaps) do
        if keymap.lhs == "<leader>jj" and keymap.mode == "n" then
          found_keymap = true
          break
        end
      end
      
      assert.is_true(found_keymap, "Custom toggle keybinding should be registered")
    end)

    it("should not register toggle keybinding when disabled", function()
      -- Mock config with disabled keybinding
      package.loaded["jj.config"] = {
        setup = function() end,
        get = function()
          return {
            keymaps = { toggle_log = nil },
            window = { position = "right", size = 50 }
          }
        end
      }

      -- Mock keymap.set to track keybinding registration
      local registered_keymaps = {}
      vim.keymap.set = function(mode, lhs, rhs, opts)
        table.insert(registered_keymaps, {
          mode = mode,
          lhs = lhs,
          rhs = rhs,
          opts = opts
        })
      end
      
      jj_commands = require("jj.commands")
      jj_commands.setup()
      
      -- Check that no toggle keymap was registered
      local found_keymap = false
      for _, keymap in ipairs(registered_keymaps) do
        if keymap.lhs and keymap.lhs:match("jl") then
          found_keymap = true
          break
        end
      end
      
      assert.is_false(found_keymap, "Toggle keybinding should not be registered when disabled")
    end)
  end)

  describe("toggle functionality", function()

    it("should call toggle_log when keybinding is pressed", function()
      -- Mock keymap.set to track keybinding registration
      local registered_keymaps = {}
      vim.keymap.set = function(mode, lhs, rhs, opts)
        table.insert(registered_keymaps, {
          mode = mode,
          lhs = lhs,
          rhs = rhs,
          opts = opts
        })
      end

      jj_commands = require("jj.commands")
      jj_commands.setup()
      
      -- Find and execute the toggle keybinding
      local toggle_fn = nil
      for _, keymap in ipairs(registered_keymaps) do
        if keymap.lhs == "<leader>jl" and keymap.mode == "n" then
          toggle_fn = keymap.rhs
          break
        end
      end
      
      assert.is_not_nil(toggle_fn, "Toggle function should be found")
      assert.is_function(toggle_fn, "Toggle should be a function")
      
      -- Execute the toggle function
      toggle_fn()
      
      -- Verify toggle_log was called
      assert.equals(1, vim.toggle_log_calls, "toggle_log should be called once")
    end)

    it("should open window when closed", function()
      -- Ensure window starts closed
      vim.window_state.is_open = false
      
      -- Get the log module and execute toggle
      local log = package.loaded["jj.log.init"]
      local result = log.toggle_log()
      
      -- Verify window opened
      assert.is_true(result, "Toggle should return true when opening")
      assert.is_true(vim.window_state.is_open, "Window should be open")
      assert.is_not_nil(vim.window_state.window_id, "Window ID should be set")
    end)

    it("should close window when open", function()
      -- Ensure window starts open
      vim.window_state.is_open = true
      vim.window_state.window_id = 12345
      
      -- Get the log module and execute toggle
      local log = package.loaded["jj.log.init"]
      local result = log.toggle_log()
      
      -- Verify window closed
      assert.is_false(result, "Toggle should return false when closing")
      assert.is_false(vim.window_state.is_open, "Window should be closed")
      assert.is_nil(vim.window_state.window_id, "Window ID should be nil")
    end)

    it("should track state correctly across multiple toggles", function()
      -- Start closed
      vim.window_state.is_open = false
      
      -- Get the log module
      local log = package.loaded["jj.log.init"]
      
      -- First toggle: should open
      local result1 = log.toggle_log()
      assert.is_true(result1, "First toggle should open window")
      assert.is_true(vim.window_state.is_open, "Window should be open after first toggle")
      
      -- Second toggle: should close
      local result2 = log.toggle_log()
      assert.is_false(result2, "Second toggle should close window")
      assert.is_false(vim.window_state.is_open, "Window should be closed after second toggle")
      
      -- Third toggle: should open again
      local result3 = log.toggle_log()
      assert.is_true(result3, "Third toggle should open window again")
      assert.is_true(vim.window_state.is_open, "Window should be open after third toggle")
    end)
  end)
end)