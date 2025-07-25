-- JJ commit-aware navigation functionality
local M = {}

-- Namespace for commit highlighting
local HIGHLIGHT_NAMESPACE = vim.api.nvim_create_namespace("jj_commit_navigation")
local HIGHLIGHT_GROUP = "JJCommitBlock"

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
  for _, commit in ipairs(commits) do
    local start_line = nil
    local end_line = nil
    
    -- Find the line containing this commit's ID
    for line_index = 1, #buffer_lines do
      local line = buffer_lines[line_index]
      
      -- Check if this line contains the commit ID
      if line:find(commit.commit_id, 1, true) then
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

-- Navigate to the next commit (j key functionality)
function M.navigate_to_next_commit(buffer_id, window_id, boundaries)
  if not buffer_id or not window_id or not boundaries or #boundaries == 0 then
    return false
  end

  local cursor_pos = vim.api.nvim_win_get_cursor(window_id)
  local cursor_line = cursor_pos[1]
  
  -- Find current commit
  local current_commit_index = nil
  for i, boundary in ipairs(boundaries) do
    if cursor_line >= boundary.start_line and cursor_line <= boundary.end_line then
      current_commit_index = i
      break
    end
  end
  
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
  if not buffer_id or not window_id or not boundaries or #boundaries == 0 then
    return false
  end

  local cursor_pos = vim.api.nvim_win_get_cursor(window_id)
  local cursor_line = cursor_pos[1]
  
  -- Find current commit
  local current_commit_index = nil
  for i, boundary in ipairs(boundaries) do
    if cursor_line >= boundary.start_line and cursor_line <= boundary.end_line then
      current_commit_index = i
      break
    end
  end
  
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
  
  -- Highlight all lines in the commit block
  for line_num = commit_block.start_line, commit_block.end_line do
    -- Convert to 0-indexed for vim.api
    local zero_indexed_line = line_num - 1
    
    -- Highlight the entire line (col_start=0, col_end=-1 means entire line)
    vim.api.nvim_buf_add_highlight(
      buffer_id,
      HIGHLIGHT_NAMESPACE,
      HIGHLIGHT_GROUP,
      zero_indexed_line,
      0,
      -1
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

-- Update navigation functions to include highlighting
function M.navigate_to_next_commit_with_highlight(buffer_id, window_id, boundaries)
  if M.navigate_to_next_commit(buffer_id, window_id, boundaries) then
    -- Get the current commit after navigation and highlight it
    local current_commit = M.get_commit_at_cursor(buffer_id, window_id, boundaries)
    if current_commit then
      M.highlight_commit_block(buffer_id, current_commit)
    end
    return true
  end
  return false
end

function M.navigate_to_previous_commit_with_highlight(buffer_id, window_id, boundaries)
  if M.navigate_to_previous_commit(buffer_id, window_id, boundaries) then
    -- Get the current commit after navigation and highlight it
    local current_commit = M.get_commit_at_cursor(buffer_id, window_id, boundaries)
    if current_commit then
      M.highlight_commit_block(buffer_id, current_commit)
    end
    return true
  end
  return false
end

-- Enhanced keymap setup that includes highlighting
function M.setup_commit_navigation_keymaps_with_highlight(buffer_id, boundaries)
  if not buffer_id or not boundaries then
    return false
  end
  
  -- Define j key mapping for next commit with highlighting
  vim.api.nvim_buf_set_keymap(buffer_id, 'n', 'j', '', {
    noremap = true,
    silent = true,
    callback = function()
      local window_id = vim.api.nvim_get_current_win()
      if not M.navigate_to_next_commit_with_highlight(buffer_id, window_id, boundaries) then
        -- If navigation failed, fall back to normal j movement
        vim.api.nvim_feedkeys('j', 'n', false)
      end
    end
  })
  
  -- Define k key mapping for previous commit with highlighting
  vim.api.nvim_buf_set_keymap(buffer_id, 'n', 'k', '', {
    noremap = true,
    silent = true,
    callback = function()
      local window_id = vim.api.nvim_get_current_win()
      if not M.navigate_to_previous_commit_with_highlight(buffer_id, window_id, boundaries) then
        -- If navigation failed, fall back to normal k movement
        vim.api.nvim_feedkeys('k', 'n', false)
      end
    end
  })
  
  return true
end

return M