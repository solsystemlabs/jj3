-- Tests for jj log rendering functionality
require("helpers.vim_mock")
local test_repo = require("helpers.test_repository")

-- Mock buffer operations
local mock_buffer_lines = {}
local mock_highlight_calls = {}

-- Add buffer operations to vim mock
vim.api.nvim_buf_set_lines = function(buffer, start, end_line, strict_indexing, replacement)
  mock_buffer_lines = replacement
end

vim.api.nvim_buf_get_lines = function(buffer, start, end_line, strict_indexing)
  return mock_buffer_lines
end

vim.api.nvim_buf_set_option = function(buffer, option, value)
  -- Mock buffer option setting
end

vim.api.nvim_buf_add_highlight = function(buffer, ns_id, hl_group, line, col_start, col_end)
  table.insert(mock_highlight_calls, {
    buffer = buffer,
    ns_id = ns_id,
    hl_group = hl_group,
    line = line,
    col_start = col_start,
    col_end = col_end
  })
end

-- Load the renderer module from the plugin directory
local renderer = dofile("lua/jj/log/renderer.lua")

describe("JJ Log Renderer", function()
  local lfs = require('lfs')
  local original_cwd

  before_each(function()
    original_cwd = lfs.currentdir()
    -- Change to test repository for all tests
    lfs.chdir(test_repo.test_repo_path)
    
    -- Reset mocks
    mock_buffer_lines = {}
    mock_highlight_calls = {}
  end)

  after_each(function()
    lfs.chdir(original_cwd)
  end)

  describe("display line generation", function()
    it("should generate display line from commit object", function()
      local commit = {
        commit_id = "abc123def456",
        change_id = "xyz789",
        author_name = "Test User",
        author_email = "test@example.com",
        timestamp = "2025-07-24 15:57:54",
        bookmarks = {"main", "feature"},
        tags = {},
        description = "Test commit description",
        mine = true,
        current_working_copy = false,
        hidden = false,
        empty = false,
        conflict_status = "no conflict",
        graph_line = "○  "
      }
      
      local display_line = renderer.generate_display_line(commit)
      
      assert.is_not_nil(display_line)
      assert.is_string(display_line)
      -- Should contain graph characters
      assert.matches("○", display_line)
      -- Should contain commit ID
      assert.matches("abc123def456", display_line)
      -- Should contain author info
      assert.matches("Test User", display_line)
      assert.matches("test@example.com", display_line)
    end)

    it("should handle working copy commits", function()
      local commit = {
        commit_id = "abc123def456",
        change_id = "xyz789",
        author_name = "Test User",
        author_email = "test@example.com",
        timestamp = "2025-07-24 15:57:54",
        bookmarks = {},
        tags = {},
        description = "Working copy",
        mine = true,
        current_working_copy = true,
        hidden = false,
        empty = false,
        conflict_status = "no conflict",
        graph_line = "@  "
      }
      
      local display_line = renderer.generate_display_line(commit)
      
      assert.is_not_nil(display_line)
      -- Should contain @ symbol for working copy
      assert.matches("@", display_line)
    end)

    it("should handle empty commits", function()
      local commit = {
        commit_id = "abc123def456",
        change_id = "xyz789",
        author_name = "Test User",
        author_email = "test@example.com",
        timestamp = "2025-07-24 15:57:54",
        bookmarks = {},
        tags = {},
        description = "Empty commit",
        mine = true,
        current_working_copy = false,
        hidden = false,
        empty = true,
        conflict_status = "no conflict",
        graph_line = "○  "
      }
      
      local display_line = renderer.generate_display_line(commit)
      
      assert.is_not_nil(display_line)
      -- Should contain (empty) indicator
      assert.matches("%(empty%)", display_line)
    end)

    it("should handle conflict commits", function()
      local commit = {
        commit_id = "abc123def456",
        change_id = "xyz789",
        author_name = "Test User",
        author_email = "test@example.com",
        timestamp = "2025-07-24 15:57:54",
        bookmarks = {},
        tags = {},
        description = "Conflict commit",
        mine = true,
        current_working_copy = false,
        hidden = false,
        empty = false,
        conflict_status = "conflict",
        graph_line = "×  "
      }
      
      local display_line = renderer.generate_display_line(commit)
      
      assert.is_not_nil(display_line)
      -- Should contain × symbol for conflicts
      assert.matches("×", display_line)
      -- Should contain conflict indicator
      assert.matches("conflict", display_line)
    end)

    it("should handle bookmarks and tags", function()
      local commit = {
        commit_id = "abc123def456",
        change_id = "xyz789",
        author_name = "Test User",
        author_email = "test@example.com",
        timestamp = "2025-07-24 15:57:54",
        bookmarks = {"main", "feature"},
        tags = {"v1.0", "release"},
        description = "Tagged commit",
        mine = true,
        current_working_copy = false,
        hidden = false,
        empty = false,
        conflict_status = "no conflict",
        graph_line = "○  "
      }
      
      local display_line = renderer.generate_display_line(commit)
      
      assert.is_not_nil(display_line)
      -- Should contain bookmarks
      assert.matches("main", display_line)
      assert.matches("feature", display_line)
    end)
  end)

  describe("graph and commit info combination", function()
    it("should properly combine graph characters with commit info", function()
      local graph_part = "├─╮  "
      local commit_info = "abc123def456 Test User test@example.com 2025-07-24 15:57:54 main"
      
      local combined = renderer.combine_graph_and_info(graph_part, commit_info)
      
      assert.is_not_nil(combined)
      assert.is_string(combined)
      -- Should start with graph characters
      assert.matches("^├─╮", combined)
      -- Should contain commit info
      assert.matches("abc123def456", combined)
    end)

    it("should handle complex graph structures", function()
      local graph_part = "╭───┼─┬─╮  "
      local commit_info = "xyz789abc123 Complex User user@example.com 2025-07-24 16:00:00"
      
      local combined = renderer.combine_graph_and_info(graph_part, commit_info)
      
      assert.is_not_nil(combined)
      -- Should preserve complex graph characters
      assert.matches("╭───┼─┬─╮", combined)
    end)

    it("should handle empty graph parts", function()
      local graph_part = ""
      local commit_info = "abc123def456 Simple commit"
      
      local combined = renderer.combine_graph_and_info(graph_part, commit_info)
      
      assert.is_not_nil(combined)
      assert.equals(commit_info, combined)
    end)
  end)

  describe("ANSI color preservation", function()
    it("should preserve ANSI color codes in display lines", function()
      local colored_line = "\27[31mRed text\27[0m Normal text \27[32mGreen text\27[0m"
      
      local processed = renderer.preserve_ansi_colors(colored_line)
      
      assert.is_not_nil(processed)
      -- Should still contain ANSI codes
      assert.matches("%[31m", processed)
      assert.matches("%[32m", processed)
      assert.matches("%[0m", processed)
    end)

    it("should handle nested color sequences", function()
      local colored_line = "\27[1m\27[31mBold Red\27[0m\27[32m Green\27[0m"
      
      local processed = renderer.preserve_ansi_colors(colored_line)
      
      assert.is_not_nil(processed)
      -- Should contain all color codes
      assert.matches("%[1m", processed)
      assert.matches("%[31m", processed)
      assert.matches("%[32m", processed)
    end)
  end)

  describe("raw log output processing", function()
    it("should process raw colored jj output", function()
      local raw_output = test_repo.load_snapshot("default_log")
      
      local processed = renderer.process_log_output(raw_output)
      
      assert.is_not_nil(processed)
      assert.is_table(processed)
      assert.is_not_nil(processed.lines)
      assert.is_not_nil(processed.highlights)
      assert.is_table(processed.lines)
      assert.is_table(processed.highlights)
      
      -- Should have multiple lines
      assert.is_true(#processed.lines > 0)
    end)

    it("should generate buffer content from raw output", function()
      local raw_output = "@    nkywompl teernisse@visiostack.com 2025-07-24 15:57:54 b34b2705 conflict\n├─╮  (no description set)\n"
      
      local buffer_lines = renderer.generate_buffer_content(raw_output)
      
      assert.is_not_nil(buffer_lines)
      assert.is_table(buffer_lines)
      assert.is_true(#buffer_lines >= 2)
      
      -- Check content
      local content = table.concat(buffer_lines, "\n")
      assert.matches("nkywompl", content)
      assert.matches("teernisse@visiostack.com", content)
    end)

    it("should handle empty raw output", function()
      local raw_output = ""
      
      local buffer_lines = renderer.generate_buffer_content(raw_output)
      
      assert.is_not_nil(buffer_lines)
      assert.is_table(buffer_lines)
      assert.equals(0, #buffer_lines)
    end)
  end)

  describe("buffer content generation from commits (fallback)", function()
    it("should generate buffer lines from commit list", function()
      local commits = {
        {
          commit_id = "abc123def456",
          change_id = "xyz1",
          author_name = "User1",
          author_email = "user1@example.com",
          timestamp = "2025-07-24 15:57:54",
          bookmarks = {"main"},
          tags = {},
          description = "First commit",
          mine = true,
          current_working_copy = true,
          hidden = false,
          empty = false,
          conflict_status = "no conflict",
          graph_line = "@  "
        },
        {
          commit_id = "def456ghi789",
          change_id = "xyz2",
          author_name = "User2",
          author_email = "user2@example.com",
          timestamp = "2025-07-24 15:50:00",
          bookmarks = {},
          tags = {},
          description = "Second commit",
          mine = false,
          current_working_copy = false,
          hidden = false,
          empty = false,
          conflict_status = "no conflict",
          graph_line = "○  "
        }
      }
      
      local buffer_lines = renderer.generate_buffer_content_from_commits(commits)
      
      assert.is_not_nil(buffer_lines)
      assert.is_table(buffer_lines)
      assert.is_true(#buffer_lines >= 2) -- Should have at least 2 lines for 2 commits
      
      -- Check that commit info is present
      local content = table.concat(buffer_lines, "\n")
      assert.matches("abc123def456", content)
      assert.matches("def456ghi789", content)
      assert.matches("User1", content)
      assert.matches("User2", content)
    end)

    it("should handle empty commit list", function()
      local commits = {}
      
      local buffer_lines = renderer.generate_buffer_content_from_commits(commits)
      
      assert.is_not_nil(buffer_lines)
      assert.is_table(buffer_lines)
      assert.equals(0, #buffer_lines)
    end)
  end)

  describe("buffer management", function()
    it("should render raw output to buffer with proper state management", function()
      local buffer_id = 1
      local raw_output = "@    nkywompl teernisse@visiostack.com 2025-07-24 15:57:54 b34b2705\n├─╮  (no description set)\n"
      
      renderer.render_to_buffer(buffer_id, raw_output)
      
      -- Should have set buffer content
      assert.is_true(#mock_buffer_lines > 0)
      
      -- Should contain commit info
      local content = table.concat(mock_buffer_lines, "\n")
      assert.matches("nkywompl", content)
      assert.matches("teernisse@visiostack.com", content)
    end)

    it("should render commits to buffer (fallback)", function()
      local buffer_id = 1
      local commits = {
        {
          commit_id = "abc123def456",
          change_id = "xyz1",
          author_name = "Test User",
          author_email = "test@example.com",
          timestamp = "2025-07-24 15:57:54",
          bookmarks = {},
          tags = {},
          description = "Test commit",
          mine = true,
          current_working_copy = false,
          hidden = false,
          empty = false,
          conflict_status = "no conflict",
          graph_line = "○  "
        }
      }
      
      renderer.render_commits_to_buffer(buffer_id, commits)
      
      -- Should have set buffer content
      assert.is_true(#mock_buffer_lines > 0)
      
      -- Should contain commit info
      local content = table.concat(mock_buffer_lines, "\n")
      assert.matches("abc123def456", content)
      assert.matches("Test User", content)
    end)

    it("should apply ANSI colors as highlights", function()
      local buffer_id = 1
      local colored_content = {
        "\27[31mRed line\27[0m",
        "\27[32mGreen line\27[0m"
      }
      
      renderer.apply_ansi_highlights(buffer_id, colored_content)
      
      -- Should have made highlight calls
      assert.is_true(#mock_highlight_calls > 0)
      
      -- Should have correct buffer ID
      for _, call in ipairs(mock_highlight_calls) do
        assert.equals(buffer_id, call.buffer)
      end
    end)

    it("should handle buffer clearing and non-modifiable state", function()
      local buffer_id = 1
      
      -- Test that clearing doesn't error
      assert.has_no.errors(function()
        renderer.clear_buffer_content(buffer_id)
      end)
      
      -- Test that setting non-modifiable doesn't error
      assert.has_no.errors(function()
        renderer.set_buffer_non_modifiable(buffer_id)
      end)
    end)
  end)
end)