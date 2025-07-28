-- Navigation integration module for jj.nvim
-- Connects commit-aware navigation with existing plugin architecture
local M = {}

-- Import required modules
local navigation = require("jj.navigation")
local highlight = require("jj.ui.highlight")

-- Store navigation state per buffer
local buffer_navigation_state = {}

-- Initialize navigation for a jj log buffer
function M.init_navigation_for_buffer(buffer_id, commits)
  
  if not buffer_id or not commits or #commits == 0 then
    return false
  end
  
  -- Detect commit boundaries using the parsed commits
  local boundaries = navigation.detect_commit_boundaries(buffer_id, commits)
  
  if #boundaries == 0 then
    return false
  end
  
  -- Store navigation state
  buffer_navigation_state[buffer_id] = {
    boundaries = boundaries,
    commits = commits,
    last_highlighted_commit = nil
  }
  
  -- Setup enhanced keymaps with highlighting
  local success = navigation.setup_commit_navigation_keymaps_with_highlight(buffer_id, boundaries)
  
  -- Highlight the first commit initially if cursor is on it
  local window_id = vim.api.nvim_get_current_win()
  if window_id then
    local current_commit = navigation.get_commit_at_cursor(buffer_id, window_id, boundaries)
    if current_commit then
      navigation.highlight_commit_block(buffer_id, current_commit)
      buffer_navigation_state[buffer_id].last_highlighted_commit = current_commit
    end
  end
  
  return success
end

-- Clean up navigation state for a buffer
function M.cleanup_navigation_for_buffer(buffer_id)
  if not buffer_id then
    return false
  end
  
  -- Clear highlights
  navigation.clear_commit_highlights(buffer_id)
  
  -- Remove navigation state
  buffer_navigation_state[buffer_id] = nil
  
  return true
end

-- Get navigation boundaries for a buffer
function M.get_navigation_boundaries(buffer_id)
  if not buffer_id or not buffer_navigation_state[buffer_id] then
    return nil
  end
  
  return buffer_navigation_state[buffer_id].boundaries
end

-- Get commits for a buffer
function M.get_buffer_commits(buffer_id)
  if not buffer_id or not buffer_navigation_state[buffer_id] then
    return nil
  end
  
  return buffer_navigation_state[buffer_id].commits
end

-- Update navigation when buffer content changes
function M.refresh_navigation(buffer_id, new_commits)
  if not buffer_id then
    return false
  end
  
  -- Clean up existing navigation
  M.cleanup_navigation_for_buffer(buffer_id)
  
  -- Re-initialize with new commits
  return M.init_navigation_for_buffer(buffer_id, new_commits)
end

-- Check if navigation is enabled for a buffer
function M.is_navigation_enabled(buffer_id)
  return buffer_id and buffer_navigation_state[buffer_id] ~= nil
end

-- Get current commit at cursor position
function M.get_current_commit(buffer_id, window_id)
  if not M.is_navigation_enabled(buffer_id) or not window_id then
    return nil
  end
  
  local boundaries = buffer_navigation_state[buffer_id].boundaries
  return navigation.get_commit_at_cursor(buffer_id, window_id, boundaries)
end

-- Manually trigger commit highlighting (useful for cursor moved events)
function M.update_commit_highlighting(buffer_id, window_id)
  if not M.is_navigation_enabled(buffer_id) or not window_id then
    return false
  end
  
  local current_commit = M.get_current_commit(buffer_id, window_id)
  local state = buffer_navigation_state[buffer_id]
  
  -- Only update highlighting if we've moved to a different commit
  if current_commit and 
     (not state.last_highlighted_commit or 
      current_commit.commit_id ~= state.last_highlighted_commit.commit_id) then
    
    navigation.highlight_commit_block(buffer_id, current_commit)
    state.last_highlighted_commit = current_commit
    return true
  elseif not current_commit and state.last_highlighted_commit then
    -- Cursor moved outside any commit, clear highlights
    navigation.clear_commit_highlights(buffer_id)
    state.last_highlighted_commit = nil
    return true
  end
  
  return false
end

-- Setup automatic highlighting on cursor movement (optional feature)
function M.setup_auto_highlighting(buffer_id)
  if not M.is_navigation_enabled(buffer_id) then
    return false
  end
  
  -- Create autocmd for cursor movement
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = buffer_id,
    callback = function()
      local window_id = vim.api.nvim_get_current_win()
      if window_id then
        M.update_commit_highlighting(buffer_id, window_id)
      end
    end,
    group = vim.api.nvim_create_augroup("JJNavigation_" .. buffer_id, { clear = true })
  })
  
  return true
end

-- Remove automatic highlighting
function M.remove_auto_highlighting(buffer_id)
  if not buffer_id then
    return false
  end
  
  -- Clear the autocmd group
  pcall(vim.api.nvim_del_augroup_by_name, "JJNavigation_" .. buffer_id)
  
  return true
end

-- Get navigation statistics for debugging
function M.get_navigation_stats(buffer_id)
  if not M.is_navigation_enabled(buffer_id) then
    return nil
  end
  
  local state = buffer_navigation_state[buffer_id]
  return {
    commit_count = #state.commits,
    boundary_count = #state.boundaries,
    has_highlighted_commit = state.last_highlighted_commit ~= nil,
    highlighted_commit_id = state.last_highlighted_commit and state.last_highlighted_commit.commit_id or nil
  }
end

-- Check if buffer is a jj log buffer (integration helper)
function M.is_jj_log_buffer(buffer_id)
  if not buffer_id then
    return false
  end
  
  -- Check buffer name and filetype
  local buf_name = vim.api.nvim_buf_get_name(buffer_id)
  local filetype = vim.api.nvim_buf_get_option(buffer_id, 'filetype')
  
  return (buf_name and buf_name:match("JJ Log") ~= nil) or filetype == "jj"
end

-- Main integration function - call this when setting up a jj log window
function M.setup_navigation_integration(buffer_id, commits, auto_highlight)
  if not buffer_id or not commits then
    return false
  end
  
  -- Setup highlight groups if not already done
  highlight.setup_navigation_highlights()
  
  -- Initialize basic navigation
  local success = M.init_navigation_for_buffer(buffer_id, commits)
  
  if success and auto_highlight then
    -- Setup automatic highlighting on cursor movement
    M.setup_auto_highlighting(buffer_id)
  end
  
  return success
end

-- Clean up all navigation integrations (called on plugin cleanup)
function M.cleanup_all_navigation()
  for buffer_id, _ in pairs(buffer_navigation_state) do
    M.remove_auto_highlighting(buffer_id)
    M.cleanup_navigation_for_buffer(buffer_id)
  end
  
  buffer_navigation_state = {}
  
  return true
end

return M