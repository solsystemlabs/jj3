-- JJ window and buffer management functionality for jj.nvim
local M = {}

-- Import renderer for content display
local renderer = require("jj.log.renderer")
local navigation_integration = require("jj.ui.navigation_integration")

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

-- Calculate window configuration based on position and style
local function calculate_window_config(config)
	local win_config = {}

	if config.style == "floating" then
		-- Floating window configuration
		win_config = {
			relative = config.relative,
			width = config.width,
			height = config.height,
			row = config.row,
			col = config.col,
			border = config.border,
			style = "minimal",
			focusable = config.focusable,
			zindex = config.zindex,
			title = config.title,
			title_pos = config.title_pos,
		}
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
function M.open_log_window(config)
	-- Merge user config with current config
	local merged_config = vim.deepcopy(current_config)
	if config then
		for k, v in pairs(config) do
			merged_config[k] = v
		end
	end
	config = merged_config

	-- Get or create buffer
	local buffer_id = M.get_or_create_log_buffer()
	if not buffer_id then
		return nil
	end

	local window_id

	if config.style == "floating" then
		-- Create floating window
		local win_config = calculate_window_config(config)
		window_id = vim.api.nvim_open_win(buffer_id, config.focusable, win_config)
	else
		-- Create split window
		window_id = M.create_split_window(buffer_id, config)
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

return M
