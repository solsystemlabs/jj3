-- JJ window and buffer management functionality for jj.nvim
local M = {}

-- Import renderer for content display
local renderer = require("jj.log.renderer")
local navigation_integration = require("jj.ui.navigation_integration")
local config = require("jj.config")

-- Default configuration
local DEFAULT_CONFIG = {
	position = "right", -- left, right, top, bottom
	style = "split", -- split, floating
	width = 80, -- columns for vertical splits or floating windows
	height = 30, -- lines for horizontal splits or floating windows
	relative = "editor", -- editor, win, cursor (for floating windows)
	row = 5, -- row offset for floating windows
	col = 5, -- column offset for floating windows
	border = "single", -- border style for floating windows
	focusable = true, -- whether window is focusable
	zindex = 50, -- z-index for floating windows
	title = "jj3", -- window title
	title_pos = "center", -- title position
}

-- Current configuration
local current_config = vim.deepcopy(DEFAULT_CONFIG)

-- Window and buffer state
local log_buffer_id = nil
local log_window_id = nil
local help_section_enabled = false

-- Setup buffer with proper options including text wrapping (alias for create_log_buffer)
function M.setup_buffer()
	return M.create_log_buffer()
end

-- Create a new jj log buffer
function M.create_log_buffer()
	-- Create unlisted scratch buffer
	local buffer_id = vim.api.nvim_create_buf(false, true)

	if not buffer_id then
		return nil
	end

	-- Set buffer options
	local options = {
		buftype = "nofile",
		bufhidden = "hide",
		swapfile = false,
		modifiable = false,
		filetype = "jj",
		buflisted = false,
	}

	for option, value in pairs(options) do
		vim.api.nvim_buf_set_option(buffer_id, option, value)
	end

	-- Set buffer name
	vim.api.nvim_buf_set_name(buffer_id, "JJ Log")

	-- Store buffer ID
	log_buffer_id = buffer_id

	return buffer_id
end

-- Get existing log buffer or create new one
function M.get_or_create_log_buffer()
	if log_buffer_id and vim.api.nvim_buf_is_valid(log_buffer_id) then
		return log_buffer_id
	end

	return M.create_log_buffer()
end

-- Calculate floating window position relative to entire Neovim interface
local function calculate_floating_position(width, height)
	local total_width = vim.o.columns
	local total_height = vim.o.lines
	
	-- Use absolutely full height - no borders means we can use entire space
	local full_height = total_height
	
	-- Position at the right edge with some padding
	local col = total_width - width - 2  -- 2 columns padding from right edge
	local row = 0  -- Start from absolute top
	
	-- Handle edge cases where window would exceed bounds
	if col < 0 then col = 0 end
	if row < 0 then row = 0 end
	
	-- Use the calculated full height instead of user-provided height
	local actual_height = full_height
	if actual_height < 1 then actual_height = 1 end
	
	return {
		col = col,
		row = row,
		width = width,
		height = actual_height
	}
end

-- Calculate window configuration based on position and style
local function calculate_window_config(config)
	local win_config = {}

	if config.style == "floating" then
		-- Use global positioning for floating windows
		local position = calculate_floating_position(config.width, config.height)
		
		-- Floating window configuration with configurable borders and title
		win_config = {
			relative = "editor",  -- Always position relative to entire editor
			width = position.width,
			height = position.height,
			row = position.row,
			col = position.col,
			border = config.border or "none",
			style = "minimal",
			focusable = config.focusable,
			zindex = config.zindex,
		}
		
		-- Add title if configured
		if config.title then
			win_config.title = config.title
			win_config.title_pos = config.title_pos or "center"
		end
	else
		-- Split window - configuration handled by vim commands
		win_config = {
			split = config.position,
			width = config.width,
			height = config.height,
		}
	end

	return win_config
end

-- Create floating window with specified configuration
function M.create_float_window(buffer_id, config)
	local merged_config = vim.deepcopy(config or {})
	merged_config.style = "floating"
	local win_config = calculate_window_config(merged_config)
	return vim.api.nvim_open_win(buffer_id, config and config.focusable or true, win_config)
end

-- Create split window based on position
function M.create_split_window(buffer_id, config)
	local cmd

	if config.position == "left" then
		cmd = string.format("leftabove vertical %d split", config.width)
	elseif config.position == "right" then
		cmd = string.format("rightbelow vertical %d split", config.width)
	elseif config.position == "top" then
		cmd = string.format("leftabove %d split", config.height)
	elseif config.position == "bottom" then
		cmd = string.format("rightbelow %d split", config.height)
	else
		-- Default to right split
		cmd = string.format("rightbelow vertical %d split", config.width)
	end

	-- Execute split command
	vim.cmd(cmd)

	-- Get the current window (newly created split)
	local window_id = vim.api.nvim_get_current_win()

	-- Set buffer in the window
	vim.api.nvim_win_set_buf(window_id, buffer_id)

	return window_id
end

-- Create window with specified configuration (main entry point)
function M.create_window(config)
	return M.open_log_window(config)
end

-- Open log window with specified configuration
function M.open_log_window(user_config)
	-- Start with current window config
	local merged_config = vim.deepcopy(current_config)
	
	-- Get user configuration from config module
	local user_global_config = config.get()
	
	-- Apply global window configuration
	if user_global_config.window then
		-- Map window_type from config to style
		if user_global_config.window.window_type == "floating" then
			merged_config.style = "floating"
		elseif user_global_config.window.window_type == "split" then
			merged_config.style = "split"
			merged_config.position = user_global_config.window.position or "right"
		end
		
		-- Apply other window config options
		if user_global_config.window.size then
			merged_config.width = user_global_config.window.size
		end
		
		-- Apply border configuration
		if user_global_config.window.border then
			merged_config.border = user_global_config.window.border
		end
		
		-- Apply title configuration
		if user_global_config.window.title ~= nil then
			merged_config.title = user_global_config.window.title
		end
		
		if user_global_config.window.title_pos then
			merged_config.title_pos = user_global_config.window.title_pos
		end
	end
	
	-- Apply user-provided config (overrides global config)
	if user_config then
		for k, v in pairs(user_config) do
			merged_config[k] = v
		end
	end
	
	local final_config = merged_config

	-- Get or create buffer
	local buffer_id = M.get_or_create_log_buffer()
	if not buffer_id then
		return nil
	end

	local window_id

	if final_config.style == "floating" then
		-- Create floating window
		local win_config = calculate_window_config(final_config)
		window_id = vim.api.nvim_open_win(buffer_id, final_config.focusable, win_config)
	else
		-- Create split window
		window_id = M.create_split_window(buffer_id, final_config)
	end

	if not window_id then
		return nil
	end

	-- Set window options
	local window_options = {
		wrap = true, -- Enable text wrapping for long lines
		spell = false,
		number = false,
		relativenumber = false,
		signcolumn = "no",
		foldcolumn = "0",
		cursorline = true, -- Enable full-width cursor line highlighting
		filetype = "jj",
	}

	for option, value in pairs(window_options) do
		vim.api.nvim_win_set_option(window_id, option, value)
	end

	-- Configure cursor line highlighting specifically for jj buffers
	M.setup_cursor_line_highlighting(window_id, buffer_id)

	-- Store window ID
	log_window_id = window_id

	return window_id
end

-- Close window (alias for close_log_window)
function M.close_window()
	return M.close_log_window()
end

-- Close log window
function M.close_log_window()
	if log_window_id and vim.api.nvim_win_is_valid(log_window_id) then
		-- Clean up navigation for the buffer before closing window
		if log_buffer_id then
			navigation_integration.cleanup_navigation_for_buffer(log_buffer_id)
			-- Clean up cursor line highlighting
			M.cleanup_cursor_line_highlighting(log_buffer_id)
		end

		-- Reset refresh state when window is closed
		local ok, refresh = pcall(require, "jj.refresh")
		if ok then
			refresh.reset_refresh_state()
		end

		vim.api.nvim_win_close(log_window_id, true)
		log_window_id = nil
		return true
	end
	return false
end

-- Toggle window (alias for toggle_log_window)
function M.toggle_window()
	return M.toggle_log_window()
end

-- Toggle log window (open if closed, close if open)
function M.toggle_log_window()
	if M.is_log_window_open() then
		M.close_log_window()
		return false -- Window was closed
	else
		local window_id = M.open_log_window()
		return window_id ~= nil -- Window was opened successfully
	end
end

-- Focus log window
function M.focus_log_window()
	if log_window_id and vim.api.nvim_win_is_valid(log_window_id) then
		vim.api.nvim_set_current_win(log_window_id)
		return true
	end
	return false
end

-- Check if window is open (alias for is_log_window_open)
function M.is_window_open()
	return M.is_log_window_open()
end

-- Check if log window is currently open
function M.is_log_window_open()
	return log_window_id ~= nil and vim.api.nvim_win_is_valid(log_window_id)
end

-- Get current log window ID
function M.get_log_window_id()
	if M.is_log_window_open() then
		return log_window_id
	end
	return nil
end

-- Get current log buffer ID
function M.get_log_buffer_id()
	if log_buffer_id and vim.api.nvim_buf_is_valid(log_buffer_id) then
		return log_buffer_id
	end
	return nil
end

-- Configure window management settings
function M.configure(user_config)
	if not user_config then
		return
	end

	-- Validate and merge configuration
	local config = vim.deepcopy(current_config)

	-- Validate position
	if user_config.position then
		local valid_positions = { left = true, right = true, top = true, bottom = true }
		if valid_positions[user_config.position] then
			config.position = user_config.position
		end
	end

	-- Handle new technical spec format (type field)
	if user_config.type then
		if user_config.type == "float" then
			config.style = "floating"
		elseif user_config.type == "vsplit" then
			config.style = "split"
			config.position = "right" -- vertical split position
		elseif user_config.type == "hsplit" then
			config.style = "split"
			config.position = "bottom" -- horizontal split position
		end
	end

	-- Validate style (backwards compatibility)
	if user_config.style then
		local valid_styles = { split = true, floating = true }
		if valid_styles[user_config.style] then
			config.style = user_config.style
		end
	end

	-- Validate numeric values
	if user_config.width and type(user_config.width) == "number" and user_config.width > 0 then
		config.width = user_config.width
	end

	if user_config.height and type(user_config.height) == "number" and user_config.height > 0 then
		config.height = user_config.height
	end

	if user_config.row and type(user_config.row) == "number" and user_config.row >= 0 then
		config.row = user_config.row
	end

	if user_config.col and type(user_config.col) == "number" and user_config.col >= 0 then
		config.col = user_config.col
	end

	-- Validate other options
	if user_config.relative then
		local valid_relatives = { editor = true, win = true, cursor = true }
		if valid_relatives[user_config.relative] then
			config.relative = user_config.relative
		end
	end

	if user_config.border then
		config.border = user_config.border
	end

	if user_config.focusable ~= nil then
		config.focusable = user_config.focusable
	end

	if user_config.zindex and type(user_config.zindex) == "number" then
		config.zindex = user_config.zindex
	end

	-- Handle technical spec additional fields
	if user_config.title then
		config.title = user_config.title
	end

	if user_config.title_pos then
		config.title_pos = user_config.title_pos
	end

	current_config = config
end

-- Get current configuration
function M.get_configuration()
	return vim.deepcopy(current_config)
end

-- Render content to log window
function M.render_log_content(raw_colored_output, commits)
	local buffer_id = M.get_log_buffer_id()
	if not buffer_id then
		return false
	end

	-- Use renderer to display content
	local result = renderer.render_to_buffer(buffer_id, raw_colored_output)

	-- Setup navigation if commits are provided and rendering succeeded
	if result and commits and #commits > 0 then
		navigation_integration.setup_navigation_integration(buffer_id, commits, true)
	end

	-- Render help section if enabled
	if help_section_enabled then
		M.render_help_section(buffer_id, true)
	end

	return result ~= nil
end

-- Clear log content
function M.clear_log_content()
	local buffer_id = M.get_log_buffer_id()
	if not buffer_id then
		return false
	end

	-- Clean up navigation before clearing content
	navigation_integration.cleanup_navigation_for_buffer(buffer_id)

	-- Use renderer to clear content
	renderer.clear_buffer_content(buffer_id)
	return true
end

-- Get window dimensions for responsive layouts
function M.get_window_dimensions()
	local window_id = M.get_log_window_id()
	if not window_id then
		return nil
	end

	return {
		width = vim.api.nvim_win_get_width(window_id),
		height = vim.api.nvim_win_get_height(window_id),
	}
end

-- Resize window (for split windows)
function M.resize_window(width, height)
	local window_id = M.get_log_window_id()
	if not window_id then
		return false
	end

	if current_config.style == "floating" then
		-- Update floating window configuration
		local win_config = vim.api.nvim_win_get_config(window_id)
		if width then
			win_config.width = width
		end
		if height then
			win_config.height = height
		end
		vim.api.nvim_win_set_config(window_id, win_config)
	else
		-- Resize split window using vim commands
		if width and (current_config.position == "left" or current_config.position == "right") then
			vim.api.nvim_win_set_width(window_id, width)
		end
		if height and (current_config.position == "top" or current_config.position == "bottom") then
			vim.api.nvim_win_set_height(window_id, height)
		end
	end

	return true
end

-- Setup default keymaps for window (to be called from main plugin)
function M.setup_keymaps()
	-- These would typically be set up in the main plugin configuration
	-- Left as placeholder for integration
end

-- Cleanup function to close windows and clear state
function M.cleanup()
	-- Clean up navigation for any active buffers
	if log_buffer_id then
		navigation_integration.cleanup_navigation_for_buffer(log_buffer_id)
	end

	-- Reset refresh state on cleanup
	local ok, refresh = pcall(require, "jj.refresh")
	if ok then
		refresh.reset_refresh_state()
	end

	M.close_log_window()
	log_buffer_id = nil
	log_window_id = nil
end

-- Setup cursor line highlighting for jj log buffers
function M.setup_cursor_line_highlighting(window_id, buffer_id)
	if not window_id or not buffer_id then
		return false
	end

	-- Ensure CursorLine highlight group exists with appropriate styling
	local ok, _ = pcall(function()
		-- Get current CursorLine highlight or create default
		local cursorline_hl = vim.api.nvim_get_hl_by_name("CursorLine", true)
		
		-- If CursorLine doesn't have background, set a subtle one
		if not cursorline_hl.background then
			vim.api.nvim_set_hl(0, "CursorLine", {
				bg = "#2d3748", -- Subtle dark background
				ctermbg = 8     -- Fallback for terminal
			})
		end
	end)

	-- Set up autocmd to ensure cursor line highlighting persists
	local autocmd_group = vim.api.nvim_create_augroup("JJCursorLineHighlighting", { clear = false })
	
	vim.api.nvim_create_autocmd({"BufEnter", "WinEnter"}, {
		group = autocmd_group,
		buffer = buffer_id,
		callback = function()
			-- Re-enable cursorline when entering jj buffer
			if vim.api.nvim_win_is_valid(window_id) then
				vim.api.nvim_win_set_option(window_id, "cursorline", true)
			end
		end
	})

	return true
end

-- Apply full-width highlighting to specific lines
function M.highlight_lines_full_width(buffer_id, lines, highlight_group)
	if not buffer_id or not lines or #lines == 0 then
		return false
	end

	highlight_group = highlight_group or "Visual"
	local namespace = vim.api.nvim_create_namespace("jj_full_width_highlighting")

	-- Clear any existing highlights in this namespace
	vim.api.nvim_buf_clear_namespace(buffer_id, namespace, 0, -1)

	-- Apply full-width highlighting to each line
	for _, line_num in ipairs(lines) do
		-- Convert to 0-indexed if needed
		local zero_indexed_line = (line_num > 0) and (line_num - 1) or line_num
		
		vim.api.nvim_buf_add_highlight(
			buffer_id,
			namespace,
			highlight_group,
			zero_indexed_line,
			0,  -- Start at beginning of line
			-1  -- Extend to end of line (full width)
		)
	end

	return true
end

-- Clear full-width highlighting from buffer
function M.clear_full_width_highlighting(buffer_id)
	if not buffer_id then
		return false
	end

	local namespace = vim.api.nvim_create_namespace("jj_full_width_highlighting")
	vim.api.nvim_buf_clear_namespace(buffer_id, namespace, 0, -1)
	return true
end

-- Cleanup cursor line highlighting configuration
function M.cleanup_cursor_line_highlighting(buffer_id)
	if not buffer_id then
		return false
	end

	-- Clear the autocmd group for cursor line highlighting
	local ok, _ = pcall(function()
		vim.api.nvim_clear_autocmds({
			group = "JJCursorLineHighlighting",
			buffer = buffer_id
		})
	end)

	-- Clear any full-width highlighting
	M.clear_full_width_highlighting(buffer_id)

	return true
end

-- Get merged keybind data from the keybinding system
function M.get_merged_keybinds()
	local buffer_id = M.get_log_buffer_id()
	
	if not buffer_id then
		return {}
	end
	
	-- Get merged keybinds from command definitions (since registry is internal)
	local default_commands = require("jj.default_commands")
	local command_context = require("jj.command_context")
	local all_commands = default_commands.get_all_default_commands()
	local merged_keybinds = {}
	
	for command_name, command_def in pairs(all_commands) do
		-- Get the command definition through command_context to get merged version
		local merged_def = command_context.get_command_definition(command_name)
		
		if merged_def and merged_def.quick_action and merged_def.quick_action.keymap then
			merged_keybinds[merged_def.quick_action.keymap] = {
				command = command_name,
				action_type = "quick_action",
				description = merged_def.quick_action.description,
			}
		end
		if merged_def and merged_def.menu and merged_def.menu.keymap then
			merged_keybinds[merged_def.menu.keymap] = {
				command = command_name,
				action_type = "menu", 
				description = merged_def.menu.title or (command_name .. " Options"),
			}
		end
	end
	
	return merged_keybinds
end

-- Format keybind data into display lines
function M.format_keybind_lines(keybind_data)
	if not keybind_data or vim.tbl_isempty(keybind_data) then
		return { "No keybindings available" }
	end
	
	local lines = {}
	local sorted_keys = {}
	
	-- Sort keys for consistent display
	for key, _ in pairs(keybind_data) do
		table.insert(sorted_keys, key)
	end
	table.sort(sorted_keys)
	
	-- Format each keybinding
	for _, key in ipairs(sorted_keys) do
		local binding = keybind_data[key]
		local description = binding.description or "No description"
		local line = string.format("%s: %s", key, description)
		table.insert(lines, line)
	end
	
	return lines
end

-- Build complete help section content with separator
function M.build_help_section_content(keybind_lines)
	local content = {}
	
	-- Add separator line
	table.insert(content, string.rep("─", 50))
	table.insert(content, "Available Keybindings:")
	table.insert(content, "")
	
	-- Add keybind lines
	for _, line in ipairs(keybind_lines) do
		table.insert(content, line)
	end
	
	return content
end

-- Render help section to buffer
function M.render_help_section(buffer_id, enabled)
	if not buffer_id then
		return false
	end
	
	-- Store the enabled state
	help_section_enabled = enabled
	
	if not enabled then
		-- Clear help section by rendering without it
		return true
	end
	
	-- Get merged keybind data and format it
	local keybind_data = M.get_merged_keybinds()
	local keybind_lines = M.format_keybind_lines(keybind_data)
	local help_content = M.build_help_section_content(keybind_lines)
	
	-- Get current buffer content
	local current_lines = vim.api.nvim_buf_get_lines(buffer_id, 0, -1, false)
	
	-- Find existing help section and remove it
	local log_content = {}
	local in_help_section = false
	
	for _, line in ipairs(current_lines) do
		if string.match(line, "^─+$") and not in_help_section then
			-- Start of help section - stop adding to log content
			in_help_section = true
		elseif not in_help_section then
			table.insert(log_content, line)
		end
	end
	
	-- Combine log content with new help section
	local all_content = {}
	for _, line in ipairs(log_content) do
		table.insert(all_content, line)
	end
	for _, line in ipairs(help_content) do
		table.insert(all_content, line)
	end
	
	-- Set buffer content
	vim.api.nvim_buf_set_option(buffer_id, "modifiable", true)
	vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, all_content)
	vim.api.nvim_buf_set_option(buffer_id, "modifiable", false)
	
	return true
end

-- Toggle help section visibility
function M.toggle_help_section()
	local buffer_id = M.get_log_buffer_id()
	if not buffer_id then
		return false
	end
	
	help_section_enabled = not help_section_enabled
	return M.render_help_section(buffer_id, help_section_enabled)
end

-- Get help section enabled state
function M.is_help_section_enabled()
	return help_section_enabled
end

return M
