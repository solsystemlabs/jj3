-- Disposable test repository utilities for command execution testing
-- This creates temporary jj repositories that can be safely wiped/recreated
local M = {}

local lfs = require('lfs')

-- Base path for disposable test repositories  
M.base_path = "tests/fixtures/disposable"

-- Current disposable repo path
M.current_repo_path = nil

-- Create a new disposable jj repository for testing
function M.create_disposable_repo(repo_name)
  repo_name = repo_name or "temp-" .. os.time()
  local repo_path = M.base_path .. "/" .. repo_name
  
  -- Ensure base directory exists
  local base_attr = lfs.attributes(M.base_path)
  if not base_attr then
    lfs.mkdir(M.base_path)
  end
  
  -- Remove existing repo if it exists
  M.remove_repo(repo_path)
  
  -- Create repo directory
  lfs.mkdir(repo_path)
  
  -- Initialize jj repository (use git backend)
  local init_command = "cd " .. repo_path .. " && jj git init"
  local handle = io.popen(init_command .. " 2>&1")
  local result = handle:read("*all")
  local success = handle:close()
  
  if not success then
    error("Failed to initialize jj repository: " .. result)
  end
  
  -- Create initial commit
  local initial_file = repo_path .. "/README.md"
  local file = io.open(initial_file, "w")
  file:write("# Test Repository\n\nThis is a disposable test repository.\n")
  file:close()
  
  local commit_command = "cd " .. repo_path .. " && jj commit -m 'Initial commit'"
  handle = io.popen(commit_command .. " 2>&1")
  result = handle:read("*all")
  success = handle:close()
  
  if not success then
    error("Failed to create initial commit: " .. result)
  end
  
  M.current_repo_path = repo_path
  return repo_path
end

-- Execute jj command in the current disposable repository
function M.execute_jj_command(command)
  if not M.current_repo_path then
    error("No disposable repository is currently active")
  end
  
  local full_command = "cd " .. M.current_repo_path .. " && jj " .. command .. " 2>&1"
  local handle = io.popen(full_command)
  local result = handle:read("*all")
  local success = handle:close()
  
  return {
    output = result,
    success = success,
    command = command
  }
end

-- Create test commits for testing auto-refresh
function M.create_test_commits(count)
  count = count or 3
  local commits = {}
  
  for i = 1, count do
    -- Create a test file
    local test_file = M.current_repo_path .. "/test_file_" .. i .. ".txt"
    local file = io.open(test_file, "w")
    file:write("Test content for commit " .. i .. "\n")
    file:close()
    
    -- Commit the file
    local commit_result = M.execute_jj_command("commit -m 'Test commit " .. i .. "'")
    if commit_result.success then
      table.insert(commits, "Test commit " .. i)
    end
  end
  
  return commits
end

-- Create a test bookmark
function M.create_test_bookmark(name, description)
  name = name or "test-bookmark-" .. os.time()
  description = description or "Test bookmark"
  
  local result = M.execute_jj_command("bookmark create " .. name)
  return result.success, name
end

-- Remove a specific repository directory
function M.remove_repo(repo_path)
  if not repo_path then
    return
  end
  
  -- Use rm -rf to remove directory (cross-platform alternative needed for Windows)
  local remove_command = "rm -rf " .. repo_path
  os.execute(remove_command)
end

-- Clean up current disposable repository
function M.cleanup_current_repo()
  if M.current_repo_path then
    M.remove_repo(M.current_repo_path)
    M.current_repo_path = nil
  end
end

-- Clean up all disposable repositories
function M.cleanup_all_repos()
  local remove_command = "rm -rf " .. M.base_path
  os.execute(remove_command)
  M.current_repo_path = nil
end

-- Check if current repo is valid
function M.is_current_repo_valid()
  if not M.current_repo_path then
    return false
  end
  
  local jj_dir_attr = lfs.attributes(M.current_repo_path .. "/.jj")
  return jj_dir_attr and jj_dir_attr.mode == "directory"
end

-- Get current repository path
function M.get_current_repo_path()
  return M.current_repo_path
end

-- Get working directory for changing into repo
function M.get_working_directory()
  return M.current_repo_path
end

return M