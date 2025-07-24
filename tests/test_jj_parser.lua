-- Tests for jj log parsing functionality
require("helpers.vim_mock")
local test_repo = require("helpers.test_repository")

-- Load the parser module from the plugin directory
local parser = dofile("lua/jj/log/parser.lua")

describe("JJ Log Parser", function()
  local lfs = require('lfs')
  local original_cwd

  before_each(function()
    original_cwd = lfs.currentdir()
    -- Change to test repository for all tests
    lfs.chdir(test_repo.test_repo_path)
  end)

  after_each(function()
    lfs.chdir(original_cwd)
  end)

  describe("minimal template parsing", function()
    it("should parse commit IDs from minimal template output", function()
      local minimal_output = test_repo.load_snapshot("minimal_template")
      local commit_ids = parser.parse_commit_ids(minimal_output)
      
      assert.is_not_nil(commit_ids)
      assert.is_table(commit_ids)
      assert.is_true(#commit_ids > 10) -- Should have many commits
      
      -- Check that each commit ID looks valid (hex string)
      for _, commit_id in ipairs(commit_ids) do
        assert.is_string(commit_id)
        assert.is_true(#commit_id >= 8) -- At least 8 characters
        assert.is_true(commit_id:match("^%x+$") ~= nil) -- Only hex characters
      end
    end)

    it("should handle empty minimal output", function()
      local commit_ids = parser.parse_commit_ids("")
      
      assert.is_not_nil(commit_ids)
      assert.is_table(commit_ids)
      assert.equals(0, #commit_ids)
    end)

    it("should handle malformed minimal output", function()
      local malformed_output = "not-a-commit-id\x00invalid-change-id\n"
      local commit_ids = parser.parse_commit_ids(malformed_output)
      
      assert.is_not_nil(commit_ids)
      assert.is_table(commit_ids)
      -- Should still extract the first field as commit ID
      assert.equals(1, #commit_ids)
      assert.equals("not-a-commit-id", commit_ids[1])
    end)
  end)

  describe("comprehensive template parsing", function()
    it("should parse full commit data from comprehensive template output", function()
      local comprehensive_output = test_repo.load_snapshot("comprehensive_template")
      local commits = parser.parse_comprehensive_log(comprehensive_output)
      
      assert.is_not_nil(commits)
      assert.is_table(commits)
      assert.is_true(#commits > 10) -- Should have many commits
      
      -- Check structure of first commit
      local first_commit = commits[1]
      assert.is_not_nil(first_commit.commit_id)
      assert.is_not_nil(first_commit.change_id)
      assert.is_not_nil(first_commit.author_name)
      assert.is_not_nil(first_commit.author_email)
      assert.is_not_nil(first_commit.timestamp)
      assert.is_not_nil(first_commit.conflict_status)
      assert.is_not_nil(first_commit.empty_status)
      assert.is_not_nil(first_commit.hidden_status)
    end)

    it("should handle commits with different statuses", function()
      local comprehensive_output = test_repo.load_snapshot("comprehensive_template")
      local commits = parser.parse_comprehensive_log(comprehensive_output)
      
      -- Should have commits with different statuses
      local has_conflict = false
      local has_empty = false
      local has_normal = false
      
      for _, commit in ipairs(commits) do
        if commit.conflict_status == "conflict" then
          has_conflict = true
        end
        if commit.empty_status == "empty" then
          has_empty = true
        end
        if commit.conflict_status == "normal" then
          has_normal = true
        end
      end
      
      assert.is_true(has_conflict, "Should have conflict commits")
      assert.is_true(has_empty, "Should have empty commits")
      assert.is_true(has_normal, "Should have normal commits")
    end)

    it("should handle commits with bookmarks and descriptions", function()
      local comprehensive_output = test_repo.load_snapshot("comprehensive_template")
      local commits = parser.parse_comprehensive_log(comprehensive_output)
      
      -- Should have commits with bookmarks
      local has_bookmarks = false
      local has_descriptions = false
      
      for _, commit in ipairs(commits) do
        if commit.bookmarks and #commit.bookmarks > 0 then
          has_bookmarks = true
        end
        if commit.description and #commit.description > 0 then
          has_descriptions = true
        end
      end
      
      assert.is_true(has_bookmarks, "Should have commits with bookmarks")
      assert.is_true(has_descriptions, "Should have commits with descriptions")
    end)

    it("should handle empty comprehensive output", function()
      local commits = parser.parse_comprehensive_log("")
      
      assert.is_not_nil(commits)
      assert.is_table(commits)
      assert.equals(0, #commits)
    end)
  end)

  describe("graph parsing", function()
    it("should parse graph structure from default log output", function()
      local default_output = test_repo.load_snapshot("default_log")
      local graph_lines = parser.parse_graph_lines(default_output)
      
      assert.is_not_nil(graph_lines)
      assert.is_table(graph_lines)
      assert.is_true(#graph_lines > 10) -- Should have many graph lines
      
      -- Check that each line has graph characters and commit info
      for i, line in ipairs(graph_lines) do
        assert.is_not_nil(line.graph)
        assert.is_not_nil(line.commit_info)
        assert.is_string(line.graph)
        assert.is_string(line.commit_info)
        
        -- Graph should contain typical graph characters
        if line.graph:find("[│├─╮╯○×@◆~]") then
          -- Found graph characters - good
        else
          -- First line might not have graph chars, but others should
          if i > 1 then
            assert.is_true(false, "Line " .. i .. " should contain graph characters: " .. line.graph)
          end
        end
      end
    end)

    it("should extract commit markers from graph lines", function()
      local default_output = test_repo.load_snapshot("default_log")
      local graph_lines = parser.parse_graph_lines(default_output)
      
      -- Should find various commit markers
      local markers_found = {}
      for _, line in ipairs(graph_lines) do
        if line.graph:find("@") then markers_found["working_copy"] = true end
        if line.graph:find("○") then markers_found["commit"] = true end
        if line.graph:find("×") then markers_found["conflict"] = true end
        if line.graph:find("◆") then markers_found["bookmark"] = true end
      end
      
      assert.is_true(markers_found["working_copy"] or markers_found["commit"], 
                     "Should find commit markers")
    end)

    it("should handle colored graph output", function()
      local colored_output = test_repo.load_snapshot("colored_log")
      local graph_lines = parser.parse_graph_lines(colored_output)
      
      assert.is_not_nil(graph_lines)
      assert.is_table(graph_lines)
      assert.is_true(#graph_lines > 10)
      
      -- Should handle ANSI escape sequences
      local has_ansi = false
      for _, line in ipairs(graph_lines) do
        if line.commit_info:find("\027%[") then -- \027 is ESC character
          has_ansi = true
          break
        end
      end
      
      assert.is_true(has_ansi, "Colored output should contain ANSI escape sequences")
    end)
  end)

  describe("dual-pass parsing workflow", function()
    it("should perform complete dual-pass parsing", function()
      local result = parser.parse_jj_log_dual_pass()
      
      assert.is_not_nil(result)
      assert.is_not_nil(result.success)
      assert.is_true(result.success)
      assert.is_not_nil(result.commits)
      assert.is_not_nil(result.graph_lines)
      assert.is_not_nil(result.commit_map)
      
      -- Should have commits and graph lines
      assert.is_true(#result.commits > 10)
      assert.is_true(#result.graph_lines > 10)
      
      -- Commit map should map commit IDs to commit data
      assert.is_table(result.commit_map)
      local first_commit = result.commits[1]
      assert.is_not_nil(result.commit_map[first_commit.commit_id])
    end)

    it("should correlate graph positions with commit data", function()
      local result = parser.parse_jj_log_dual_pass()
      
      assert.is_true(result.success)
      
      -- Check that we can find commits by their IDs in the graph
      local commit_ids_in_graph = {}
      for _, line in ipairs(result.graph_lines) do
        -- Extract commit ID from graph line (this is implementation specific)
        local commit_id = parser.extract_commit_id_from_graph_line(line)
        if commit_id then
          commit_ids_in_graph[commit_id] = true
        end
      end
      
      -- Should have found multiple commit IDs
      local count = 0
      for _ in pairs(commit_ids_in_graph) do
        count = count + 1
      end
      assert.is_true(count > 5, "Should find multiple commit IDs in graph")
    end)

    it("should handle parsing errors gracefully", function()
      -- Mock the executor to return an error
      local original_execute = require("jj.log.executor").execute_minimal_log
      require("jj.log.executor").execute_minimal_log = function()
        return { success = false, error = "Mock error" }
      end
      
      local result = parser.parse_jj_log_dual_pass()
      
      assert.is_not_nil(result)
      assert.is_false(result.success)
      assert.is_not_nil(result.error)
      
      -- Restore original function
      require("jj.log.executor").execute_minimal_log = original_execute
    end)
  end)

  describe("commit data structures", function()
    it("should create valid commit objects", function()
      local commit_data = {
        "commit123", "change456", "John Doe", "john@example.com",
        "2025-01-01 12:00:00", "main,feature", "v1.0", "",
        "normal", "normal", "normal", "Initial commit", ""
      }
      
      local commit = parser.create_commit_object(commit_data)
      
      assert.is_not_nil(commit)
      assert.equals("commit123", commit.commit_id)
      assert.equals("change456", commit.change_id)
      assert.equals("John Doe", commit.author_name)
      assert.equals("john@example.com", commit.author_email)
      assert.equals("2025-01-01 12:00:00", commit.timestamp)
      assert.is_table(commit.bookmarks)
      assert.equals("main", commit.bookmarks[1])
      assert.equals("feature", commit.bookmarks[2])
      assert.equals("normal", commit.conflict_status)
      assert.equals("normal", commit.empty_status)
      assert.equals("normal", commit.hidden_status)
      assert.equals("Initial commit", commit.description)
    end)

    it("should handle missing or empty fields", function()
      local commit_data = {
        "commit123", "change456", "", "",
        "", "", "", "",
        "", "", "", "", ""
      }
      
      local commit = parser.create_commit_object(commit_data)
      
      assert.is_not_nil(commit)
      assert.equals("commit123", commit.commit_id)
      assert.equals("", commit.author_name)
      assert.is_table(commit.bookmarks)
      assert.equals(0, #commit.bookmarks) -- Empty bookmarks
    end)
  end)
end)