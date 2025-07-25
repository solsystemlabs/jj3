-- Command registration and handling for jj.nvim
local M = {}

-- Import required modules
local repository = require("jj.utils.repository")
local executor = require("jj.log.executor")
local parser = require("jj.log.parser")
local ansi = require("jj.utils.ansi")

-- State for log window
local log_window = {
	buffer = nil,
	window = nil,
	is_open = false
}

-- Create and display jj log in a new buffer
local function show_jj_log()
	-- Validate repository first
	local validation = repository.validate_repository()
	if not validation.valid then
		vim.notify("jj.nvim: " .. (validation.error or "Not in a jj repository"), vim.log.levels.ERROR)
		return
	end

	vim.notify("jj.nvim: Loading jj log...", vim.log.levels.INFO)

	-- Get colored log output
	local log_result = executor.execute_jj_command("log --color=always")
	if not log_result.success then
		vim.notify("jj.nvim: Failed to get log: " .. (log_result.error or "unknown error"), vim.log.levels.ERROR)
		return
	end

	-- Process the colored output
	local lines = {}
	for line in log_result.output:gmatch("[^\n]+") do
		table.insert(lines, line)
	end

	-- Set up ANSI color processing
	ansi.setup()
	local processed = ansi.process_colored_lines_for_buffer(lines)

	-- Create new buffer
	local buf = vim.api.nvim_create_buf(false, true)
	
	-- Set buffer options
	vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
	vim.api.nvim_buf_set_option(buf, 'swapfile', false)
	vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
	vim.api.nvim_buf_set_option(buf, 'filetype', 'jj')
	vim.api.nvim_buf_set_name(buf, 'jj://log')

	-- Set buffer content (clean lines without ANSI codes)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, processed.lines)
	
	-- Make buffer non-modifiable
	vim.api.nvim_buf_set_option(buf, 'modifiable', false)

	-- Apply highlights
	if #processed.highlights > 0 then
		local highlight_result = ansi.apply_highlights_to_buffer(buf, processed.highlights)
		if not highlight_result.success then
			vim.notify("jj.nvim: Warning - some highlights failed to apply", vim.log.levels.WARN)
		end
	end

	-- Create window to display the buffer
	local win_config = {
		relative = 'editor',
		width = math.floor(vim.o.columns * 0.8),
		height = math.floor(vim.o.lines * 0.8),
		col = math.floor(vim.o.columns * 0.1),
		row = math.floor(vim.o.lines * 0.1),
		style = 'minimal',
		border = 'rounded',
		title = ' JJ Log ',
		title_pos = 'center'
	}

	local win = vim.api.nvim_open_win(buf, true, win_config)
	
	-- Set window options
	vim.api.nvim_win_set_option(win, 'wrap', false)
	vim.api.nvim_win_set_option(win, 'cursorline', true)

	-- Store window and buffer info
	log_window.buffer = buf
	log_window.window = win
	log_window.is_open = true

	-- Set up keymaps for the log window
	local opts = { buffer = buf, silent = true }
	vim.keymap.set('n', 'q', function() M.close_log_window() end, opts)
	vim.keymap.set('n', '<Esc>', function() M.close_log_window() end, opts)
	vim.keymap.set('n', 'r', function() M.refresh_log() end, opts)

	vim.notify("jj.nvim: Log loaded (" .. #processed.lines .. " commits)", vim.log.levels.INFO)
end

-- Close the log window
function M.close_log_window()
	if log_window.is_open and log_window.window then
		vim.api.nvim_win_close(log_window.window, true)
		log_window.window = nil
		log_window.buffer = nil
		log_window.is_open = false
	end
end

-- Refresh the log window
function M.refresh_log()
	if log_window.is_open then
		M.close_log_window()
		show_jj_log()
	end
end

-- Toggle log window (main functionality)
local function toggle_log_window()
	if log_window.is_open then
		M.close_log_window()
	else
		show_jj_log()
	end
end

-- Test dual-pass parsing (for testing/debugging)
local function test_dual_pass_parsing()
	local validation = repository.validate_repository()
	if not validation.valid then
		vim.notify("jj.nvim: " .. (validation.error or "Not in a jj repository"), vim.log.levels.ERROR)
		return
	end

	vim.notify("jj.nvim: Testing dual-pass parsing...", vim.log.levels.INFO)

	local result = parser.parse_jj_log_dual_pass()
	if result.success then
		vim.notify(string.format("jj.nvim: Dual-pass parsing successful - %d commits, %d graph lines", 
			#result.commits, #result.graph_lines), vim.log.levels.INFO)
		
		-- Print first few commits for debugging
		for i = 1, math.min(3, #result.commits) do
			local commit = result.commits[i]
			print(string.format("Commit %d: %s (%s) - %s", 
				i, commit.commit_id:sub(1, 8), commit.author_name, commit.description))
		end
	else
		vim.notify("jj.nvim: Dual-pass parsing failed: " .. (result.error or "unknown error"), vim.log.levels.ERROR)
	end
end

-- Setup commands and keybindings
function M.setup()
	-- Register :JJ user command
	vim.api.nvim_create_user_command("JJ", function(opts)
		if opts.args == "test" then
			test_dual_pass_parsing()
		else
			toggle_log_window()
		end
	end, {
		desc = "Main jj.nvim command",
		nargs = '?',
	})

	-- Register global keybinding for log toggle
	local config = require("jj.config")
	local keymap = config.get().keymaps.toggle_log

	vim.keymap.set("n", keymap, toggle_log_window, {
		desc = "Toggle jj log window",
		silent = true,
	})
end

return M
