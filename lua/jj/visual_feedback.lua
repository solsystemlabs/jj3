-- Visual feedback system for commit selection workflows
local M = {}

-- State management
local selection_window = nil
local highlight_namespace = nil
local buffer_highlights = {}

-- Initialize highlight namespace
local function ensure_highlight_namespace()
  if not highlight_namespace then
    highlight_namespace = vim.api.nvim_create_namespace("jj3_selection_highlights")
  end
  return highlight_namespace
end

-- Define highlight groups for selection states
function M.setup_highlight_groups()
  local highlight_groups = M.get_highlight_group_definitions()
  
  for group_name, definition in pairs(highlight_groups) do
    vim.api.nvim_set_hl(0, group_name, definition)
  end
end

function M.get_highlight_group_definitions()
  return {
    JJ3SelectedSource = { 
      bg = "#2d4f67", 
      fg = "#a8dadc",
      bold = true
    },
    JJ3SelectedTarget = { 
      bg = "#6b2c42", 
      fg = "#f1c0c0",
      bold = true
    },
    JJ3SelectedMultiple = { 
      bg = "#4a5d23", 
      fg = "#c9db74",
      bold = true  
    },
    JJ3CurrentSelection = { 
      bg = "#5d4037", 
      fg = "#ffcc80",
      bold = true,
      underline = true
    }
  }
end

-- Show selection floating window
function M.show_selection_window(parent_winnr, context)
  M.hide_selection_window() -- Close any existing window
  
  -- Create buffer for floating window
  local bufnr = vim.api.nvim_create_buf(false, true)
  
  -- Generate window content
  local content = M.generate_window_content(context)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
  
  -- Calculate window dimensions
  local max_width = 0
  for _, line in ipairs(content) do
    max_width = math.max(max_width, #line)
  end
  local width = max_width + 2
  local height = #content + 2
  
  -- Get parent window position and size
  local parent_config = vim.api.nvim_win_get_config(parent_winnr)
  local parent_row = parent_config.row or 0
  local parent_col = parent_config.col or 0
  
  -- Create floating window pinned to top-left of parent
  local win_config = {
    relative = "win",
    win = parent_winnr,
    row = 1,
    col = 1,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " " .. (context.command_def.description or "Selection") .. " ",
    title_pos = "left"
  }
  
  local winnr = vim.api.nvim_open_win(bufnr, false, win_config)
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "filetype", "jj3-selection")
  
  -- Store window info
  selection_window = {
    winnr = winnr,
    bufnr = bufnr,
    parent_winnr = parent_winnr,
    context = context,
    current_phase = context.current_phase
  }
end

-- Hide selection floating window
function M.hide_selection_window()
  if selection_window and selection_window.winnr then
    pcall(vim.api.nvim_win_close, selection_window.winnr, true)
    selection_window = nil
  end
end

-- Update selection context and refresh window
function M.update_selection_context(new_context)
  if not selection_window then
    return
  end
  
  selection_window.context = new_context
  selection_window.current_phase = new_context.current_phase
  
  -- Regenerate content
  local content = M.generate_window_content(new_context)
  vim.api.nvim_buf_set_lines(selection_window.bufnr, 0, -1, false, content)
  
  -- Resize window if needed
  local max_width = 0
  for _, line in ipairs(content) do
    max_width = math.max(max_width, #line)
  end
  local width = max_width + 2
  local height = #content + 2
  
  vim.api.nvim_win_set_config(selection_window.winnr, {
    width = width,
    height = height
  })
end

-- Generate content for the floating window
function M.generate_window_content(context)
  local content = {}
  local command_def = context.command_def
  local current_phase = context.current_phase
  local phase_index = context.phase_index or 1
  local selections = context.selections or {}
  
  -- Add main prompt
  local current_phase_info = command_def.phases and command_def.phases[phase_index]
  if current_phase_info then
    table.insert(content, current_phase_info.prompt)
    
    -- Add phase progress for multi-phase commands
    if #command_def.phases > 1 then
      table.insert(content, "Phase " .. phase_index .. " of " .. #command_def.phases)
    end
    
    table.insert(content, "")
  end
  
  -- Add selected commits section
  if vim.tbl_count(selections) > 0 then
    table.insert(content, "Selected commits:")
    
    for key, value in pairs(selections) do
      if type(value) == "table" then
        -- Multi-select
        for _, commit_id in ipairs(value) do
          table.insert(content, "• " .. commit_id .. " (" .. key .. ")")
        end
      else
        -- Single selection
        table.insert(content, "• " .. value .. " (" .. key .. ")")
      end
    end
    
    table.insert(content, "")
  end
  
  -- Add keybinding help
  local keybinds
  if current_phase_info and current_phase_info.multi_select then
    keybinds = "␣ add  ⏎ confirm  ⎋ cancel"
  else
    keybinds = "␣ select  ⏎ confirm  ⎋ cancel"
  end
  
  table.insert(content, keybinds)
  
  return content
end

-- Update selection highlights in the log buffer
function M.update_selection_highlights(bufnr, selections, current_phase)
  local ns_id = ensure_highlight_namespace()
  
  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  buffer_highlights[bufnr] = {}
  
  -- Get buffer content to find commit lines
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  
  -- Apply highlights for each selection
  for selection_key, selection_value in pairs(selections) do
    local commit_ids = {}
    
    if type(selection_value) == "table" then
      -- Multi-select
      commit_ids = selection_value
    else
      -- Single selection
      commit_ids = { selection_value }
    end
    
    for _, commit_id in ipairs(commit_ids) do
      local line_number = M._find_commit_line(lines, commit_id)
      if line_number then
        local hl_group = M._get_highlight_group_for_selection(selection_key, current_phase)
        
        -- Apply highlight to entire line
        vim.api.nvim_buf_add_highlight(bufnr, ns_id, hl_group, line_number, 0, -1)
        
        -- Store highlight info
        buffer_highlights[bufnr] = buffer_highlights[bufnr] or {}
        buffer_highlights[bufnr][commit_id] = {
          line_number = line_number,
          hl_group = hl_group
        }
      end
    end
  end
end

-- Clear all selection highlights from buffer
function M.clear_selection_highlights(bufnr)
  local ns_id = ensure_highlight_namespace()
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  buffer_highlights[bufnr] = {}
end

-- Find the line number containing a specific commit ID
function M._find_commit_line(lines, commit_id)
  for i, line in ipairs(lines) do
    -- Look for commit ID in the line (handle various jj log formats)
    if line:find(commit_id, 1, true) then
      return i - 1 -- Convert to 0-based indexing
    end
  end
  return nil
end

-- Get appropriate highlight group for selection type
function M._get_highlight_group_for_selection(selection_key, current_phase)
  if selection_key == "source" then
    return "JJ3SelectedSource"
  elseif selection_key == "target" or selection_key == current_phase then
    return "JJ3SelectedTarget"
  elseif selection_key == "targets" or selection_key:match("multiple") then
    return "JJ3SelectedMultiple"
  else
    return "JJ3SelectedSource" -- Default fallback
  end
end

-- Get current window info
function M.get_selection_window_info()
  return selection_window
end

-- Get current highlights for a buffer
function M.get_current_highlights(bufnr)
  return buffer_highlights[bufnr] or {}
end

-- Initialize the visual feedback system
function M.setup()
  M.setup_highlight_groups()
end

-- Testing helpers
function M._reset_for_testing()
  M.hide_selection_window()
  buffer_highlights = {}
  highlight_namespace = nil
end

return M