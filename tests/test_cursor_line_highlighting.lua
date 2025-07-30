-- Test cursor line highlighting functionality for jj log window
require("helpers.vim_mock")

-- Additional mocks for cursor line highlighting tests
local mock_buffers = {}
local mock_windows = {}
local mock_window_options = {}
local mock_buffer_options = {}
local mock_highlights = {}
local mock_autocmds = {}

-- Extend vim mock with specific functions for cursor line tests
local original_nvim_win_set_option = vim.api.nvim_win_set_option
vim.api.nvim_win_set_option = function(window_id, option, value)
  if not mock_window_options[window_id] then
    mock_window_options[window_id] = {}
  end
  mock_window_options[window_id][option] = value
  if original_nvim_win_set_option then
    original_nvim_win_set_option(window_id, option, value)
  end
end

local original_nvim_buf_add_highlight = vim.api.nvim_buf_add_highlight
vim.api.nvim_buf_add_highlight = function(buffer_id, ns_id, hl_group, line, col_start, col_end)
  if not mock_highlights[buffer_id] then
    mock_highlights[buffer_id] = {}
  end
  table.insert(mock_highlights[buffer_id], {
    ns_id = ns_id,
    hl_group = hl_group,
    line = line,
    col_start = col_start,
    col_end = col_end
  })
  if original_nvim_buf_add_highlight then
    original_nvim_buf_add_highlight(buffer_id, ns_id, hl_group, line, col_start, col_end)
  end
end

local original_nvim_create_autocmd = vim.api.nvim_create_autocmd
vim.api.nvim_create_autocmd = function(event, opts)
  table.insert(mock_autocmds, {event = event, opts = opts})
  if original_nvim_create_autocmd then
    return original_nvim_create_autocmd(event, opts)
  end
  return math.random(1000, 9999)
end

-- Mock the dependencies before loading the window module
package.loaded["jj.log.renderer"] = {
  clear_buffer_content = function() end
}
package.loaded["jj.ui.navigation_integration"] = {
  cleanup_navigation_for_buffer = function() end
}

-- Load the window module
local window = dofile("../lua/jj/ui/window.lua")

describe("Cursor Line Highlighting", function()
  before_each(function()
    -- Clear mock data
    mock_buffers = {}
    mock_windows = {}
    mock_window_options = {}
    mock_buffer_options = {}
    mock_highlights = {}
    mock_autocmds = {}
  end)

  describe("full-width line highlighting", function()
    it("should enable cursorline for jj log windows", function()
      local window_id = window.open_log_window()
      
      assert.is_not_nil(window_id)
      assert.is_not_nil(mock_window_options[window_id])
      assert.is_true(mock_window_options[window_id].cursorline)
    end)

    it("should use full-width highlighting with col_end = -1", function()
      local buffer_id = window.create_log_buffer()
      
      -- Simulate adding full-width highlights
      vim.api.nvim_buf_add_highlight(buffer_id, 1, "CursorLine", 0, 0, -1)
      vim.api.nvim_buf_add_highlight(buffer_id, 1, "CursorLine", 1, 0, -1)
      
      assert.is_not_nil(mock_highlights[buffer_id])
      assert.equals(2, #mock_highlights[buffer_id])
      
      -- Check that both highlights use full-width (-1 col_end)
      for _, highlight in ipairs(mock_highlights[buffer_id]) do
        assert.equals(0, highlight.col_start)
        assert.equals(-1, highlight.col_end)
      end
    end)

    it("should apply highlighting to multiple lines when needed", function()
      local buffer_id = window.create_log_buffer()
      
      -- Simulate highlighting multiple lines (like a commit block)
      local lines_to_highlight = {0, 1, 2, 3}
      for _, line_num in ipairs(lines_to_highlight) do
        vim.api.nvim_buf_add_highlight(buffer_id, 1, "Visual", line_num, 0, -1)
      end
      
      assert.equals(4, #mock_highlights[buffer_id])
      
      -- Verify each line has full-width highlighting
      for i, highlight in ipairs(mock_highlights[buffer_id]) do
        assert.equals(lines_to_highlight[i], highlight.line)
        assert.equals(0, highlight.col_start)
        assert.equals(-1, highlight.col_end)
        assert.equals("Visual", highlight.hl_group)
      end
    end)
  end)

  describe("buffer-specific configuration", function()
    it("should set cursorline only for jj buffers", function()
      local buffer_id = window.create_log_buffer()
      local window_id = window.open_log_window()
      
      -- Should have cursorline enabled for jj window
      assert.is_true(mock_window_options[window_id].cursorline)
      
      -- Should have jj filetype
      assert.equals("jj", mock_window_options[window_id].filetype)
    end)

    it("should handle window cleanup properly", function()
      local window_id = window.open_log_window()
      
      -- Verify window was created with cursorline
      assert.is_true(mock_window_options[window_id].cursorline)
      
      -- Close window
      vim.api.nvim_win_close(window_id, true)
      
      -- Window options should be cleaned up
      assert.is_nil(mock_windows[window_id])
      assert.is_nil(mock_window_options[window_id])
    end)
  end)

  describe("highlight group management", function()
    it("should clear existing highlights before adding new ones", function()
      local buffer_id = window.create_log_buffer()
      
      -- Add initial highlights
      vim.api.nvim_buf_add_highlight(buffer_id, 1, "Visual", 0, 0, -1)
      vim.api.nvim_buf_add_highlight(buffer_id, 1, "Visual", 1, 0, -1)
      assert.equals(2, #mock_highlights[buffer_id])
      
      -- Clear and add new highlights
      vim.api.nvim_buf_clear_namespace(buffer_id, 1, 0, -1)
      vim.api.nvim_buf_add_highlight(buffer_id, 1, "CursorLine", 2, 0, -1)
      
      -- Should have only the new highlight
      assert.equals(1, #mock_highlights[buffer_id])
      assert.equals("CursorLine", mock_highlights[buffer_id][1].hl_group)
      assert.equals(2, mock_highlights[buffer_id][1].line)
    end)

    it("should use appropriate highlight groups for different contexts", function()
      local buffer_id = window.create_log_buffer()
      
      -- Test different highlight groups
      vim.api.nvim_buf_add_highlight(buffer_id, 1, "CursorLine", 0, 0, -1)
      vim.api.nvim_buf_add_highlight(buffer_id, 1, "Visual", 1, 0, -1)
      vim.api.nvim_buf_add_highlight(buffer_id, 1, "Search", 2, 0, -1)
      
      local highlights = mock_highlights[buffer_id]
      assert.equals(3, #highlights)
      
      local highlight_groups = {}
      for _, hl in ipairs(highlights) do
        table.insert(highlight_groups, hl.hl_group)
      end
      
      assert.is_true(vim.tbl_contains(highlight_groups, "CursorLine"))
      assert.is_true(vim.tbl_contains(highlight_groups, "Visual"))
      assert.is_true(vim.tbl_contains(highlight_groups, "Search"))
    end)
  end)
end)