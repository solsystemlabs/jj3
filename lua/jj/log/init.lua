-- JJ log orchestration module - integrates all components for complete log display
local M = {}

-- Import all required modules
local repository = require("jj.utils.repository")
local executor = require("jj.log.executor")
local parser = require("jj.log.parser")
local renderer = require("jj.log.renderer")
local window = require("jj.ui.window")
local ansi = require("jj.utils.ansi")

-- Module state
local current_log_data = nil
local is_initialized = false

-- Initialize ANSI color processing
local function ensure_initialized()
  if not is_initialized then
    ansi.setup()
    is_initialized = true
  end
end

-- Show comprehensive error message based on error type
local function show_error_message(error_type, details)
  local messages = {
    not_jj_repo = "Not in a jj repository. Please navigate to a directory with a .jj folder.",
    jj_not_found = "jj command not found. Please ensure jujutsu is installed and available in PATH.",
    jj_execution_failed = "Failed to execute jj command: " .. (details or "unknown error"),
    parsing_failed = "Failed to parse jj log output: " .. (details or "unknown error"),
    rendering_failed = "Failed to render log content: " .. (details or "unknown error"),
    window_creation_failed = "Failed to create log window: " .. (details or "unknown error"),
    unknown_error = "An unexpected error occurred: " .. (details or "please check your jj installation")
  }
  
  local message = messages[error_type] or messages.unknown_error
  vim.notify("jj.nvim: " .. message, vim.log.levels.ERROR)
end

-- Show informational message
local function show_info_message(message)
  vim.notify("jj.nvim: " .. message, vim.log.levels.INFO)
end

-- Get log data using dual-pass parsing
local function get_log_data()
  -- Execute jj log with dual-pass parsing
  local log_result = parser.parse_jj_log_dual_pass()
  
  if not log_result.success then
    return nil, log_result.error or "Failed to parse jj log"
  end
  
  if not log_result.graph_lines or #log_result.graph_lines == 0 then
    return nil, "No log data found"
  end
  
  return log_result, nil
end

-- Get raw colored log output for rendering
local function get_colored_log_output()
  local log_result = executor.execute_jj_command("log --color=always")
  
  if not log_result.success then
    if log_result.error and log_result.error:match("command not found") then
      return nil, "jj_not_found"
    else
      return nil, "jj_execution_failed", log_result.error
    end
  end
  
  return log_result.output, nil
end

-- Main function to show jj log
function M.show_log(config)
  ensure_initialized()
  
  -- Validate repository first
  local validation = repository.validate_repository()
  if not validation.valid then
    show_error_message("not_jj_repo", validation.error)
    return false
  end
  
  -- Show loading message
  show_info_message("Loading jj log...")
  
  -- Get colored log output for rendering
  local colored_output, error_type, error_details = get_colored_log_output()
  if not colored_output then
    show_error_message(error_type, error_details)
    return false
  end
  
  -- Get parsed commit data for navigation
  local log_data, parse_error = get_log_data()
  local commits = (log_data and log_data.commits) or {}
  if parse_error then
    show_info_message("Navigation disabled: " .. parse_error)
  end
  
  
  -- Configure window if config provided
  if config then
    window.configure(config)
  end
  
  -- Open log window
  local window_id = window.open_log_window()
  if not window_id then
    show_error_message("window_creation_failed", "Could not create log display window")
    return false
  end
  
  -- Render content to window
  local render_success = window.render_log_content(colored_output, commits)
  if not render_success then
    show_error_message("rendering_failed", "Could not render log content to buffer")
    window.close_log_window()
    return false
  end
  
  -- Store current log data for potential refresh
  current_log_data = colored_output
  
  -- Show success message
  show_info_message("jj log displayed successfully")
  
  return true
end

-- Toggle log window (show if closed, close if open)
function M.toggle_log(config)
  ensure_initialized()
  
  if window.is_log_window_open() then
    -- Close window
    local closed = window.close_log_window()
    if closed then
      show_info_message("jj log window closed")
    end
    return false
  else
    -- Show log
    return M.show_log(config)
  end
end

-- Refresh log content (reload from jj)
function M.refresh_log()
  ensure_initialized()
  
  -- Check if window is open
  if not window.is_log_window_open() then
    show_error_message("unknown_error", "No log window is currently open")
    return false
  end
  
  -- Validate repository
  local validation = repository.validate_repository()
  if not validation.valid then
    show_error_message("not_jj_repo", validation.error)
    return false
  end
  
  show_info_message("Refreshing jj log...")
  
  -- Get fresh colored log output
  local colored_output, error_type, error_details = get_colored_log_output()
  if not colored_output then
    show_error_message(error_type, error_details)
    return false
  end
  
  -- Get parsed commit data for navigation
  local log_data, parse_error = get_log_data()
  local commits = (log_data and log_data.commits) or {}
  if parse_error then
    show_info_message("Navigation disabled: " .. parse_error)
  end
  
  -- Render updated content
  local render_success = window.render_log_content(colored_output, commits)
  if not render_success then
    show_error_message("rendering_failed", "Could not refresh log content")
    return false
  end
  
  -- Update stored log data
  current_log_data = colored_output
  
  show_info_message("jj log refreshed successfully")
  return true
end

-- Close log window
function M.close_log()
  ensure_initialized()
  
  local closed = window.close_log_window()
  if closed then
    show_info_message("jj log window closed")
    return true
  end
  
  return false
end

-- Focus log window
function M.focus_log()
  ensure_initialized()
  
  if not window.is_log_window_open() then
    -- Open log if not already open
    return M.show_log()
  end
  
  local focused = window.focus_log_window()
  if focused then
    return true
  end
  
  show_error_message("unknown_error", "Could not focus log window")
  return false
end

-- Check if log window is currently open
function M.is_log_open()
  return window.is_log_window_open()
end

-- Configure window management
function M.configure(config)
  ensure_initialized()
  
  if not config then
    return
  end
  
  -- Validate configuration
  local valid_config = {}
  
  -- Position validation
  if config.position then
    local valid_positions = {left = true, right = true, top = true, bottom = true}
    if valid_positions[config.position] then
      valid_config.position = config.position
    end
  end
  
  -- Style validation
  if config.style then
    local valid_styles = {split = true, floating = true}
    if valid_styles[config.style] then
      valid_config.style = config.style
    end
  end
  
  -- Numeric validations
  if config.width and type(config.width) == "number" and config.width > 0 then
    valid_config.width = config.width
  end
  
  if config.height and type(config.height) == "number" and config.height > 0 then
    valid_config.height = config.height
  end
  
  -- Pass through other valid options
  local passthrough_options = {"relative", "row", "col", "border", "focusable", "zindex"}
  for _, option in ipairs(passthrough_options) do
    if config[option] ~= nil then
      valid_config[option] = config[option]
    end
  end
  
  -- Apply configuration to window module
  window.configure(valid_config)
end

-- Get current configuration
function M.get_configuration()
  return window.get_configuration()
end

-- Get window dimensions (for responsive layouts)
function M.get_window_dimensions()
  return window.get_window_dimensions()
end

-- Clear log content (useful for testing or manual clearing)
function M.clear_log()
  ensure_initialized()
  
  if not window.is_log_window_open() then
    return false
  end
  
  local success = window.clear_log_content()
  if success then
    show_info_message("jj log content cleared")
  end
  
  return success
end

-- Get status information about current log state
function M.get_status()
  return {
    is_open = window.is_log_window_open(),
    has_data = current_log_data ~= nil,
    window_id = window.get_log_window_id(),
    buffer_id = window.get_log_buffer_id(),
    configuration = window.get_configuration()
  }
end

-- Advanced function to show log with specific jj command options
function M.show_log_with_options(jj_options, window_config)
  ensure_initialized()
  
  -- Validate repository first
  local validation = repository.validate_repository()
  if not validation.valid then
    show_error_message("not_jj_repo", validation.error)
    return false
  end
  
  show_info_message("Loading jj log with custom options...")
  
  -- Build jj command with custom options
  local command = "log --color=always"
  if jj_options then
    command = command .. " " .. jj_options
  end
  
  -- Execute custom jj command
  local log_result = executor.execute_jj_command(command)
  if not log_result.success then
    if log_result.error and log_result.error:match("command not found") then
      show_error_message("jj_not_found")
    else
      show_error_message("jj_execution_failed", log_result.error)
    end
    return false
  end
  
  -- Configure window if config provided
  if window_config then
    window.configure(window_config)
  end
  
  -- Open log window
  local window_id = window.open_log_window()
  if not window_id then
    show_error_message("window_creation_failed")
    return false
  end
  
  -- Render content (no commit navigation for custom commands)
  local render_success = window.render_log_content(log_result.output, {})
  if not render_success then
    show_error_message("rendering_failed")
    window.close_log_window()
    return false
  end
  
  show_info_message("Custom jj log displayed successfully")
  return true
end

-- Cleanup function for proper resource management
function M.cleanup()
  window.cleanup()
  current_log_data = nil
  is_initialized = false
end

-- Setup function for initialization
function M.setup(config)
  ensure_initialized()
  
  if config then
    M.configure(config)
  end
  
  return true
end

return M