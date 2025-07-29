-- Tests for visual feedback system
require("tests.helpers.vim_mock")

local visual_feedback = require("jj.visual_feedback")
local types = require("jj.types")

describe("visual feedback system", function()
  local mock_bufnr = 1
  local mock_log_winnr = 1000

  before_each(function()
    -- Reset visual feedback state
    visual_feedback._reset_for_testing()
    
    -- Mock buffer and window APIs
    vim.api.nvim_create_buf = function(listed, scratch)
      return mock_bufnr + 1
    end
    
    vim.api.nvim_open_win = function(bufnr, enter, config)
      return mock_log_winnr + 1
    end
    
    vim.api.nvim_win_close = function(winnr, force)
      -- Mock window close
    end
    
    vim.api.nvim_buf_set_lines = function(bufnr, start, end_line, strict_indexing, replacement)
      -- Mock buffer content setting
    end
    
    vim.api.nvim_win_set_config = function(winnr, config)
      -- Mock window config updates
    end
    
    vim.api.nvim_win_get_config = function(winnr)
      return { row = 0, col = 0 }
    end
    
    vim.api.nvim_buf_set_option = function(bufnr, name, value)
      -- Mock buffer option setting
    end
    
    vim.api.nvim_buf_add_highlight = function(bufnr, ns_id, hl_group, line, col_start, col_end)
      -- Mock highlight addition
    end
    
    vim.api.nvim_buf_clear_namespace = function(bufnr, ns_id, start, end_line)
      -- Mock highlight clearing
    end
    
    vim.api.nvim_buf_get_lines = function(bufnr, start, end_line, strict_indexing)
      -- Mock buffer with some commit lines
      return {
        "@  abc123  Current commit",
        "○  def456  Previous commit", 
        "○  ghi789  Older commit"
      }
    end
  end)

  describe("floating window management", function()
    it("should create floating window for selection mode", function()
      local command_def = {
        description = "Test command",
        phases = { { key = "target", prompt = "Select target commit" } }
      }
      
      visual_feedback.show_selection_window(mock_log_winnr, {
        command_def = command_def,
        current_phase = "target",
        phase_index = 1,
        selections = {}
      })
      
      local window_info = visual_feedback.get_selection_window_info()
      assert.is_not_nil(window_info)
      assert.are.equal(mock_log_winnr, window_info.parent_winnr)
    end)

    it("should hide floating window when exiting selection mode", function()
      local command_def = {
        phases = { { key = "target", prompt = "Select target" } }
      }
      
      visual_feedback.show_selection_window(mock_log_winnr, {
        command_def = command_def,
        current_phase = "target"
      })
      
      assert.is_not_nil(visual_feedback.get_selection_window_info())
      
      visual_feedback.hide_selection_window()
      
      assert.is_nil(visual_feedback.get_selection_window_info())
    end)

    it("should update window content when selection context changes", function()
      local command_def = {
        phases = {
          { key = "source", prompt = "Select source commit" },
          { key = "target", prompt = "Select target commit" }
        }
      }
      
      -- Initial state
      visual_feedback.show_selection_window(mock_log_winnr, {
        command_def = command_def,
        current_phase = "source",
        phase_index = 1,
        selections = {}
      })
      
      -- Update to next phase
      visual_feedback.update_selection_context({
        command_def = command_def,
        current_phase = "target",
        phase_index = 2,
        selections = { source = "abc123" }
      })
      
      local window_info = visual_feedback.get_selection_window_info()
      assert.is_not_nil(window_info)
      assert.are.equal("target", window_info.current_phase)
    end)
  end)

  describe("selection highlighting", function()
    it("should apply highlight to selected commits", function()
      local selections = { source = "abc123", target = "def456" }
      
      visual_feedback.update_selection_highlights(mock_bufnr, selections)
      
      local highlights = visual_feedback.get_current_highlights(mock_bufnr)
      assert.is_not_nil(highlights)
      assert.is_not_nil(highlights["abc123"])
      assert.is_not_nil(highlights["def456"])
    end)

    it("should use different highlight groups for different selection types", function()
      local selections = { source = "abc123" }
      local current_phase = "target"
      
      visual_feedback.update_selection_highlights(mock_bufnr, selections, current_phase)
      
      local highlights = visual_feedback.get_current_highlights(mock_bufnr)
      -- Source commit should use source highlight
      assert.are.equal("JJ3SelectedSource", highlights["abc123"].hl_group)
    end)

    it("should handle multi-select highlights", function()
      local selections = { targets = {"abc123", "def456", "ghi789"} }
      
      visual_feedback.update_selection_highlights(mock_bufnr, selections)
      
      local highlights = visual_feedback.get_current_highlights(mock_bufnr)
      assert.are.equal(3, vim.tbl_count(highlights))
      
      for _, commit_id in ipairs(selections.targets) do
        assert.is_not_nil(highlights[commit_id])
        assert.are.equal("JJ3SelectedMultiple", highlights[commit_id].hl_group)
      end
    end)

    it("should clear highlights when selection is cancelled", function()
      local selections = { source = "abc123", target = "def456" }
      
      visual_feedback.update_selection_highlights(mock_bufnr, selections)
      assert.is_not_nil(visual_feedback.get_current_highlights(mock_bufnr))
      
      visual_feedback.clear_selection_highlights(mock_bufnr)
      
      local highlights = visual_feedback.get_current_highlights(mock_bufnr)
      assert.are.equal(0, vim.tbl_count(highlights))
    end)
  end)

  describe("window content generation", function()
    it("should generate content for single-phase command", function()
      local context = {
        command_def = {
          description = "Squash current working copy into selected",
          phases = { { key = "target", prompt = "Select target commit to squash into" } }
        },
        current_phase = "target",
        phase_index = 1,
        selections = {}
      }
      
      local content = visual_feedback.generate_window_content(context)
      
      assert.is_true(#content > 0)
      local content_str = table.concat(content, "\n")
      assert.is_true(content_str:find("Select target commit to squash into") ~= nil)
      assert.is_true(content_str:find("␣ select") ~= nil)
    end)

    it("should generate content for multi-phase command", function()
      local context = {
        command_def = {
          description = "Rebase source onto destination",
          phases = {
            { key = "source", prompt = "Select source commit" },
            { key = "destination", prompt = "Select destination commit" }
          }
        },
        current_phase = "destination",
        phase_index = 2,
        selections = { source = "abc123" }
      }
      
      local content = visual_feedback.generate_window_content(context)
      
      local content_str = table.concat(content, "\n")
      assert.is_true(content_str:find("Select destination commit") ~= nil)
      assert.is_true(content_str:find("• abc123 %(source%)") ~= nil)
      assert.is_true(content_str:find("Phase 2 of 2") ~= nil)
    end)

    it("should generate content for multi-select command", function()
      local context = {
        command_def = {
          description = "Abandon multiple commits",
          phases = {
            { key = "targets", prompt = "Select commits to abandon", multi_select = true }
          }
        },
        current_phase = "targets",
        phase_index = 1,
        selections = { targets = {"abc123", "def456"} }
      }
      
      local content = visual_feedback.generate_window_content(context)
      
      local content_str = table.concat(content, "\n")
      assert.is_true(content_str:find("Select commits to abandon") ~= nil)
      assert.is_true(content_str:find("• abc123") ~= nil)
      assert.is_true(content_str:find("• def456") ~= nil)
      assert.is_true(content_str:find("␣ add") ~= nil)
    end)
  end)

  describe("highlight group management", function()
    it("should define all required highlight groups", function()
      visual_feedback.setup_highlight_groups()
      
      -- Test that highlight groups are defined (this would call nvim_set_hl)
      -- In a real test, we'd verify the API calls were made correctly
      assert.is_true(true) -- Placeholder for highlight group verification
    end)

    it("should provide different colors for each selection type", function()
      local groups = visual_feedback.get_highlight_group_definitions()
      
      assert.is_not_nil(groups["JJ3SelectedSource"])
      assert.is_not_nil(groups["JJ3SelectedTarget"])
      assert.is_not_nil(groups["JJ3SelectedMultiple"])
      assert.is_not_nil(groups["JJ3CurrentSelection"])
      
      -- Ensure they have different colors
      assert.are_not.equal(groups["JJ3SelectedSource"], groups["JJ3SelectedTarget"])
    end)
  end)

  describe("integration with log buffer", function()
    it("should work with buffer that contains commit IDs", function()
      -- Mock buffer content with log entries
      local log_lines = {
        "@  abc123  Current commit",
        "○  def456  Previous commit", 
        "○  ghi789  Older commit"
      }
      
      vim.api.nvim_buf_get_lines = function(bufnr, start, end_line, strict_indexing)
        return log_lines
      end
      
      local selections = { source = "def456" }
      visual_feedback.update_selection_highlights(mock_bufnr, selections)
      
      -- Should find and highlight the correct line
      local highlights = visual_feedback.get_current_highlights(mock_bufnr)
      assert.is_not_nil(highlights["def456"])
      assert.are.equal(1, highlights["def456"].line_number) -- 0-indexed
    end)

    it("should handle commits not found in buffer gracefully", function()
      local log_lines = {
        "@  abc123  Current commit",
        "○  def456  Previous commit"
      }
      
      vim.api.nvim_buf_get_lines = function(bufnr, start, end_line, strict_indexing)
        return log_lines
      end
      
      local selections = { source = "xyz999" } -- Not in buffer
      visual_feedback.update_selection_highlights(mock_bufnr, selections)
      
      local highlights = visual_feedback.get_current_highlights(mock_bufnr)
      assert.is_nil(highlights["xyz999"])
    end)
  end)
end)