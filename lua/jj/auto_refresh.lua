-- Auto-refresh functionality for jj.nvim - triggers refresh after jj commands
local M = {}

-- State management
local auto_refresh_state = {
  command_hooks = {},
  next_hook_id = 1,
  is_enabled = true,
  last_refresh_time = 0,
  refresh_throttle_ms = 100 -- Minimum time between refreshes
}

-- Commands that should trigger auto-refresh when successful
local REFRESH_TRIGGERING_COMMANDS = {
  "^commit",     -- commit operations
  "^new",        -- new commit creation
  "^rebase",     -- rebase operations
  "^abandon",    -- abandon commits
  "^restore",    -- restore operations
  "^squash",     -- squash commits
  "^split",      -- split commits
  "^edit",       -- edit commits
  "^bookmark",   -- bookmark operations
  "^git",        -- git interop commands
  "^move",       -- move commits
  "^resolve",    -- conflict resolution
  "^undo",       -- undo operations
  "^operation"   -- operation commands
}

-- Commands that should NOT trigger auto-refresh (read-only operations)
local NON_REFRESH_COMMANDS = {
  "^log",        -- log viewing
  "^show",       -- show commit details
  "^status",     -- status checking
  "^diff",       -- diff viewing
  "^files",      -- file listing
  "^cat",        -- file content viewing
  "^config",     -- config operations (unless set)
  "^help",       -- help commands
  "^version"     -- version checking
}

-- Register a command hook for auto-refresh
function M.register_command_hook(callback)
  if type(callback) ~= "function" then
    error("Command hook callback must be a function")
  end
  
  local hook_id = auto_refresh_state.next_hook_id
  auto_refresh_state.next_hook_id = auto_refresh_state.next_hook_id + 1
  
  auto_refresh_state.command_hooks[hook_id] = {
    callback = callback,
    enabled = true
  }
  
  return hook_id
end

-- Disable a specific command hook
function M.disable_command_hook(hook_id)
  if auto_refresh_state.command_hooks[hook_id] then
    auto_refresh_state.command_hooks[hook_id].enabled = false
    return true
  end
  return false
end

-- Enable a specific command hook
function M.enable_command_hook(hook_id)
  if auto_refresh_state.command_hooks[hook_id] then
    auto_refresh_state.command_hooks[hook_id].enabled = true
    return true
  end
  return false
end

-- Remove a command hook entirely
function M.remove_command_hook(hook_id)
  if auto_refresh_state.command_hooks[hook_id] then
    auto_refresh_state.command_hooks[hook_id] = nil
    return true
  end
  return false
end

-- Check if a command should trigger auto-refresh
function M.should_trigger_refresh(command, success)
  if not success then
    return false -- Don't refresh on failed commands
  end
  
  if not command or type(command) ~= "string" then
    return false
  end
  
  -- Check if it's a non-refresh command
  for _, pattern in ipairs(NON_REFRESH_COMMANDS) do
    if command:match(pattern) then
      return false
    end
  end
  
  -- Check if it's a refresh-triggering command
  for _, pattern in ipairs(REFRESH_TRIGGERING_COMMANDS) do
    if command:match(pattern) then
      return true
    end
  end
  
  -- Default to not refreshing for unknown commands
  return false
end

-- Execute all registered command hooks
function M.execute_command_hooks(command, success, output)
  if not auto_refresh_state.is_enabled then
    return
  end
  
  for hook_id, hook in pairs(auto_refresh_state.command_hooks) do
    if hook.enabled then
      local ok, err = pcall(hook.callback, command, success, output)
      if not ok then
        vim.notify("jj.nvim: Command hook " .. hook_id .. " failed: " .. err, vim.log.levels.WARN)
      end
    end
  end
end

-- Auto-refresh function called after jj commands complete
function M.auto_refresh_after_command(command, success, output, window_mock)
  -- Check if we should trigger refresh for this command
  if not M.should_trigger_refresh(command, success) then
    return false
  end
  
  -- Throttle rapid consecutive refreshes (but allow for testing with mock time)
  local current_time = vim.loop and vim.loop.now() or os.time() * 1000 -- fallback for testing
  if current_time - auto_refresh_state.last_refresh_time < auto_refresh_state.refresh_throttle_ms then
    -- Allow override in testing by setting throttle to 0
    if auto_refresh_state.refresh_throttle_ms > 0 then
      return false
    end
  end
  
  -- For testing, use mock; for real usage, check window state dynamically
  if window_mock then
    if not window_mock.is_log_window_open() then
      return false -- No window open, nothing to refresh
    end
  else
    -- In real usage, load window module dynamically
    local ok, window = pcall(require, "jj.ui.window")
    if not ok or not window.is_log_window_open() then
      return false -- No window open, nothing to refresh
    end
  end
  
  -- Update last refresh time
  auto_refresh_state.last_refresh_time = current_time
  
  -- Check if refresh is already in progress
  local ok, command_queue = pcall(require, "jj.command_queue")
  if ok and command_queue.is_refresh_active() then
    -- Refresh is already in progress, don't trigger another one
    return false
  end
  
  -- Mark refresh as active
  if ok then
    command_queue.on_refresh_start()
  end
  
  -- Provide user feedback
  vim.notify("jj.nvim: Auto-refreshing after " .. command, vim.log.levels.INFO)
  
  -- Get current cursor position to preserve it
  local current_window = vim.api.nvim_get_current_win()
  local cursor_pos = vim.api.nvim_win_get_cursor(current_window)
  
  local success_refresh = false
  
  if window_mock then
    -- In test mode, use mock refresh
    if window_mock.refresh_log_content then
      success_refresh = window_mock.refresh_log_content({})
    else
      success_refresh = true
    end
    
    -- Refresh navigation state if available
    if window_mock.refresh_navigation then
      window_mock.refresh_navigation()
    end
  else
    -- In real usage, trigger the actual refresh
    local log_ok, log = pcall(require, "jj.log")
    if log_ok then
      success_refresh = log.refresh_log()
    end
  end
  
  -- Mark refresh as complete and process any queued commands
  if ok then
    if success_refresh then
      command_queue.on_refresh_complete()
    else
      command_queue.on_refresh_error("Log refresh failed")
    end
  end
  
  if success_refresh then
    -- Try to preserve cursor position
    local buffer_line_count = 10 -- Default for testing
    if window_mock and window_mock.get_buffer_line_count then
      buffer_line_count = window_mock.get_buffer_line_count()
    elseif not window_mock then
      -- Get actual buffer line count
      local window_ok, window = pcall(require, "jj.ui.window")
      if window_ok then
        local buffer_id = window.get_log_buffer_id()
        if buffer_id then
          buffer_line_count = vim.api.nvim_buf_line_count(buffer_id)
        end
      end
    end
    
    if cursor_pos and cursor_pos[1] <= buffer_line_count then
      -- Cursor position is still valid, restore it
      pcall(vim.api.nvim_win_set_cursor, current_window, cursor_pos)
    end
    
    vim.notify("jj.nvim: Auto-refresh completed", vim.log.levels.INFO)
    return true
  else
    vim.notify("jj.nvim: Auto-refresh failed", vim.log.levels.ERROR)
    return false
  end
end

-- Hook into jj command execution (to be called by command executor)
function M.on_command_complete(command, success, output)
  -- Execute all registered hooks first
  M.execute_command_hooks(command, success, output)
  
  -- Then trigger auto-refresh if needed
  M.auto_refresh_after_command(command, success, output)
end

-- Enable/disable auto-refresh system
function M.enable_auto_refresh()
  auto_refresh_state.is_enabled = true
end

function M.disable_auto_refresh()
  auto_refresh_state.is_enabled = false
end

function M.is_auto_refresh_enabled()
  return auto_refresh_state.is_enabled
end

-- Configure refresh throttling
function M.set_refresh_throttle(ms)
  if type(ms) == "number" and ms >= 0 then
    auto_refresh_state.refresh_throttle_ms = ms
    return true
  end
  return false
end

function M.get_refresh_throttle()
  return auto_refresh_state.refresh_throttle_ms
end

-- Add custom command patterns for refresh triggering
function M.add_refresh_command_pattern(pattern)
  if type(pattern) == "string" then
    table.insert(REFRESH_TRIGGERING_COMMANDS, pattern)
    return true
  end
  return false
end

function M.add_non_refresh_command_pattern(pattern)
  if type(pattern) == "string" then
    table.insert(NON_REFRESH_COMMANDS, pattern)
    return true
  end
  return false
end

-- Get current configuration for debugging
function M.get_auto_refresh_config()
  return {
    is_enabled = auto_refresh_state.is_enabled,
    hook_count = vim.tbl_count(auto_refresh_state.command_hooks),
    throttle_ms = auto_refresh_state.refresh_throttle_ms,
    last_refresh_time = auto_refresh_state.last_refresh_time,
    refresh_commands = REFRESH_TRIGGERING_COMMANDS,
    non_refresh_commands = NON_REFRESH_COMMANDS
  }
end

-- Get hook statistics
function M.get_hook_stats()
  local enabled_count = 0
  local disabled_count = 0
  
  for _, hook in pairs(auto_refresh_state.command_hooks) do
    if hook.enabled then
      enabled_count = enabled_count + 1
    else
      disabled_count = disabled_count + 1
    end
  end
  
  return {
    total_hooks = vim.tbl_count(auto_refresh_state.command_hooks),
    enabled_hooks = enabled_count,
    disabled_hooks = disabled_count
  }
end

-- Setup default auto-refresh behavior
function M.setup_default_auto_refresh()
  -- Register default auto-refresh hook
  M.register_command_hook(function(command, success, output)
    M.auto_refresh_after_command(command, success, output)
  end)
end

-- Reset auto-refresh state (useful for testing)
function M.reset_auto_refresh_state()
  auto_refresh_state.command_hooks = {}
  auto_refresh_state.next_hook_id = 1
  auto_refresh_state.is_enabled = true
  auto_refresh_state.last_refresh_time = 0
end

-- Cleanup function
function M.cleanup()
  auto_refresh_state.command_hooks = {}
  auto_refresh_state.next_hook_id = 1
  auto_refresh_state.last_refresh_time = 0
end

return M