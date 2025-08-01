-- Terminal window management for interactive jj commands
local M = {}

-- Active terminal windows tracking
local active_terminals = {}

-- Default window configuration
local DEFAULT_CONFIG = {
  width_ratio = 0.8,
  height_ratio = 0.8,
  min_width = 40,
  min_height = 10,
  border = "rounded",
  title_pos = "center",
  focus = true,
}

-- Create a floating terminal window for interactive commands
function M.create_terminal_window(command, config, on_exit_callback)
  -- Validate input
  if not command or type(command) ~= "string" or command == "" then
    return {
      error = "Invalid command: command must be a non-empty string"
    }
  end
  
  -- Merge config with defaults
  config = config or {}
  local window_config = vim.tbl_deep_extend("force", DEFAULT_CONFIG, config)
  
  -- Get window dimensions
  local dimensions = M.get_window_dimensions(window_config)
  local position = M.calculate_center_position(dimensions.width, dimensions.height)
  
  -- Create buffer for terminal
  local buffer_id = vim.api.nvim_create_buf(false, true)
  if buffer_id <= 0 then
    return {
      error = "Failed to create buffer for terminal"
    }
  end
  
  -- Configure buffer for terminal use
  vim.bo[buffer_id].buflisted = false
  
  -- Configure floating window
  local win_config = {
    relative = "editor",
    width = dimensions.width,
    height = dimensions.height,
    row = position.row,
    col = position.col,
    style = "minimal",
    border = window_config.border,
    title = M.get_window_title(command),
    title_pos = window_config.title_pos,
  }
  
  -- Create floating window
  local window_id = vim.api.nvim_open_win(buffer_id, window_config.focus, win_config)
  if window_id <= 0 then
    return {
      error = "Failed to create window for terminal"
    }
  end
  
  -- Start terminal job
  local job_result = M.start_terminal_job(buffer_id, window_id, command, on_exit_callback)
  if job_result.error then
    -- Clean up window and buffer on job creation failure
    pcall(vim.api.nvim_win_close, window_id, true)
    return job_result
  end
  
  -- Set up terminal keybindings for easier exit
  vim.api.nvim_buf_set_keymap(buffer_id, "t", "<C-c>", "<C-\\><C-n>:q<CR>", {
    silent = true,
    noremap = true,
    desc = "Close terminal window"
  })
  
  -- Enter terminal mode if window has focus
  if window_config.focus then
    vim.cmd("startinsert")
  end
  
  -- Track active terminal
  local terminal_info = {
    buffer_id = buffer_id,
    window_id = window_id,
    job_id = job_result.job_id,
    command = command,
    created_at = os.time(),
  }
  
  active_terminals[window_id] = terminal_info
  
  return {
    buffer_id = buffer_id,
    window_id = window_id,
    job_id = job_result.job_id,
  }
end

-- Calculate window dimensions based on screen size and config
function M.get_window_dimensions(config)
  config = config or DEFAULT_CONFIG
  
  -- Use explicit dimensions if provided
  if config.width and config.height then
    return {
      width = math.max(config.width, config.min_width or DEFAULT_CONFIG.min_width),
      height = math.max(config.height, config.min_height or DEFAULT_CONFIG.min_height),
    }
  end
  
  -- Calculate based on screen size ratios
  local screen_width = vim.o.columns
  local screen_height = vim.o.lines
  
  local width = math.floor(screen_width * (config.width_ratio or DEFAULT_CONFIG.width_ratio))
  local height = math.floor(screen_height * (config.height_ratio or DEFAULT_CONFIG.height_ratio))
  
  -- Apply minimums
  width = math.max(width, config.min_width or DEFAULT_CONFIG.min_width)
  height = math.max(height, config.min_height or DEFAULT_CONFIG.min_height)
  
  -- Ensure we don't exceed screen size
  width = math.min(width, screen_width - 4) -- Leave some margin
  height = math.min(height, screen_height - 4)
  
  return { width = width, height = height }
end

-- Calculate centered position for window
function M.calculate_center_position(width, height)
  local screen_width = vim.o.columns
  local screen_height = vim.o.lines
  
  local col = math.max(0, math.floor((screen_width - width) / 2))
  local row = math.max(0, math.floor((screen_height - height) / 2))
  
  return { row = row, col = col }
end

-- Generate window title from command
function M.get_window_title(command)
  if not command or command == "" then
    return " jj "
  end
  
  -- Extract command name (first word)
  local cmd_name = command:match("^(%S+)")
  return " jj " .. (cmd_name or "command") .. " "
end

-- Start terminal job in the given buffer
function M.start_terminal_job(buffer_id, window_id, command, on_exit_callback)
  -- Prepare full command  
  local full_command = "jj " .. command
  
  -- Set up job options
  local job_opts = {
    pty = true,
    on_exit = function(job_id, exit_code, event)
      -- Capture terminal output for completion message
      local output_lines = vim.api.nvim_buf_get_lines(buffer_id, 0, -1, false)
      local output = table.concat(output_lines, "\n"):gsub("^%s*", ""):gsub("%s*$", "")
      
      -- Clean up terminal tracking
      if active_terminals[window_id] then
        active_terminals[window_id] = nil
      end
      
      -- Terminal completion will be handled by the normal command flow
      -- via the on_exit_callback
      
      -- Close the window after a brief delay
      vim.defer_fn(function()
        pcall(vim.api.nvim_win_close, window_id, true)
      end, 100)
      
      -- Call user callback if provided
      if on_exit_callback and type(on_exit_callback) == "function" then
        on_exit_callback(exit_code)
      end
    end,
  }
  
  -- Start the job
  local job_id = vim.fn.termopen(full_command, job_opts)
  
  if job_id <= 0 then
    return {
      error = "Failed to start terminal job for command: " .. command
    }
  end
  
  return {
    job_id = job_id
  }
end

-- Clean up all active terminals
function M.cleanup_all_terminals()
  for window_id, terminal_info in pairs(active_terminals) do
    -- Close window
    pcall(vim.api.nvim_win_close, window_id, true)
    
    -- Stop job if still running
    if terminal_info.job_id and terminal_info.job_id > 0 then
      pcall(vim.fn.jobstop, terminal_info.job_id)
    end
  end
  
  -- Clear tracking
  active_terminals = {}
end

-- Get information about active terminals
function M.get_active_terminals()
  return vim.deepcopy(active_terminals)
end

-- Check if a specific window is a terminal window
function M.is_terminal_window(window_id)
  return active_terminals[window_id] ~= nil
end

-- Get terminal info for a specific window
function M.get_terminal_info(window_id)
  local info = active_terminals[window_id]
  return info and vim.deepcopy(info) or nil
end

-- Close specific terminal window
function M.close_terminal(window_id)
  local terminal_info = active_terminals[window_id]
  if not terminal_info then
    return false
  end
  
  -- Close window
  pcall(vim.api.nvim_win_close, window_id, true)
  
  -- Stop job
  if terminal_info.job_id and terminal_info.job_id > 0 then
    pcall(vim.fn.jobstop, terminal_info.job_id)
  end
  
  -- Remove from tracking
  active_terminals[window_id] = nil
  
  return true
end

return M