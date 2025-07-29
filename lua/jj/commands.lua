-- Command registration and handling for jj.nvim
local M = {}

-- Lazy load modules for better startup performance
local log = nil
local config = nil

-- Helper function to ensure modules are loaded
local function ensure_modules_loaded()
	if not log then
		log = require("jj.log.init")
		-- Set up log orchestration on first load
		if config then
			local user_config = config.get()
			log.setup(user_config.window)
		end
	end
	if not config then
		config = require("jj.config")
	end
end

-- Command handlers
local function handle_jj_command(opts)
	ensure_modules_loaded()
	local args = opts.args or ""

	if args == "" then
		-- Default behavior: toggle log window
		log.toggle_log()
	elseif args == "show" then
		-- Explicitly show log
		log.show_log()
	elseif args == "close" then
		-- Close log window
		log.close_log()
	elseif args == "refresh" then
		-- Refresh log content
		log.refresh_log()
	elseif args == "toggle" then
		-- Toggle log window
		log.toggle_log()
	elseif args == "focus" then
		-- Focus log window
		log.focus_log()
	elseif args == "clear" then
		-- Clear log content
		log.clear_log()
	elseif args == "status" then
		-- Show status information
		local status = log.get_status()
		local status_msg = string.format(
			"Log window: %s, Has data: %s, Window ID: %s, Buffer ID: %s",
			status.is_open and "open" or "closed",
			status.has_data and "yes" or "no",
			status.window_id or "none",
			status.buffer_id or "none"
		)
		vim.notify("jj.nvim status: " .. status_msg, vim.log.levels.INFO)
	elseif args:match("^%-%-") then
		-- Handle jj command options (e.g., :JJ --limit 10)
		log.show_log_with_options(args)
	else
		-- Show help for unknown commands
		local help_msg = [[
jj.nvim commands:
  :JJ              - Toggle log window
  :JJ show         - Show log window
  :JJ close        - Close log window  
  :JJ refresh      - Refresh log content
  :JJ toggle       - Toggle log window
  :JJ focus        - Focus log window
  :JJ clear        - Clear log content
  :JJ status       - Show status information
  :JJ --<options>  - Show log with custom jj options
    ]]
		vim.notify(help_msg, vim.log.levels.INFO)
	end
end

-- Keybinding handler for log toggle
local function handle_log_toggle()
	ensure_modules_loaded()
	log.toggle_log()
end

-- Setup window-specific keymaps for log buffer
local function setup_log_buffer_keymaps(buffer_id)
	ensure_modules_loaded()
	local opts = { buffer = buffer_id, silent = true, noremap = true }

	-- Close window
	vim.keymap.set("n", "q", function()
		log.close_log()
	end, opts)
	vim.keymap.set("n", "<Esc>", function()
		log.close_log()
	end, opts)

	-- Refresh log
	vim.keymap.set("n", "r", function()
		log.refresh_log()
	end, opts)
	vim.keymap.set("n", "R", function()
		log.refresh_log()
	end, opts)

	-- Focus window
	vim.keymap.set("n", "<CR>", function()
		log.focus_log()
	end, opts)

	-- Clear content (for testing/debugging)
	vim.keymap.set("n", "c", function()
		log.clear_log()
	end, opts)

	-- Toggle window
	vim.keymap.set("n", "t", function()
		log.toggle_log()
	end, opts)

	-- Setup command execution keybindings
	local keybindings = require("jj.keybindings")
	local result = keybindings.setup_jj_buffer_keybindings(buffer_id)

	if not result.success then
		vim.notify(
			"jj.nvim: Failed to setup command keybindings: " .. (result.error or "unknown error"),
			vim.log.levels.WARN
		)
	end
end

-- Auto-command to set up keymaps when log buffer is entered
local function setup_log_buffer_autocmd()
	vim.api.nvim_create_autocmd("BufEnter", {
		pattern = "JJ Log",
		callback = function()
			local buffer_id = vim.api.nvim_get_current_buf()
			setup_log_buffer_keymaps(buffer_id)
		end,
		desc = "Set up jj log buffer keymaps",
	})
end

-- Configure log display based on user settings
local function apply_user_configuration()
	ensure_modules_loaded()
	local user_config = config.get()

	if user_config.window then
		log.configure(user_config.window)
	end
end

-- Setup commands and keybindings
function M.setup()
	-- Ensure config is loaded for setup
	if not config then
		config = require("jj.config")
	end

	-- Apply user configuration
	apply_user_configuration()

	-- Register :JJ user command with completion
	vim.api.nvim_create_user_command("JJ", handle_jj_command, {
		desc = "jj.nvim: Display and manage jj log",
		nargs = "?",
		complete = function()
			return {
				"show",
				"close",
				"refresh",
				"toggle",
				"focus",
				"clear",
				"status",
				"--limit",
				"--revisions",
			}
		end,
	})

	-- Register global keybinding for log toggle
	local user_config = config.get()
	local keymap = user_config.keymaps.toggle_log

	if keymap then
		vim.keymap.set("n", keymap, handle_log_toggle, {
			desc = "Toggle jj log window",
			silent = true,
			noremap = true,
		})
	end

	-- Set up buffer-specific keymaps
	setup_log_buffer_autocmd()

	-- Set up log orchestration (defer until first use)
	-- log.setup(user_config.window) -- This will be called in ensure_modules_loaded
end

-- Cleanup function
function M.cleanup()
	log.cleanup()
end

-- Expose log functions for advanced usage
M.log = {
	show = function(config)
		return log.show_log(config)
	end,
	toggle = function(config)
		return log.toggle_log(config)
	end,
	close = function()
		return log.close_log()
	end,
	refresh = function()
		return log.refresh_log()
	end,
	focus = function()
		return log.focus_log()
	end,
	clear = function()
		return log.clear_log()
	end,
	is_open = function()
		return log.is_log_open()
	end,
	configure = function(config)
		return log.configure(config)
	end,
	get_status = function()
		return log.get_status()
	end,
	get_configuration = function()
		return log.get_configuration()
	end,
	show_with_options = function(options, config)
		return log.show_log_with_options(options, config)
	end,
}

-- Legacy compatibility functions (if needed)
function M.close_log_window()
	return log.close_log()
end

function M.refresh_log()
	return log.refresh_log()
end

-- Test function for debugging
function M.test_integration()
	local status = log.get_status()
	print("jj.nvim Integration Test:")
	print("  Log window open:", status.is_open)
	print("  Has log data:", status.has_data)
	print("  Window ID:", status.window_id)
	print("  Buffer ID:", status.buffer_id)
	print("  Configuration:", vim.inspect(status.configuration))

	if not status.is_open then
		print("  Opening log window...")
		local success = log.show_log()
		print("  Show log result:", success)
	end
end

return M
