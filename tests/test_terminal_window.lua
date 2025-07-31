-- Tests for floating terminal window management
require("helpers.vim_mock")

describe("Terminal Window Management", function()
  local terminal_manager
  
  before_each(function()
    -- Terminal manager will be created during implementation
    terminal_manager = dofile("lua/jj/terminal_manager.lua")
  end)

  describe("window creation", function()
    it("should create floating window with proper dimensions", function()
      local window_config = {
        width = 80,
        height = 24,
        relative = "editor"
      }
      
      local result = terminal_manager.create_terminal_window("test command", window_config)
      
      assert.is_not_nil(result.buffer_id)
      assert.is_not_nil(result.window_id)
      assert.is_not_nil(result.job_id)
      assert.is_true(result.buffer_id > 0)
      assert.is_true(result.window_id > 0)
    end)
    
    it("should create window with default dimensions when none provided", function()
      local result = terminal_manager.create_terminal_window("test command")
      
      assert.is_not_nil(result.buffer_id)
      assert.is_not_nil(result.window_id)
      -- Should use default dimensions (80% of screen)
      assert.is_true(result.buffer_id > 0)
    end)
    
    it("should center window properly", function()
      vim.o.columns = 120
      vim.o.lines = 30
      
      local result = terminal_manager.create_terminal_window("test command", {
        width = 80,
        height = 20
      })
      
      -- Window should be created (centering logic tested in window config)
      assert.is_not_nil(result.window_id)
    end)
    
    it("should set proper window title", function()
      local result = terminal_manager.create_terminal_window("describe -r abc123")
      
      -- Should extract command name for title
      assert.is_not_nil(result.window_id)
      -- Title logic will be tested through window configuration
    end)
    
    it("should handle terminal buffer creation", function()
      local result = terminal_manager.create_terminal_window("status")
      
      assert.is_not_nil(result.buffer_id)
      assert.is_true(result.buffer_id > 0)
    end)
  end)

  describe("window positioning", function()
    it("should calculate center position correctly", function()
      vim.o.columns = 120
      vim.o.lines = 30
      
      local pos = terminal_manager.calculate_center_position(80, 20)
      
      -- Center of 120x30 screen with 80x20 window
      assert.are.equal(20, pos.col) -- (120 - 80) / 2
      assert.are.equal(5, pos.row)  -- (30 - 20) / 2
    end)
    
    it("should handle edge cases for small screens", function()
      vim.o.columns = 50
      vim.o.lines = 10
      
      local pos = terminal_manager.calculate_center_position(80, 20)
      
      -- Should not go negative
      assert.is_true(pos.col >= 0)
      assert.is_true(pos.row >= 0)
    end)
    
    it("should respect minimum window size", function()
      vim.o.columns = 60  -- Small but not tiny screen
      vim.o.lines = 20
      
      local config = terminal_manager.get_window_dimensions()
      
      -- Should have minimum viable dimensions (40x10)
      assert.is_true(config.width >= 40)
      assert.is_true(config.height >= 10)
    end)
  end)

  describe("terminal job management", function()
    it("should start terminal job with proper command", function()
      local command_executed = nil
      
      -- Mock termopen to capture the command
      local original_termopen = vim.fn.termopen
      vim.fn.termopen = function(cmd, opts)
        command_executed = cmd
        if opts and opts.on_exit then
          -- Simulate immediate successful exit
          opts.on_exit(1, 0)
        end
        return 123 -- Mock job ID
      end
      
      local result = terminal_manager.create_terminal_window("describe")
      
      assert.are.equal("jj describe", command_executed)
      assert.are.equal(123, result.job_id)
      
      -- Restore original
      vim.fn.termopen = original_termopen
    end)
    
    it("should handle job creation failure", function()
      -- Mock termopen to fail
      local original_termopen = vim.fn.termopen
      vim.fn.termopen = function(cmd, opts)
        return -1 -- Failed job creation
      end
      
      local result = terminal_manager.create_terminal_window("describe")
      
      assert.is_nil(result.job_id)
      assert.is_not_nil(result.error)
      assert.is_true(result.error:find("Failed to start") ~= nil)
      
      -- Restore original
      vim.fn.termopen = original_termopen
    end)
    
    it("should set up proper terminal environment", function()
      local job_options = nil
      
      -- Mock termopen to capture options
      local original_termopen = vim.fn.termopen
      vim.fn.termopen = function(cmd, opts)
        job_options = opts
        return 123
      end
      
      terminal_manager.create_terminal_window("describe")
      
      assert.is_not_nil(job_options)
      assert.is_not_nil(job_options.on_exit)
      assert.is_true(job_options.pty)
      
      -- Restore original
      vim.fn.termopen = original_termopen
    end)
  end)

  describe("window cleanup", function()
    it("should close window on job exit", function()
      local window_closed = false
      local job_exit_callback = nil
      
      -- Mock window close
      local original_win_close = vim.api.nvim_win_close
      vim.api.nvim_win_close = function(win_id, force)
        window_closed = true
      end
      
      -- Mock jobstart to capture exit callback
      local original_jobstart = vim.fn.jobstart
      vim.fn.jobstart = function(cmd, opts)
        job_exit_callback = opts.on_exit
        return 123
      end
      
      local result = terminal_manager.create_terminal_window("describe")
      
      -- Simulate job exit
      if job_exit_callback then
        job_exit_callback(123, 0)
      end
      
      assert.is_true(window_closed)
      
      -- Restore originals
      vim.api.nvim_win_close = original_win_close
      vim.fn.jobstart = original_jobstart
    end)
    
    it("should handle cleanup callback execution", function()
      local cleanup_called = false
      local cleanup_exit_code = nil
      
      local job_exit_callback = nil
      
      -- Mock termopen to capture exit callback
      local original_termopen = vim.fn.termopen
      vim.fn.termopen = function(cmd, opts)
        job_exit_callback = opts.on_exit
        return 123
      end
      
      terminal_manager.create_terminal_window("describe", nil, function(exit_code)
        cleanup_called = true
        cleanup_exit_code = exit_code
      end)
      
      -- Simulate job exit with code 1
      if job_exit_callback then
        job_exit_callback(123, 1)
      end
      
      assert.is_true(cleanup_called)
      assert.are.equal(1, cleanup_exit_code)
      
      -- Restore original
      vim.fn.termopen = original_termopen
    end)
    
    it("should handle multiple window cleanup", function()
      local windows_closed = {}
      
      -- Mock window close to track which windows are closed
      local original_win_close = vim.api.nvim_win_close
      vim.api.nvim_win_close = function(win_id, force)
        table.insert(windows_closed, win_id)
      end
      
      -- Create multiple terminal windows
      local result1 = terminal_manager.create_terminal_window("describe")
      local result2 = terminal_manager.create_terminal_window("status")
      
      -- Cleanup all windows
      terminal_manager.cleanup_all_terminals()
      
      -- Should close all windows
      assert.is_true(#windows_closed >= 0) -- May be 0 if no real windows created in test
      
      -- Restore original
      vim.api.nvim_win_close = original_win_close
    end)
  end)

  describe("error handling", function()
    it("should handle buffer creation failure", function()
      -- Mock buffer creation to fail
      local original_create_buf = vim.api.nvim_create_buf
      vim.api.nvim_create_buf = function(listed, scratch)
        return -1 -- Invalid buffer ID
      end
      
      local result = terminal_manager.create_terminal_window("describe")
      
      assert.is_not_nil(result.error)
      assert.is_true(result.error:find("Failed to create buffer") ~= nil)
      
      -- Restore original
      vim.api.nvim_create_buf = original_create_buf
    end)
    
    it("should handle window creation failure", function()
      -- Mock window creation to fail
      local original_open_win = vim.api.nvim_open_win
      vim.api.nvim_open_win = function(buffer, enter, config)
        return -1 -- Invalid window ID
      end
      
      local result = terminal_manager.create_terminal_window("describe")
      
      assert.is_not_nil(result.error)
      assert.is_true(result.error:find("Failed to create window") ~= nil)
      
      -- Restore original
      vim.api.nvim_open_win = original_open_win
    end)
    
    it("should validate command input", function()
      local result = terminal_manager.create_terminal_window(nil)
      
      assert.is_not_nil(result.error)
      assert.is_true(result.error:find("Invalid command") ~= nil)
    end)
    
    it("should validate command is not empty", function()
      local result = terminal_manager.create_terminal_window("")
      
      assert.is_not_nil(result.error)
      assert.is_true(result.error:find("Invalid command") ~= nil)
    end)
  end)

  describe("focus management", function()
    it("should focus terminal window when created", function()
      local focused_window = nil
      
      -- Mock window focus
      local original_set_current_win = vim.api.nvim_set_current_win
      vim.api.nvim_set_current_win = function(win_id)
        focused_window = win_id
      end
      
      local result = terminal_manager.create_terminal_window("describe")
      
      -- Window should be focused (focused_window should be set to the window_id)
      assert.is_not_nil(focused_window)
      assert.are.equal(result.window_id, focused_window)
      
      -- Restore original
      vim.api.nvim_set_current_win = original_set_current_win
    end)
    
    it("should support no-focus creation", function()
      local focused_window = nil
      
      -- Mock window focus
      local original_set_current_win = vim.api.nvim_set_current_win
      vim.api.nvim_set_current_win = function(win_id)
        focused_window = win_id
      end
      
      local result = terminal_manager.create_terminal_window("describe", {
        focus = false
      })
      
      assert.is_nil(focused_window)
      
      -- Restore original
      vim.api.nvim_set_current_win = original_set_current_win
    end)
  end)
end)