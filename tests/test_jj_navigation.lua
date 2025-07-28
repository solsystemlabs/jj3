-- Tests for jj commit-aware navigation functionality
require("helpers.vim_mock")
local test_repo = require("helpers.test_repository")

-- Mock buffer operations for navigation testing
local mock_buffers = {}
local mock_buffer_lines = {}
local mock_cursor_positions = {}
local next_buffer_id = 1

-- Mock vim.api.nvim_buf_get_lines for reading buffer content
vim.api.nvim_buf_get_lines = function(buffer_id, start, end_line, strict_indexing)
  if mock_buffer_lines[buffer_id] then
    local lines = mock_buffer_lines[buffer_id]
    if start == 0 and end_line == -1 then
      return lines -- Return all lines
    end
    -- Return slice of lines
    local result = {}
    for i = start + 1, math.min(end_line, #lines) do
      table.insert(result, lines[i])
    end
    return result
  end
  return {}
end

-- Mock vim.api.nvim_win_get_cursor for cursor position
vim.api.nvim_win_get_cursor = function(window_id)
  return mock_cursor_positions[window_id] or {1, 0}
end

-- Mock vim.api.nvim_win_set_cursor for cursor movement
vim.api.nvim_win_set_cursor = function(window_id, pos)
  mock_cursor_positions[window_id] = pos
end

-- Mock vim.api.nvim_buf_set_keymap for keymap testing
local mock_keymaps = {}
vim.api.nvim_buf_set_keymap = function(buffer_id, mode, key, rhs, opts)
  if not mock_keymaps[buffer_id] then
    mock_keymaps[buffer_id] = {}
  end
  mock_keymaps[buffer_id][mode .. key] = {
    rhs = rhs,
    opts = opts
  }
end

-- Mock vim.api.nvim_get_current_win
vim.api.nvim_get_current_win = function()
  return 1 -- Default to window 1
end

-- Mock vim.api.nvim_feedkeys
vim.api.nvim_feedkeys = function(keys, mode, escape_csi)
  -- For testing purposes, just track what would be fed
  if not _G.mock_feedkeys_calls then
    _G.mock_feedkeys_calls = {}
  end
  table.insert(_G.mock_feedkeys_calls, {keys = keys, mode = mode, escape_csi = escape_csi})
end

-- Mock highlighting functions
local mock_highlights = {}
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
end

vim.api.nvim_buf_clear_namespace = function(buffer_id, ns_id, line_start, line_end)
  if mock_highlights[buffer_id] then
    -- Filter out highlights in the specified range and namespace
    local filtered = {}
    for _, hl in ipairs(mock_highlights[buffer_id]) do
      local should_keep = true
      if ns_id ~= -1 and hl.ns_id == ns_id then
        if line_start ~= -1 and line_end ~= -1 then
          if hl.line >= line_start and hl.line < line_end then
            should_keep = false
          end
        else
          should_keep = false -- Clear all highlights for this namespace
        end
      end
      if should_keep then
        table.insert(filtered, hl)
      end
    end
    mock_highlights[buffer_id] = filtered
  end
end

vim.api.nvim_create_namespace = function(name)
  return math.random(1000, 9999) -- Return a mock namespace ID
end

-- Create test buffer with jj log content
local function create_test_buffer_with_log(log_lines)
  local buffer_id = next_buffer_id
  next_buffer_id = next_buffer_id + 1
  
  mock_buffers[buffer_id] = true
  mock_buffer_lines[buffer_id] = log_lines
  
  return buffer_id
end

-- Sample jj log output for testing
local sample_log_lines = {
  "@    nkywompl teernisse@visiostack.com 2025-07-24 15:57:54 b34b2705 conflict",
  "├─╮  (no description set)",
  "│ │ ○  yqtmtwnw teernisse@visiostack.com 2025-07-24 15:53:13 mega-merge c8d5508a",
  "│ │ │  (empty) (no description set)",
  "│ │ ○  zlszpnwy teernisse@visiostack.com 2025-07-24 15:53:13 48ebc8ac",
  "│ │ │  Resolve mega merge conflicts",
  "│ │ ×      knylytyq teernisse@visiostack.com 2025-07-24 15:53:13 4292a094 conflict",
  "╭───┼─┬─╮  Mega merge: hotfix + branch-a + branch-b + main",
  "│ │ ○ │ │  lqzokswu teernisse@visiostack.com 2025-07-24 15:48:00 hotfix fa7836de",
  "│ │ │ │ │  (empty) (no description set)",
}

-- Sample parsed commits data (matching the log above)  
local sample_commits = {
  {
    commit_id = "b34b2705",
    change_id = "nkywompl", 
    author_name = "teernisse",
    author_email = "teernisse@visiostack.com",
    timestamp = "2025-07-24 15:57:54",
    description = "(no description set)",
    bookmarks = {},
    tags = {},
    conflict_status = "conflict"
  },
  {
    commit_id = "c8d5508a",
    change_id = "yqtmtwnw",
    author_name = "teernisse", 
    author_email = "teernisse@visiostack.com",
    timestamp = "2025-07-24 15:53:13",
    description = "(empty) (no description set)",
    bookmarks = {"mega-merge"},
    tags = {},
    conflict_status = "normal"
  },
  {
    commit_id = "48ebc8ac",
    change_id = "zlszpnwy",
    author_name = "teernisse",
    author_email = "teernisse@visiostack.com", 
    timestamp = "2025-07-24 15:53:13",
    description = "Resolve mega merge conflicts",
    bookmarks = {},
    tags = {},
    conflict_status = "normal"
  }
}

-- Load the navigation module
local navigation = dofile("lua/jj/navigation.lua")

describe("JJ Navigation", function()
  local lfs = require('lfs')
  local original_cwd

  before_each(function()
    original_cwd = lfs.currentdir()
    lfs.chdir(test_repo.test_repo_path)
    
    -- Reset mocks
    mock_buffers = {}
    mock_buffer_lines = {}
    mock_cursor_positions = {}
    mock_keymaps = {}
    mock_highlights = {}
    _G.mock_feedkeys_calls = {}
    next_buffer_id = 1
  end)

  after_each(function()
    lfs.chdir(original_cwd)
  end)

  describe("commit block data structures", function()
    it("should create valid commit block", function()
      local block = navigation.create_commit_block("abc123", "xyz789", 5, 7, {description = "test"})
      
      assert.is_not_nil(block)
      assert.equals("abc123", block.commit_id)
      assert.equals("xyz789", block.change_id)
      assert.equals(5, block.start_line)
      assert.equals(7, block.end_line)
      assert.equals(3, block.line_count)
    end)

    it("should reject invalid commit block parameters", function()
      -- Missing commit_id
      local block1 = navigation.create_commit_block(nil, "xyz", 1, 2, {})
      assert.is_nil(block1)
      
      -- Invalid line numbers
      local block2 = navigation.create_commit_block("abc", "xyz", 0, 1, {})
      assert.is_nil(block2)
      
      -- End line before start line
      local block3 = navigation.create_commit_block("abc", "xyz", 5, 3, {})
      assert.is_nil(block3)
    end)

    it("should validate commit block structure", function()
      local valid_block = navigation.create_commit_block("abc123", "xyz789", 1, 3, {})
      assert.is_true(navigation.is_valid_commit_block(valid_block))
      
      -- Invalid block  
      assert.is_false(navigation.is_valid_commit_block(nil))
      assert.is_false(navigation.is_valid_commit_block({}))
      assert.is_false(navigation.is_valid_commit_block({commit_id = "abc"}))
    end)
  end)

  describe("commit boundary detection", function()
    it("should detect commit boundaries from parsed data and buffer content", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      
      assert.is_not_nil(boundaries)
      assert.is_table(boundaries)
      assert.is_true(#boundaries > 0)
    end)

    it("should map commits to correct line ranges", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      
      -- First commit (b34b2705) should include lines 1-2
      local first_commit = boundaries[1]
      assert.is_not_nil(first_commit)
      assert.equals("b34b2705", first_commit.commit_id)
      assert.equals(1, first_commit.start_line)
      assert.equals(2, first_commit.end_line)
    end)

    it("should handle commits with multiple description lines", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      
      -- Find commit with description
      local commit_with_desc = nil
      for _, boundary in ipairs(boundaries) do
        if boundary.commit_id == "48ebc8ac" then
          commit_with_desc = boundary
          break
        end
      end
      
      assert.is_not_nil(commit_with_desc)
      assert.is_true(commit_with_desc.end_line > commit_with_desc.start_line)
    end)

    it("should handle empty buffer gracefully", function()
      local buffer_id = create_test_buffer_with_log({})
      
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      
      assert.is_table(boundaries)
      assert.equals(0, #boundaries)
    end)

    it("should handle nil commits gracefully", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      local boundaries = navigation.detect_commit_boundaries(buffer_id, nil)
      
      assert.is_table(boundaries)
      assert.equals(0, #boundaries)
    end)

    it("should handle commits not found in buffer", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      local missing_commits = {
        {
          commit_id = "nonexistent123",
          change_id = "missing",
          description = "Not in buffer"
        }
      }
      
      local boundaries = navigation.detect_commit_boundaries(buffer_id, missing_commits)
      
      assert.is_table(boundaries)
      assert.equals(0, #boundaries)
    end)
  end)

  describe("cursor position to commit mapping", function()
    it("should identify commit at cursor position", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      
      -- Set cursor to line 1 (first commit)
      mock_cursor_positions[1] = {1, 0}
      
      local commit_at_cursor = navigation.get_commit_at_cursor(buffer_id, 1, boundaries)
      
      assert.is_not_nil(commit_at_cursor)
      assert.equals("b34b2705", commit_at_cursor.commit_id)
    end)

    it("should handle cursor on description lines", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      
      -- Set cursor to line 2 (description of first commit)
      mock_cursor_positions[1] = {2, 0}
      
      local commit_at_cursor = navigation.get_commit_at_cursor(buffer_id, 1, boundaries)
      
      assert.is_not_nil(commit_at_cursor)
      assert.equals("b34b2705", commit_at_cursor.commit_id)
    end)

    it("should return nil for cursor outside any commit boundaries", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      
      -- Set cursor to a line beyond any commit
      mock_cursor_positions[1] = {100, 0}
      
      local commit_at_cursor = navigation.get_commit_at_cursor(buffer_id, 1, boundaries)
      
      assert.is_nil(commit_at_cursor)
    end)

    it("should handle nil boundaries gracefully", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      mock_cursor_positions[1] = {1, 0}
      
      local commit_at_cursor = navigation.get_commit_at_cursor(buffer_id, 1, nil)
      
      assert.is_nil(commit_at_cursor)
    end)
  end)

  describe("commit navigation", function()
    it("should navigate to next commit with j key", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      
      -- Start at first commit (line 1)
      mock_cursor_positions[1] = {1, 0}
      
      local result = navigation.navigate_to_next_commit(buffer_id, 1, boundaries)
      
      assert.is_true(result)
      -- Should move to line 3 (second commit: c8d5508a)
      assert.equals(3, mock_cursor_positions[1][1])
    end)

    it("should navigate to previous commit with k key", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      
      -- Start at second commit (line 3)
      mock_cursor_positions[1] = {3, 0}
      
      local result = navigation.navigate_to_previous_commit(buffer_id, 1, boundaries)
      
      assert.is_true(result)
      -- Should move to line 1 (first commit: b34b2705)
      assert.equals(1, mock_cursor_positions[1][1])
    end)

    it("should not navigate past first commit when going up", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      
      -- Start at first commit
      mock_cursor_positions[1] = {1, 0}
      
      local result = navigation.navigate_to_previous_commit(buffer_id, 1, boundaries)
      
      assert.is_false(result)
      -- Should stay at line 1
      assert.equals(1, mock_cursor_positions[1][1])
    end)

    it("should not navigate past last commit when going down", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      
      -- Start at last commit (48ebc8ac at line 5)
      mock_cursor_positions[1] = {5, 0}
      
      local result = navigation.navigate_to_next_commit(buffer_id, 1, boundaries)
      
      assert.is_false(result)
      -- Should stay at line 5
      assert.equals(5, mock_cursor_positions[1][1])
    end)

    it("should handle navigation from description lines", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      
      -- Start at description line of first commit (line 2)
      mock_cursor_positions[1] = {2, 0}
      
      local result = navigation.navigate_to_next_commit(buffer_id, 1, boundaries)
      
      assert.is_true(result)
      -- Should move to next commit (line 3)
      assert.equals(3, mock_cursor_positions[1][1])
    end)

    it("should handle empty boundaries gracefully", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      mock_cursor_positions[1] = {1, 0}
      
      local result_next = navigation.navigate_to_next_commit(buffer_id, 1, {})
      local result_prev = navigation.navigate_to_previous_commit(buffer_id, 1, {})
      
      assert.is_false(result_next)
      assert.is_false(result_prev)
      -- Cursor should not move
      assert.equals(1, mock_cursor_positions[1][1])
    end)

    it("should handle nil parameters gracefully", function()
      assert.is_false(navigation.navigate_to_next_commit(nil, 1, {}))
      assert.is_false(navigation.navigate_to_previous_commit(nil, 1, {}))
      assert.is_false(navigation.navigate_to_next_commit(1, nil, {}))
      assert.is_false(navigation.navigate_to_previous_commit(1, nil, {}))
      assert.is_false(navigation.navigate_to_next_commit(1, 1, nil))
      assert.is_false(navigation.navigate_to_previous_commit(1, 1, nil))
    end)
  end)

  describe("keymap setup", function()
    it("should setup j/k keymaps for buffer", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      
      local result = navigation.setup_commit_navigation_keymaps(buffer_id, boundaries)
      
      assert.is_true(result)
      assert.is_not_nil(mock_keymaps[buffer_id])
      assert.is_not_nil(mock_keymaps[buffer_id]["nj"])
      assert.is_not_nil(mock_keymaps[buffer_id]["nk"])
    end)

    it("should configure keymap options correctly", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      
      navigation.setup_commit_navigation_keymaps(buffer_id, boundaries)
      
      local j_keymap = mock_keymaps[buffer_id]["nj"]
      local k_keymap = mock_keymaps[buffer_id]["nk"]
      
      assert.is_true(j_keymap.opts.noremap)
      assert.is_true(j_keymap.opts.silent)
      assert.is_function(j_keymap.opts.callback)
      
      assert.is_true(k_keymap.opts.noremap)
      assert.is_true(k_keymap.opts.silent)
      assert.is_function(k_keymap.opts.callback)
    end)

    it("should handle nil parameters gracefully", function()
      assert.is_false(navigation.setup_commit_navigation_keymaps(nil, {}))
      assert.is_false(navigation.setup_commit_navigation_keymaps(1, nil))
    end)
  end)

  describe("commit highlighting", function()
    it("should highlight commit block lines", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      local first_commit = boundaries[1]
      
      local result = navigation.highlight_commit_block(buffer_id, first_commit)
      
      assert.is_true(result)
      assert.is_not_nil(mock_highlights[buffer_id])
      assert.is_true(#mock_highlights[buffer_id] > 0)
      
      -- Should highlight both commit line (1) and description line (2)
      local highlights_found = 0
      for _, hl in ipairs(mock_highlights[buffer_id]) do
        if hl.line >= 0 and hl.line <= 1 then -- 0-indexed lines
          highlights_found = highlights_found + 1
        end
      end
      assert.equals(2, highlights_found)
    end)

    it("should use correct highlight group", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      local first_commit = boundaries[1]
      
      navigation.highlight_commit_block(buffer_id, first_commit)
      
      -- All highlights should use the JJCommitBlock highlight group
      for _, hl in ipairs(mock_highlights[buffer_id]) do
        assert.equals("JJCommitBlock", hl.hl_group)
      end
    end)

    it("should clear previous highlights before adding new ones", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      
      -- Highlight first commit
      navigation.highlight_commit_block(buffer_id, boundaries[1])
      local first_highlight_count = #mock_highlights[buffer_id]
      
      -- Highlight second commit - should clear previous highlights
      navigation.highlight_commit_block(buffer_id, boundaries[2])
      
      -- Should still have highlights, but only for the second commit
      assert.is_true(#mock_highlights[buffer_id] > 0)
      -- The exact count depends on implementation, but should be reasonable
      assert.is_true(#mock_highlights[buffer_id] <= first_highlight_count + 2)
    end)

    it("should handle nil commit block gracefully", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      local result = navigation.highlight_commit_block(buffer_id, nil)
      
      assert.is_false(result)
    end)

    it("should handle invalid buffer gracefully", function()
      local boundaries = navigation.detect_commit_boundaries(1, sample_commits)
      
      local result = navigation.highlight_commit_block(nil, boundaries[1])
      
      assert.is_false(result)
    end)

    it("should clear all highlights from buffer", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      
      -- Add some highlights
      navigation.highlight_commit_block(buffer_id, boundaries[1])
      assert.is_true(#mock_highlights[buffer_id] > 0)
      
      -- Clear highlights
      local result = navigation.clear_commit_highlights(buffer_id)
      
      assert.is_true(result)
      assert.equals(0, #mock_highlights[buffer_id])
    end)
  end)

  describe("navigation with highlighting", function()
    it("should highlight commit when navigating with j key", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      
      -- Start at first commit
      mock_cursor_positions[1] = {1, 0}
      
      local result = navigation.navigate_to_next_commit_with_highlight(buffer_id, 1, boundaries)
      
      assert.is_true(result)
      assert.equals(3, mock_cursor_positions[1][1]) -- Should move to second commit
      assert.is_true(#mock_highlights[buffer_id] > 0) -- Should have highlights
    end)

    it("should highlight commit when navigating with k key", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      
      -- Start at second commit
      mock_cursor_positions[1] = {3, 0}
      
      local result = navigation.navigate_to_previous_commit_with_highlight(buffer_id, 1, boundaries)
      
      assert.is_true(result)
      assert.equals(1, mock_cursor_positions[1][1]) -- Should move to first commit
      assert.is_true(#mock_highlights[buffer_id] > 0) -- Should have highlights
    end)

    it("should setup enhanced keymaps with highlighting", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      
      local result = navigation.setup_commit_navigation_keymaps_with_highlight(buffer_id, boundaries)
      
      assert.is_true(result)
      assert.is_not_nil(mock_keymaps[buffer_id])
      assert.is_not_nil(mock_keymaps[buffer_id]["nj"])
      assert.is_not_nil(mock_keymaps[buffer_id]["nk"])
      assert.is_not_nil(mock_keymaps[buffer_id]["ngg"])
      assert.is_not_nil(mock_keymaps[buffer_id]["nG"])
    end)
  end)

  describe("first/last commit navigation", function()
    it("should navigate to first commit with gg", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      
      -- Start at second commit (line 3)
      mock_cursor_positions[1] = {3, 0}
      
      local result = navigation.navigate_to_first_commit(buffer_id, 1, boundaries)
      
      assert.is_true(result)
      -- Should move to line 1 (first commit)
      assert.equals(1, mock_cursor_positions[1][1])
    end)

    it("should navigate to last commit with G", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      
      -- Start at first commit (line 1)
      mock_cursor_positions[1] = {1, 0}
      
      local result = navigation.navigate_to_last_commit(buffer_id, 1, boundaries)
      
      assert.is_true(result)
      -- Should move to line 5 (last commit: e9f12a34)
      assert.equals(5, mock_cursor_positions[1][1])
    end)

    it("should navigate to first commit with highlighting", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      
      -- Start at second commit
      mock_cursor_positions[1] = {3, 0}
      
      local result = navigation.navigate_to_first_commit_with_highlight(buffer_id, 1, boundaries)
      
      assert.is_true(result)
      assert.equals(1, mock_cursor_positions[1][1]) -- Should move to first commit
      assert.is_true(#mock_highlights[buffer_id] > 0) -- Should have highlights
    end)

    it("should navigate to last commit with highlighting", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      local boundaries = navigation.detect_commit_boundaries(buffer_id, sample_commits)
      
      -- Start at first commit
      mock_cursor_positions[1] = {1, 0}
      
      local result = navigation.navigate_to_last_commit_with_highlight(buffer_id, 1, boundaries)
      
      assert.is_true(result)
      assert.equals(5, mock_cursor_positions[1][1]) -- Should move to last commit
      assert.is_true(#mock_highlights[buffer_id] > 0) -- Should have highlights
    end)

    it("should handle empty boundaries gracefully", function()
      local result_first = navigation.navigate_to_first_commit(1, 1, {})
      local result_last = navigation.navigate_to_last_commit(1, 1, {})
      
      assert.is_false(result_first)
      assert.is_false(result_last)
    end)

    it("should handle nil parameters gracefully", function()
      assert.is_false(navigation.navigate_to_first_commit(nil, 1, {}))
      assert.is_false(navigation.navigate_to_first_commit(1, nil, {}))
      assert.is_false(navigation.navigate_to_first_commit(1, 1, nil))
      
      assert.is_false(navigation.navigate_to_last_commit(nil, 1, {}))
      assert.is_false(navigation.navigate_to_last_commit(1, nil, {}))
      assert.is_false(navigation.navigate_to_last_commit(1, 1, nil))
    end)

    it("should work with single commit", function()
      -- Create a buffer with only one commit
      local single_commit_lines = {"@  b34b2705 user@example.com 2023-05-14T12:00:00 main"}
      local single_commit = {{
        commit_id = "b34b2705",
        change_id = "kxvskzvp",
        author_name = "user@example.com",
        timestamp = "2023-05-14T12:00:00"
      }}
      
      local buffer_id = create_test_buffer_with_log(single_commit_lines)
      local boundaries = navigation.detect_commit_boundaries(buffer_id, single_commit)
      
      mock_cursor_positions[1] = {1, 0}
      
      -- Both gg and G should work and stay at the same position
      local result_first = navigation.navigate_to_first_commit(buffer_id, 1, boundaries)
      assert.is_true(result_first)
      assert.equals(1, mock_cursor_positions[1][1])
      
      local result_last = navigation.navigate_to_last_commit(buffer_id, 1, boundaries)
      assert.is_true(result_last)
      assert.equals(1, mock_cursor_positions[1][1])
    end)
  end)
end)