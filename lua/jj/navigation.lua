-- JJ commit-aware navigation functionality
local M = {}

-- Namespace for commit highlighting
local HIGHLIGHT_NAMESPACE = vim.api.nvim_create_namespace("jj_commit_navigation")
local HIGHLIGHT_GROUP = "JJCommitBlock"

-- Initialize highlight group for commit blocks
local function setup_highlight_groups()
  -- Define JJCommitBlock highlight group with background color for full-width highlighting
  vim.api.nvim_set_hl(0, "JJCommitBlock", {
    bg = "#3d4f5c",    -- Dark blue-gray background
    fg = "#ffffff",    -- White text for contrast
    ctermbg = 8,       -- Dark gray for terminal
    ctermfg = 15       -- White for terminal
  })
end

-- Call setup on module load
setup_highlight_groups()

-- Create a commit block data structure
function M.create_commit_block(commit_id, change_id, start_line, end_line, commit_data)
  -- Validate inputs
  if not commit_id or not start_line or not end_line then
    return nil
  end
  
  if start_line < 1 or end_line < start_line then
    return nil
  end
  
  return {
    commit_id = commit_id,
    change_id = change_id or "",
    start_line = start_line,
    end_line = end_line,
    commit_data = commit_data,
    line_count = end_line - start_line + 1
  }
end

-- Validate commit block structure
function M.is_valid_commit_block(block)
  if not block then
    return false
  end
  
  -- Check that all required fields exist and have correct types
  if not block.commit_id or type(block.commit_id) ~= "string" or block.commit_id == "" then
    return false
  end
  
  if not block.start_line or type(block.start_line) ~= "number" then
    return false
  end
  
  if not block.end_line or type(block.end_line) ~= "number" then
    return false
  end
  
  if block.start_line < 1 or block.end_line < block.start_line then
    return false
  end
  
  return true
end

-- Detect commit boundaries by mapping parsed commits to buffer line positions
function M.detect_commit_boundaries(buffer_id, commits)
  
  if not buffer_id or not commits then
    return {}
  end

  local boundaries = {}
  local buffer_lines = vim.api.nvim_buf_get_lines(buffer_id, 0, -1, false)
  
  if not buffer_lines or #buffer_lines == 0 then
    return boundaries
  end
  

  -- Process commits in the order they appear in the parsed data
  for commit_idx, commit in ipairs(commits) do
    local start_line = nil
    local end_line = nil
    
    -- Find the line containing this commit's ID (check both full and short versions)
    for line_index = 1, #buffer_lines do
      local line = buffer_lines[line_index]
      
      -- Check if this line contains the commit ID (full version or 8+ char prefix)
      local commit_id_full = commit.commit_id
      local commit_id_short = commit_id_full:sub(1, 8) -- Get first 8 characters
      
      if line:find(commit_id_full, 1, true) or line:find(commit_id_short, 1, true) then
        start_line = line_index
        end_line = line_index
        
        -- Look for the next line to see if it's a description
        if line_index + 1 <= #buffer_lines then
          local next_line = buffer_lines[line_index + 1]
          
          -- Check if next line looks like a description (starts with graph chars and has content)
          -- Description lines often start with graph characters followed by spaces and text
          if next_line:match("^[│├─╮╯~%s]*%([^%)]*%)") or -- Pattern like "(no description set)"
             next_line:match("^[│├─╮╯~%s]*[%w]") then -- Pattern with alphanumeric content
            end_line = line_index + 1
          end
        end
        
        -- Add boundary for this commit using the data structure
        local commit_block = M.create_commit_block(
          commit.commit_id,
          commit.change_id,
          start_line,
          end_line,
          commit
        )
        
        -- Only add valid commit blocks
        if M.is_valid_commit_block(commit_block) then
          table.insert(boundaries, commit_block)
        end
        
        break -- Found this commit, move to next
      end
    end
  end
  
  -- Sort boundaries by start_line to ensure correct display order
  table.sort(boundaries, function(a, b)
    return a.start_line < b.start_line
  end)
  
  return boundaries
end

-- Get commit at current cursor position
function M.get_commit_at_cursor(buffer_id, window_id, boundaries)
  if not buffer_id or not window_id or not boundaries then
    return nil
  end

  local cursor_pos = vim.api.nvim_win_get_cursor(window_id)
  local cursor_line = cursor_pos[1]
  
  -- Find which commit boundary contains the cursor line
  for _, boundary in ipairs(boundaries) do
    if cursor_line >= boundary.start_line and cursor_line <= boundary.end_line then
      return boundary
    end
  end
  
  return nil
end

-- Common validation for navigation functions
local function validate_navigation_params(buffer_id, window_id, boundaries)
  return buffer_id and window_id and boundaries and #boundaries > 0
end

-- Find the current commit index based on cursor position
local function find_current_commit_index(window_id, boundaries)
  local cursor_pos = vim.api.nvim_win_get_cursor(window_id)
  local cursor_line = cursor_pos[1]
  
  for i, boundary in ipairs(boundaries) do
    if cursor_line >= boundary.start_line and cursor_line <= boundary.end_line then
      return i, cursor_line
    end
  end
  
  return nil, cursor_line
end

-- Navigate to the next commit (j key functionality)
function M.navigate_to_next_commit(buffer_id, window_id, boundaries)
  if not validate_navigation_params(buffer_id, window_id, boundaries) then
    return false
  end

  local current_commit_index, cursor_line = find_current_commit_index(window_id, boundaries)
  
  -- If cursor is not on any commit, find the first commit after current line
  if not current_commit_index then
    for i, boundary in ipairs(boundaries) do
      if boundary.start_line > cursor_line then
        vim.api.nvim_win_set_cursor(window_id, {boundary.start_line, 0})
        return true
      end
    end
    return false
  end
  
  -- Move to next commit if available
  if current_commit_index < #boundaries then
    local next_boundary = boundaries[current_commit_index + 1]
    vim.api.nvim_win_set_cursor(window_id, {next_boundary.start_line, 0})
    return true
  end
  
  return false -- Already at last commit
end

-- Navigate to the previous commit (k key functionality)
function M.navigate_to_previous_commit(buffer_id, window_id, boundaries)
  if not validate_navigation_params(buffer_id, window_id, boundaries) then
    return false
  end

  local current_commit_index, cursor_line = find_current_commit_index(window_id, boundaries)
  
  -- If cursor is not on any commit, find the first commit before current line
  if not current_commit_index then
    for i = #boundaries, 1, -1 do
      local boundary = boundaries[i]
      if boundary.end_line < cursor_line then
        vim.api.nvim_win_set_cursor(window_id, {boundary.start_line, 0})
        return true
      end
    end
    return false
  end
  
  -- Move to previous commit if available
  if current_commit_index > 1 then
    local prev_boundary = boundaries[current_commit_index - 1]
    vim.api.nvim_win_set_cursor(window_id, {prev_boundary.start_line, 0})
    return true
  end
  
  return false -- Already at first commit
end

-- Setup buffer-local keymaps for commit navigation
function M.setup_commit_navigation_keymaps(buffer_id, boundaries)
  if not buffer_id or not boundaries then
    return false
  end
  
  -- Define j key mapping for next commit
  vim.api.nvim_buf_set_keymap(buffer_id, 'n', 'j', '', {
    noremap = true,
    silent = true,
    callback = function()
      local window_id = vim.api.nvim_get_current_win()
      if not M.navigate_to_next_commit(buffer_id, window_id, boundaries) then
        -- If navigation failed, fall back to normal j movement
        vim.api.nvim_feedkeys('j', 'n', false)
      end
    end
  })
  
  -- Define k key mapping for previous commit  
  vim.api.nvim_buf_set_keymap(buffer_id, 'n', 'k', '', {
    noremap = true,
    silent = true,
    callback = function()
      local window_id = vim.api.nvim_get_current_win()
      if not M.navigate_to_previous_commit(buffer_id, window_id, boundaries) then
        -- If navigation failed, fall back to normal k movement
        vim.api.nvim_feedkeys('k', 'n', false)
      end
    end
  })
  
  return true
end

-- Highlight a commit block to show it's currently selected
function M.highlight_commit_block(buffer_id, commit_block)
  if not buffer_id or not commit_block or not M.is_valid_commit_block(commit_block) then
    return false
  end
  
  -- Clear any existing highlights first
  M.clear_commit_highlights(buffer_id)
  
  -- Highlight all lines in the commit block with full window width
  for line_num = commit_block.start_line, commit_block.end_line do
    -- Convert to 0-indexed for vim.api
    local zero_indexed_line = line_num - 1
    
    -- Use extmark with hl_eol to highlight entire line width (no end_col needed)
    vim.api.nvim_buf_set_extmark(
      buffer_id,
      HIGHLIGHT_NAMESPACE,
      zero_indexed_line,
      0,
      {
        hl_group = HIGHLIGHT_GROUP,
        hl_eol = true,  -- This extends highlighting to end of window
        line_hl_group = HIGHLIGHT_GROUP  -- This highlights the entire line
      }
    )
  end
  
  return true
end

-- Clear all commit highlighting from buffer
function M.clear_commit_highlights(buffer_id)
  if not buffer_id then
    return false
  end
  
  -- Clear all highlights in our namespace
  vim.api.nvim_buf_clear_namespace(buffer_id, HIGHLIGHT_NAMESPACE, 0, -1)
  
  return true
end

-- Helper function to add highlighting after navigation
local function navigate_with_highlight(navigation_func, buffer_id, window_id, boundaries)
  if navigation_func(buffer_id, window_id, boundaries) then
    -- Get the current commit after navigation and highlight it
    local current_commit = M.get_commit_at_cursor(buffer_id, window_id, boundaries)
    if current_commit then
      M.highlight_commit_block(buffer_id, current_commit)
    end
    return true
  end
  return false
end

-- Update navigation functions to include highlighting
function M.navigate_to_next_commit_with_highlight(buffer_id, window_id, boundaries)
  return navigate_with_highlight(M.navigate_to_next_commit, buffer_id, window_id, boundaries)
end

function M.navigate_to_previous_commit_with_highlight(buffer_id, window_id, boundaries)
  return navigate_with_highlight(M.navigate_to_previous_commit, buffer_id, window_id, boundaries)
end

-- Navigate to the first commit (gg functionality)
function M.navigate_to_first_commit(buffer_id, window_id, boundaries)
  if not validate_navigation_params(buffer_id, window_id, boundaries) then
    return false
  end

  local first_boundary = boundaries[1]
  vim.api.nvim_win_set_cursor(window_id, {first_boundary.start_line, 0})
  return true
end

-- Navigate to the last commit (G functionality)
function M.navigate_to_last_commit(buffer_id, window_id, boundaries)
  if not validate_navigation_params(buffer_id, window_id, boundaries) then
    return false
  end

  local last_boundary = boundaries[#boundaries]
  vim.api.nvim_win_set_cursor(window_id, {last_boundary.start_line, 0})
  return true
end

-- Navigate to first commit with highlighting
function M.navigate_to_first_commit_with_highlight(buffer_id, window_id, boundaries)
  return navigate_with_highlight(M.navigate_to_first_commit, buffer_id, window_id, boundaries)
end

-- Navigate to last commit with highlighting
function M.navigate_to_last_commit_with_highlight(buffer_id, window_id, boundaries)
  return navigate_with_highlight(M.navigate_to_last_commit, buffer_id, window_id, boundaries)
end

-- Helper function to create keymap with fallback
local function create_navigation_keymap(buffer_id, key, navigation_func, fallback_key, boundaries)
  vim.api.nvim_buf_set_keymap(buffer_id, 'n', key, '', {
    noremap = true,
    silent = true,
    callback = function()
      local window_id = vim.api.nvim_get_current_win()
      if not navigation_func(buffer_id, window_id, boundaries) then
        -- If navigation failed, fall back to normal movement
        vim.api.nvim_feedkeys(fallback_key or key, 'n', false)
      end
    end
  })
end

-- Enhanced keymap setup that includes highlighting
function M.setup_commit_navigation_keymaps_with_highlight(buffer_id, boundaries)
  if not buffer_id or not boundaries then
    return false
  end
  
  -- Setup all navigation keymaps
  local keymaps = {
    {key = 'j', func = M.navigate_to_next_commit_with_highlight},
    {key = 'k', func = M.navigate_to_previous_commit_with_highlight},
    {key = 'gg', func = M.navigate_to_first_commit_with_highlight},
    {key = 'G', func = M.navigate_to_last_commit_with_highlight}
  }
  
  for _, keymap in ipairs(keymaps) do
    create_navigation_keymap(buffer_id, keymap.key, keymap.func, keymap.key, boundaries)
  end
  
  return true
end

return M