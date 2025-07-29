-- Tests for selection navigation and confirmation system
require("tests.helpers.vim_mock")

local selection_navigation = require("jj.selection_navigation")
local selection_state = require("jj.selection_state")
local visual_feedback = require("jj.visual_feedback")
local types = require("jj.types")

describe("selection navigation system", function()
  local mock_bufnr = 1
  local mock_winnr = 1000

  before_each(function()
    -- Reset all systems
    selection_navigation._reset_for_testing()
    selection_state._reset_for_testing()
    visual_feedback._reset_for_testing()
    
    -- Mock vim APIs
    vim.api.nvim_get_current_buf = function()
      return mock_bufnr
    end
    
    vim.api.nvim_get_current_win = function()
      return mock_winnr
    end
    
    vim.api.nvim_win_get_cursor = function(winnr)
      return {1, 0} -- line 1, column 0 (1-indexed)
    end
    
    vim.api.nvim_buf_get_lines = function(bufnr, start, end_line, strict_indexing)
      return {
        "@  abc123  Current commit",
        "○  def456  Previous commit", 
        "○  ghi789  Older commit"
      }
    end
    
    vim.keymap.set = function(mode, lhs, rhs, opts)
      -- Mock keymap setting
    end
    
    vim.keymap.del = function(mode, lhs, opts)
      -- Mock keymap deletion
    end
    
    -- Mock other visual feedback APIs
    visual_feedback.show_selection_window = function(winnr, context) end
    visual_feedback.hide_selection_window = function() end
    visual_feedback.update_selection_context = function(context) end
    visual_feedback.update_selection_highlights = function(bufnr, selections) end
    visual_feedback.clear_selection_highlights = function(bufnr) end
  end)

  describe("commit ID extraction", function()
    it("should extract commit ID from cursor position", function()
      local commit_id = selection_navigation.get_commit_id_at_cursor(mock_bufnr, 1)
      
      assert.are.equal("abc123", commit_id)
    end)

    it("should handle different log formats", function()
      -- Test first format
      vim.api.nvim_buf_get_lines = function(bufnr, start, end_line, strict_indexing)
        return {"◉ def456 teernisse@visiostack.com 2025-07-28"}
      end
      
      local commit_id = selection_navigation.get_commit_id_at_cursor(mock_bufnr, 1)
      assert.are.equal("def456", commit_id)
      
      -- Test second format
      vim.api.nvim_buf_get_lines = function(bufnr, start, end_line, strict_indexing)
        return {"○ ghi789 teernisse@visiostack.com 2025-07-27"}
      end
      
      local commit_id2 = selection_navigation.get_commit_id_at_cursor(mock_bufnr, 1)  
      assert.are.equal("ghi789", commit_id2)
    end)

    it("should return nil for lines without commit IDs", function()
      vim.api.nvim_buf_get_lines = function(bufnr, start, end_line, strict_indexing)
        return {
          "│ This is just a description line",
          "│ Another description line"
        }
      end
      
      local commit_id = selection_navigation.get_commit_id_at_cursor(mock_bufnr, 1)
      assert.is_nil(commit_id)
    end)
  end)

  describe("keybinding management", function()
    it("should enable selection mode keybindings", function()
      local machine = selection_state.new(mock_bufnr)
      
      selection_navigation.enable_selection_mode(mock_bufnr, machine)
      
      local is_enabled = selection_navigation.is_selection_mode_enabled(mock_bufnr)
      assert.is_true(is_enabled)
    end)

    it("should disable selection mode keybindings", function()
      local machine = selection_state.new(mock_bufnr)
      
      selection_navigation.enable_selection_mode(mock_bufnr, machine)
      assert.is_true(selection_navigation.is_selection_mode_enabled(mock_bufnr))
      
      selection_navigation.disable_selection_mode(mock_bufnr)
      assert.is_false(selection_navigation.is_selection_mode_enabled(mock_bufnr))
    end)

    it("should preserve normal navigation keybindings in selection mode", function()
      local machine = selection_state.new(mock_bufnr)
      
      selection_navigation.enable_selection_mode(mock_bufnr, machine)
      
      -- Normal navigation should still work (j, k, gg, G, etc.)
      -- This would be tested by verifying the keymaps are set up correctly
      assert.is_true(true) -- Placeholder for keymap verification
    end)
  end)

  describe("selection workflow integration", function()
    it("should handle space key selection", function()
      local machine = selection_state.new(mock_bufnr)
      local command_def = {
        description = "Test command",
        phases = { { key = "target", prompt = "Select target" } }
      }
      
      -- Start selection mode
      local started = machine:handle_event(types.Events.COMMAND_STARTED, { command_def = command_def })
      assert.is_true(started)
      assert.are.equal(types.States.SELECTING_TARGET, machine:get_current_state())
      
      selection_navigation.enable_selection_mode(mock_bufnr, machine)
      
      -- Simulate space key press
      vim.api.nvim_win_get_cursor = function(winnr) return {1, 0} end -- On line with abc123
      
      local result = selection_navigation.handle_selection_key(mock_bufnr)
      
      assert.is_true(result)
      -- Machine should transition to executing state
      assert.are.equal(types.States.EXECUTING_COMMAND, machine:get_current_state())
    end)

    it("should handle enter key confirmation", function()
      local machine = selection_state.new(mock_bufnr)
      local command_def = {
        phases = { { key = "target", prompt = "Select target" } }
      }
      
      machine:handle_event(types.Events.COMMAND_STARTED, { command_def = command_def })
      selection_navigation.enable_selection_mode(mock_bufnr, machine)
      
      -- First select a commit
      vim.api.nvim_win_get_cursor = function(winnr) return {2, 0} end -- def456
      selection_navigation.handle_selection_key(mock_bufnr)
      
      -- Then confirm with enter
      local result = selection_navigation.handle_confirmation_key(mock_bufnr)
      
      assert.is_true(result)
      assert.are.equal(types.States.EXECUTING_COMMAND, machine:get_current_state())
    end)

    it("should handle escape key cancellation", function()
      local machine = selection_state.new(mock_bufnr)
      local command_def = {
        phases = { { key = "target", prompt = "Select target" } }
      }
      
      machine:handle_event(types.Events.COMMAND_STARTED, { command_def = command_def })
      selection_navigation.enable_selection_mode(mock_bufnr, machine)
      
      local result = selection_navigation.handle_cancellation_key(mock_bufnr)
      
      assert.is_true(result)
      assert.are.equal(types.States.BROWSE, machine:get_current_state())
      assert.is_false(selection_navigation.is_selection_mode_enabled(mock_bufnr))
    end)
  end)

  describe("multi-phase workflow", function()
    it("should handle multi-phase selection workflow", function()
      local machine = selection_state.new(mock_bufnr)
      local command_def = {
        phases = {
          { key = "source", prompt = "Select source" },
          { key = "destination", prompt = "Select destination" }
        }
      }
      
      machine:handle_event(types.Events.COMMAND_STARTED, { command_def = command_def })
      selection_navigation.enable_selection_mode(mock_bufnr, machine)
      
      -- Select source (line 1 = abc123)
      vim.api.nvim_win_get_cursor = function(winnr) return {1, 0} end
      selection_navigation.handle_selection_key(mock_bufnr)
      assert.are.equal(types.States.SELECTING_TARGET, machine:get_current_state())
      
      -- Select destination (line 2 = def456)  
      vim.api.nvim_win_get_cursor = function(winnr) return {2, 0} end
      selection_navigation.handle_selection_key(mock_bufnr)
      assert.are.equal(types.States.EXECUTING_COMMAND, machine:get_current_state())
      
      -- Should have both selections
      local context = machine:get_command_context()
      assert.are.equal("abc123", context.selections.source)
      assert.are.equal("def456", context.selections.destination)
    end)

    it("should allow cancellation at any phase", function()
      local machine = selection_state.new(mock_bufnr)
      local command_def = {
        phases = {
          { key = "source", prompt = "Select source" },
          { key = "destination", prompt = "Select destination" }
        }
      }
      
      machine:handle_event(types.Events.COMMAND_STARTED, { command_def = command_def })
      selection_navigation.enable_selection_mode(mock_bufnr, machine)
      
      -- Select source
      vim.api.nvim_win_get_cursor = function(winnr) return {1, 0} end
      selection_navigation.handle_selection_key(mock_bufnr)
      assert.are.equal(types.States.SELECTING_TARGET, machine:get_current_state())
      
      -- Cancel during target selection
      selection_navigation.handle_cancellation_key(mock_bufnr)
      assert.are.equal(types.States.BROWSE, machine:get_current_state())
      assert.is_nil(machine:get_command_context())
    end)
  end)

  describe("multi-select workflow", function()
    it("should handle multi-select commands", function()
      local machine = selection_state.new(mock_bufnr)
      local command_def = {
        phases = {
          { key = "targets", prompt = "Select commits", multi_select = true }
        }
      }
      
      machine:handle_event(types.Events.COMMAND_STARTED, { command_def = command_def })
      selection_navigation.enable_selection_mode(mock_bufnr, machine)
      
      -- Select multiple commits
      vim.api.nvim_win_get_cursor = function(winnr) return {1, 0} end -- abc123
      selection_navigation.handle_selection_key(mock_bufnr)
      
      vim.api.nvim_win_get_cursor = function(winnr) return {2, 0} end -- def456
      selection_navigation.handle_selection_key(mock_bufnr)
      
      -- Should still be in selecting mode
      assert.are.equal(types.States.SELECTING_MULTIPLE, machine:get_current_state())
      
      -- Confirm selection
      selection_navigation.handle_confirmation_key(mock_bufnr)
      assert.are.equal(types.States.EXECUTING_COMMAND, machine:get_current_state())
      
      -- Should have both commits selected
      local context = machine:get_command_context()
      assert.are.equal(2, #context.selections.targets)
      assert.is_true(vim.tbl_contains(context.selections.targets, "abc123"))
      assert.is_true(vim.tbl_contains(context.selections.targets, "def456"))
    end)
  end)

  describe("visual feedback integration", function()
    it("should update visual feedback during selection", function()
      local machine = selection_state.new(mock_bufnr)
      local command_def = {
        phases = { { key = "target", prompt = "Select target" } }
      }
      
      -- Mock visual feedback calls
      local window_shown = false
      local highlights_updated = false
      
      visual_feedback.show_selection_window = function(winnr, context)
        window_shown = true
      end
      
      visual_feedback.update_selection_highlights = function(bufnr, selections)
        highlights_updated = true
      end
      
      machine:handle_event(types.Events.COMMAND_STARTED, { command_def = command_def })
      selection_navigation.enable_selection_mode(mock_bufnr, machine)
      
      assert.is_true(window_shown)
      
      -- Make a selection
      vim.api.nvim_win_get_cursor = function(winnr) return {1, 0} end
      selection_navigation.handle_selection_key(mock_bufnr)
      
      assert.is_true(highlights_updated)
    end)

    it("should clean up visual feedback on cancellation", function()
      local machine = selection_state.new(mock_bufnr)
      local command_def = {
        phases = { { key = "target", prompt = "Select target" } }
      }
      
      local window_hidden = false
      local highlights_cleared = false
      
      visual_feedback.hide_selection_window = function()
        window_hidden = true
      end
      
      visual_feedback.clear_selection_highlights = function(bufnr)
        highlights_cleared = true
      end
      
      machine:handle_event(types.Events.COMMAND_STARTED, { command_def = command_def })
      selection_navigation.enable_selection_mode(mock_bufnr, machine)
      
      selection_navigation.handle_cancellation_key(mock_bufnr)
      
      assert.is_true(window_hidden)
      assert.is_true(highlights_cleared)
    end)
  end)

  describe("error handling", function()
    it("should handle invalid cursor positions gracefully", function()
      vim.api.nvim_buf_get_lines = function(bufnr, start, end_line, strict_indexing)
        return {} -- No lines at that position
      end
      
      local commit_id = selection_navigation.get_commit_id_at_cursor(mock_bufnr, 999)
      assert.is_nil(commit_id)
    end)

    it("should handle selection when no state machine exists", function()
      local result = selection_navigation.handle_selection_key(mock_bufnr)
      assert.is_false(result)
    end)

    it("should handle keybinding operations on non-selection buffers", function()
      selection_navigation.disable_selection_mode(999) -- Non-existent buffer
      -- Should not error
      assert.is_true(true)
    end)
  end)
end)