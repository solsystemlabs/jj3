-- Tests for navigation integration with existing plugin architecture
require("helpers.vim_mock")
local test_repo = require("helpers.test_repository")

-- Mock window management
local mock_window_id = 1
local mock_buffer_id = 1
local mock_buffers = {}
local mock_buffer_lines = {}
local mock_cursor_positions = {}
local mock_highlights = {}
local mock_keymaps = {}
local mock_autocmds = {}

-- Mock vim.api functions for integration testing
vim.api.nvim_buf_get_lines = function(buffer_id, start, end_line, strict_indexing)
  if mock_buffer_lines[buffer_id] then
    local lines = mock_buffer_lines[buffer_id]
    if start == 0 and end_line == -1 then
      return lines
    end
    local result = {}
    for i = start + 1, math.min(end_line, #lines) do
      table.insert(result, lines[i])
    end
    return result
  end
  return {}
end

vim.api.nvim_win_get_cursor = function(window_id)
  return mock_cursor_positions[window_id] or {1, 0}
end

vim.api.nvim_win_set_cursor = function(window_id, pos)
  mock_cursor_positions[window_id] = pos
end

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
    mock_highlights[buffer_id] = {}
  end
end

vim.api.nvim_create_namespace = function(name)
  return math.random(1000, 9999)
end

vim.api.nvim_buf_set_keymap = function(buffer_id, mode, key, rhs, opts)
  if not mock_keymaps[buffer_id] then
    mock_keymaps[buffer_id] = {}
  end
  mock_keymaps[buffer_id][mode .. key] = {
    rhs = rhs,
    opts = opts
  }
end

vim.api.nvim_get_current_win = function()
  return mock_window_id
end

vim.api.nvim_create_autocmd = function(event, opts)
  if not mock_autocmds[opts.buffer] then
    mock_autocmds[opts.buffer] = {}
  end
  table.insert(mock_autocmds[opts.buffer], {
    event = event,
    callback = opts.callback,
    group = opts.group
  })
end

vim.api.nvim_create_augroup = function(name, opts)
  return name
end

vim.api.nvim_del_augroup_by_name = function(name)
  -- Mock function, doesn't need to do anything
end

vim.api.nvim_buf_get_name = function(buffer_id)
  return "JJ Log"
end

vim.api.nvim_buf_get_option = function(buffer_id, option)
  if option == "filetype" then
    return "jj"
  end
  return ""
end

vim.api.nvim_set_hl = function(ns_id, name, opts)
  -- Mock function for setting highlights
end

vim.o = {
  background = "dark"
}

-- Create test buffer with jj log content
local function create_test_buffer_with_log(log_lines)
  mock_buffer_lines[mock_buffer_id] = log_lines
  mock_buffers[mock_buffer_id] = true
  return mock_buffer_id
end

-- Sample data for testing
local sample_log_lines = {
  "@    nkywompl teernisse@visiostack.com 2025-07-24 15:57:54 b34b2705 conflict",
  "├─╮  (no description set)",
  "│ │ ○  yqtmtwnw teernisse@visiostack.com 2025-07-24 15:53:13 mega-merge c8d5508a",
  "│ │ │  (empty) (no description set)",
  "│ │ ○  zlszpnwy teernisse@visiostack.com 2025-07-24 15:53:13 48ebc8ac",
  "│ │ │  Resolve mega merge conflicts",
}

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
  }
}

-- Load the integration module
local navigation_integration = dofile("lua/jj/ui/navigation_integration.lua")

describe("Navigation Integration", function()
  local lfs = require('lfs')
  local original_cwd

  before_each(function()
    original_cwd = lfs.currentdir()
    lfs.chdir(test_repo.test_repo_path)
    
    -- Clean up any existing navigation state
    navigation_integration.cleanup_all_navigation()
    
    -- Reset mocks
    mock_buffers = {}
    mock_buffer_lines = {}
    mock_cursor_positions = {}
    mock_highlights = {}
    mock_keymaps = {}
    mock_autocmds = {}
    mock_buffer_id = math.random(100, 999) -- Use random buffer IDs to avoid conflicts
    mock_window_id = 1
  end)

  after_each(function()
    lfs.chdir(original_cwd)
  end)

  describe("integration setup", function()
    it("should initialize navigation for buffer with commits", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      local result = navigation_integration.init_navigation_for_buffer(buffer_id, sample_commits)
      
      assert.is_true(result)
      assert.is_true(navigation_integration.is_navigation_enabled(buffer_id))
    end)

    it("should setup keymaps when initializing navigation", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      navigation_integration.init_navigation_for_buffer(buffer_id, sample_commits)
      
      assert.is_not_nil(mock_keymaps[buffer_id])
      assert.is_not_nil(mock_keymaps[buffer_id]["nj"])
      assert.is_not_nil(mock_keymaps[buffer_id]["nk"])
    end)

    it("should setup highlighting when initializing navigation", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      mock_cursor_positions[mock_window_id] = {1, 0} -- Position on first commit
      
      navigation_integration.init_navigation_for_buffer(buffer_id, sample_commits)
      
      -- Should have initial highlighting
      assert.is_true(#mock_highlights[buffer_id] > 0)
    end)

    it("should handle empty commits gracefully", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      local result = navigation_integration.init_navigation_for_buffer(buffer_id, {})
      
      assert.is_false(result)
      assert.is_false(navigation_integration.is_navigation_enabled(buffer_id))
    end)

    it("should handle nil commits gracefully", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      local result = navigation_integration.init_navigation_for_buffer(buffer_id, nil)
      
      assert.is_false(result)
      assert.is_false(navigation_integration.is_navigation_enabled(buffer_id))
    end)
  end)

  describe("navigation state management", function()
    it("should provide access to boundaries and commits", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      navigation_integration.init_navigation_for_buffer(buffer_id, sample_commits)
      
      local boundaries = navigation_integration.get_navigation_boundaries(buffer_id)
      local commits = navigation_integration.get_buffer_commits(buffer_id)
      
      assert.is_not_nil(boundaries)
      assert.is_not_nil(commits)
      assert.is_true(#boundaries > 0)
      assert.equals(#sample_commits, #commits)
    end)

    it("should provide current commit information", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      navigation_integration.init_navigation_for_buffer(buffer_id, sample_commits)
      mock_cursor_positions[mock_window_id] = {1, 0}
      
      local current_commit = navigation_integration.get_current_commit(buffer_id, mock_window_id)
      
      assert.is_not_nil(current_commit)
      assert.equals("b34b2705", current_commit.commit_id)
    end)

    it("should update highlighting on cursor movement", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      navigation_integration.init_navigation_for_buffer(buffer_id, sample_commits)
      
      -- Start at first commit
      mock_cursor_positions[mock_window_id] = {1, 0}
      local initial_highlights = #mock_highlights[buffer_id]
      
      -- Move to second commit
      mock_cursor_positions[mock_window_id] = {3, 0}
      navigation_integration.update_commit_highlighting(buffer_id, mock_window_id)
      
      -- Should still have highlights (may have changed)
      assert.is_true(#mock_highlights[buffer_id] >= initial_highlights)
    end)
  end)

  describe("buffer detection", function()
    it("should identify jj log buffers correctly", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      local is_jj_buffer = navigation_integration.is_jj_log_buffer(buffer_id)
      
      assert.is_true(is_jj_buffer)
    end)

    it("should handle nil buffer gracefully", function()
      local is_jj_buffer = navigation_integration.is_jj_log_buffer(nil)
      
      assert.is_false(is_jj_buffer)
    end)
  end)

  describe("auto highlighting", function()
    it("should setup autocmd for automatic highlighting", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      navigation_integration.init_navigation_for_buffer(buffer_id, sample_commits)
      
      local result = navigation_integration.setup_auto_highlighting(buffer_id)
      
      assert.is_true(result)
      assert.is_not_nil(mock_autocmds[buffer_id])
      assert.is_true(#mock_autocmds[buffer_id] > 0)
    end)

    it("should not setup autocmd for disabled navigation", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      local result = navigation_integration.setup_auto_highlighting(buffer_id)
      
      assert.is_false(result)
    end)
  end)

  describe("cleanup", function()
    it("should clean up navigation state for buffer", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      navigation_integration.init_navigation_for_buffer(buffer_id, sample_commits)
      
      assert.is_true(navigation_integration.is_navigation_enabled(buffer_id))
      
      local result = navigation_integration.cleanup_navigation_for_buffer(buffer_id)
      
      assert.is_true(result)
      assert.is_false(navigation_integration.is_navigation_enabled(buffer_id))
      assert.equals(0, #mock_highlights[buffer_id])
    end)

    it("should refresh navigation with new commits", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      navigation_integration.init_navigation_for_buffer(buffer_id, sample_commits)
      
      -- Add a new commit
      local new_commits = vim.deepcopy(sample_commits)
      table.insert(new_commits, {
        commit_id = "abc12345",
        change_id = "newcommit",
        author_name = "test",
        author_email = "test@example.com",
        timestamp = "2025-07-25 10:00:00",
        description = "New commit",
        bookmarks = {},
        tags = {},
        conflict_status = "normal"
      })
      
      local result = navigation_integration.refresh_navigation(buffer_id, new_commits)
      
      assert.is_true(result)
      assert.is_true(navigation_integration.is_navigation_enabled(buffer_id))
      
      local commits = navigation_integration.get_buffer_commits(buffer_id)
      assert.equals(3, #commits)
    end)
  end)

  describe("navigation statistics", function()
    it("should provide navigation stats for debugging", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      navigation_integration.init_navigation_for_buffer(buffer_id, sample_commits)
      
      local stats = navigation_integration.get_navigation_stats(buffer_id)
      
      assert.is_not_nil(stats)
      assert.equals(2, stats.commit_count)
      assert.is_true(stats.boundary_count > 0)
      assert.is_boolean(stats.has_highlighted_commit)
    end)

    it("should return nil stats for disabled navigation", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      local stats = navigation_integration.get_navigation_stats(buffer_id)
      
      assert.is_nil(stats)
    end)
  end)

  describe("main integration function", function()
    it("should setup complete navigation integration", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      local result = navigation_integration.setup_navigation_integration(buffer_id, sample_commits, true)
      
      assert.is_true(result)
      assert.is_true(navigation_integration.is_navigation_enabled(buffer_id))
      assert.is_not_nil(mock_keymaps[buffer_id])
      assert.is_not_nil(mock_autocmds[buffer_id])
    end)

    it("should setup integration without auto highlighting", function()
      local buffer_id = create_test_buffer_with_log(sample_log_lines)
      
      local result = navigation_integration.setup_navigation_integration(buffer_id, sample_commits, false)
      
      assert.is_true(result)
      assert.is_true(navigation_integration.is_navigation_enabled(buffer_id))
      assert.is_not_nil(mock_keymaps[buffer_id])
      -- Should not have autocmds when auto_highlight is false
      assert.is_nil(mock_autocmds[buffer_id])
    end)
  end)
end)