-- Test repository utilities for jj.nvim testing
local M = {}

-- Path to the complex test repository
M.test_repo_path = "tests/fixtures/complex-repo"

-- Path to snapshot files
M.snapshots_path = "tests/fixtures/snapshots"

-- Available snapshot files
M.snapshots = {
  default_log = "default_log_output.txt",
  colored_log = "colored_log_output.txt", 
  minimal_template = "minimal_template_output.txt",
  comprehensive_template = "comprehensive_template_output.txt"
}

-- Load a snapshot file
function M.load_snapshot(snapshot_name)
  local snapshot_file = M.snapshots[snapshot_name]
  if not snapshot_file then
    error("Unknown snapshot: " .. snapshot_name)
  end
  
  local path = M.snapshots_path .. "/" .. snapshot_file
  local file = io.open(path, "r")
  if not file then
    error("Could not open snapshot file: " .. path)
  end
  
  local content = file:read("*all")
  file:close()
  return content
end

-- Execute jj command in test repository
function M.execute_jj_command(command)
  local full_command = "cd " .. M.test_repo_path .. " && jj " .. command
  local handle = io.popen(full_command)
  local result = handle:read("*all")
  handle:close()
  return result
end

-- Check if test repository exists and is valid
function M.is_test_repo_valid()
  local lfs = require('lfs')
  
  -- Check if repository directory exists
  local repo_attr = lfs.attributes(M.test_repo_path)
  if not repo_attr or repo_attr.mode ~= "directory" then
    return false
  end
  
  -- Check if .jj directory exists
  local jj_dir_attr = lfs.attributes(M.test_repo_path .. "/.jj")
  if not jj_dir_attr or jj_dir_attr.mode ~= "directory" then
    return false
  end
  
  return true
end

-- Get expected commit count from test repository
function M.get_expected_commit_count()
  if not M.is_test_repo_valid() then
    return 0
  end
  
  local output = M.execute_jj_command("log --template 'commit_id ++ \"\\n\"'")
  local count = 0
  for _ in output:gmatch("[^\n]+") do
    count = count + 1
  end
  return count
end

-- Get list of bookmarks in test repository
function M.get_expected_bookmarks()
  if not M.is_test_repo_valid() then
    return {}
  end
  
  local output = M.execute_jj_command("bookmark list")
  local bookmarks = {}
  for bookmark in output:gmatch("([%w%-]+):") do
    table.insert(bookmarks, bookmark)
  end
  return bookmarks
end

-- Test repository documentation
M.repository_structure = {
  description = "Complex jj repository with multiple branching patterns",
  features = {
    "Linear history with multiple commits",
    "Parallel development branches",
    "Merge commits with 2+ parents", 
    "Conflict resolution commits",
    "Empty commits",
    "Abandoned commits",
    "Multiple bookmarks",
    "GitHub integration (git_head markers)",
    "Complex graph with elided revisions"
  },
  bookmarks = {
    "feature-a", "feature-b", "branch-a", "branch-b", 
    "sub-branch-a", "hotfix", "mega-merge", "main"
  },
  conflict_scenarios = {
    "shared.txt conflicts between branches",
    "Multi-parent merge conflicts",
    "Resolved and unresolved conflict states"
  }
}

return M