-- JJ command execution framework for jj.nvim
local M = {}

-- Import repository utilities
local repository = require("jj.utils.repository")

-- Template definitions
local MINIMAL_TEMPLATE = 'commit_id ++ "\\x00" ++ change_id ++ "\\n"'

local COMPREHENSIVE_TEMPLATE = 'commit_id ++ "\\x00" ++ change_id ++ "\\x00" ++ '
	.. 'author.name() ++ "\\x00" ++ author.email() ++ "\\x00" ++ '
	.. 'committer.timestamp() ++ "\\x00" ++ bookmarks ++ "\\x00" ++ '
	.. 'tags ++ "\\x00" ++ working_copies ++ "\\x00" ++ '
	.. 'if(conflict, "conflict", "normal") ++ "\\x00" ++ '
	.. 'if(empty, "empty", "normal") ++ "\\x00" ++ '
	.. 'if(hidden, "hidden", "normal") ++ "\\x00" ++ '
	.. 'description.first_line() ++ "\\x00" ++ '
	.. 'if(git_head, git_head, "") ++ "\\n"'

-- Execute a jj command synchronously
function M.execute_jj_command(command)
	-- Check if command should be queued due to active refresh
	local queue_ok, command_queue = pcall(require, "jj.command_queue")
	if queue_ok and not command_queue.should_execute_command(command) then
		-- Queue the command for later execution
		local queued = command_queue.queue_command(command, function()
			-- Execute the command when refresh completes
			M.execute_jj_command(command)
		end)

		if queued then
			return {
				success = false,
				error = "Command queued - refresh in progress",
				output = nil,
				queued = true,
			}
		end
	end

	-- Validate repository context first
	local validation = repository.validate_repository()
	if not validation.valid then
		return {
			success = false,
			error = "Repository validation failed: " .. (validation.error or "unknown error"),
			output = nil,
		}
	end

	-- Sanitize command to prevent injection
	if not M._is_safe_command(command) then
		return {
			success = false,
			error = "Command contains unsafe characters: " .. command,
			output = nil,
		}
	end

	-- Route through interactive detection system
	local cmd_parts = M._parse_command(command)
	local is_interactive = M._should_use_interactive_mode(cmd_parts.cmd, cmd_parts.args)
	
	if is_interactive then
		-- Execute in interactive terminal mode
		return M._execute_interactive_command(command, cmd_parts.cmd, cmd_parts.args)
	end

	-- Execute the command normally
	local full_command = "jj " .. command
	local output = vim.fn.system(full_command)
	local exit_code = vim.v.shell_error

	local result = nil
	if exit_code == 0 then
		result = {
			success = true,
			error = nil,
			output = output,
		}
	else
		result = {
			success = false,
			error = "Command failed with exit code " .. exit_code .. ": " .. output,
			output = nil,
		}
	end

	-- Note: Auto-refresh is handled by the command execution layer, not the executor
	-- This allows commands to control when and how refresh happens

	return result
end

-- Execute jj command with custom template
function M.execute_with_template(command, template)
	-- Use manual quoting instead of shellescape to avoid over-escaping
	local escaped_template = "'" .. template:gsub("'", "'\"'\"'") .. "'"
	local template_arg = "--template=" .. escaped_template
	local full_command = command .. " " .. template_arg
	return M.execute_jj_command(full_command)
end

-- Execute jj log with minimal template (for commit ID extraction)
function M.execute_minimal_log()
	return M.execute_with_template("log --no-graph", MINIMAL_TEMPLATE)
end

-- Execute jj log with comprehensive template (for full commit data)
function M.execute_comprehensive_log()
	return M.execute_with_template("log --no-graph", COMPREHENSIVE_TEMPLATE)
end

-- Execute command asynchronously with callback
function M.execute_async(command, callback)
	-- Check if command should be queued due to active refresh
	local queue_ok, command_queue = pcall(require, "jj.command_queue")
	if queue_ok and not command_queue.should_execute_command(command) then
		-- Queue the command for later execution
		local queued = command_queue.queue_command(command, function()
			-- Execute the command when refresh completes
			M.execute_async(command, callback)
		end)

		if queued then
			callback({
				success = false,
				error = "Command queued - refresh in progress",
				output = nil,
				queued = true,
			})
			return
		end
	end

	-- Validate repository context first
	local validation = repository.validate_repository()
	if not validation.valid then
		callback({
			success = false,
			error = "Repository validation failed: " .. (validation.error or "unknown error"),
			output = nil,
		})
		return
	end

	-- Sanitize command
	if not M._is_safe_command(command) then
		callback({
			success = false,
			error = "Command contains unsafe characters",
			output = nil,
		})
		return
	end

	-- Route through interactive detection system
	local cmd_parts = M._parse_command(command)
	local is_interactive = M._should_use_interactive_mode(cmd_parts.cmd, cmd_parts.args)
	
	if is_interactive then
		-- Execute in interactive terminal mode asynchronously
		M._execute_interactive_command_async(command, cmd_parts.cmd, cmd_parts.args, callback)
		return
	end

	-- Use vim.fn.jobstart for async execution
	local full_command = "jj " .. command
	local output_lines = {}

	local job_id = vim.fn.jobstart(full_command, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if data then
				vim.list_extend(output_lines, data)
			end
		end,
		on_stderr = function(_, data)
			if data then
				vim.list_extend(output_lines, data)
			end
		end,
		on_exit = function(_, exit_code)
			local output = table.concat(output_lines, "\n")

			local result = nil
			if exit_code == 0 then
				result = {
					success = true,
					error = nil,
					output = output,
				}
			else
				result = {
					success = false,
					error = "Command failed with exit code " .. exit_code .. ": " .. output,
					output = nil,
				}
			end

			-- Trigger auto-refresh hooks after async command completion
			local ok, auto_refresh = pcall(require, "jj.auto_refresh")
			if ok then
				auto_refresh.on_command_complete(command, result.success, result.output or result.error)
			end

			callback(result)
		end,
	})

	if job_id <= 0 then
		callback({
			success = false,
			error = "Failed to start job",
			output = nil,
		})
	end
end

-- Execute command with timeout
function M.execute_with_timeout(command, timeout_ms)
	timeout_ms = timeout_ms or 5000 -- Default 5 second timeout

	local result = nil
	local completed = false

	-- Start async execution
	M.execute_async(command, function(res)
		result = res
		completed = true
	end)

	-- Wait for completion or timeout
	local start_time = vim.loop.now()
	while not completed do
		vim.wait(10)
		if vim.loop.now() - start_time > timeout_ms then
			return {
				success = false,
				error = "Command timed out after " .. timeout_ms .. "ms",
				output = nil,
			}
		end
	end

	return result
end

-- Get predefined minimal template
function M.get_minimal_template()
	return MINIMAL_TEMPLATE
end

-- Get predefined comprehensive template
function M.get_comprehensive_template()
	return COMPREHENSIVE_TEMPLATE
end

-- Validate template syntax (basic validation)
function M.validate_template(template)
	if type(template) ~= "string" then
		return false
	end

	-- Check for balanced quotes and basic syntax
	local quote_count = 0
	for _ in template:gmatch('"') do
		quote_count = quote_count + 1
	end

	-- Must have even number of quotes
	if quote_count % 2 ~= 0 then
		return false
	end

	-- Check for dangerous patterns
	if template:find("[;&|`$]") then
		return false
	end

	return true
end

-- Internal function to check if command is safe
function M._is_safe_command(command)
	if type(command) ~= "string" then
		return false
	end

	-- Check for command injection patterns (but allow common jj patterns)
	local dangerous_patterns = {
		";",
		"|",
		"&",
		"`",
		"rm ",
		"del ",
		"format ",
		"shutdown",
	}

	for _, pattern in ipairs(dangerous_patterns) do
		if command:find(pattern) then
			return false
		end
	end

	return true
end

-- Parse command string into cmd and args
function M._parse_command(command)
	if not command or type(command) ~= "string" then
		return { cmd = "", args = {} }
	end
	
	-- Simple space-based parsing (could be enhanced for complex quoting)
	local parts = vim.split(command, "%s+")
	local cmd = parts[1] or ""
	local args = {}
	
	for i = 2, #parts do
		table.insert(args, parts[i])
	end
	
	return { cmd = cmd, args = args }
end

-- Check if command should use interactive mode
function M._should_use_interactive_mode(cmd, args)
	-- Try to load interactive detection module
	local ok, interactive_detection = pcall(require, "jj.interactive_detection")
	if not ok then
		-- Fallback: no interactive detection available
		return false
	end
	
	return interactive_detection.is_interactive_command(cmd, args)
end

-- Execute command in interactive terminal mode (placeholder for now)
function M._execute_interactive_command(command, cmd, args)
	-- TODO: This will be implemented in Task 2 (Floating Terminal Window Management)
	-- For now, fall back to normal execution to maintain compatibility
	
	-- Log that we detected an interactive command but are falling back
	if vim.notify then
		vim.notify("Interactive command detected: " .. cmd .. " (falling back to normal execution)", vim.log.levels.INFO)
	end
	
	-- Execute normally for now
	local full_command = "jj " .. command
	local output = vim.fn.system(full_command)
	local exit_code = vim.v.shell_error
	
	local result = nil
	if exit_code == 0 then
		result = {
			success = true,
			error = nil,
			output = output,
			interactive_fallback = true,
		}
	else
		result = {
			success = false,
			error = "Command failed with exit code " .. exit_code .. ": " .. output,
			output = nil,
			interactive_fallback = true,
		}
	end
	
	return result
end

-- Execute command in interactive terminal mode asynchronously (placeholder for now)
function M._execute_interactive_command_async(command, cmd, args, callback)
	-- TODO: This will be implemented in Task 2 (Floating Terminal Window Management)
	-- For now, fall back to normal async execution to maintain compatibility
	
	-- Log that we detected an interactive command but are falling back
	if vim.notify then
		vim.notify("Interactive command detected: " .. cmd .. " (falling back to async execution)", vim.log.levels.INFO)
	end
	
	-- Execute normally using existing async path
	local full_command = "jj " .. command
	local output_lines = {}

	local job_id = vim.fn.jobstart(full_command, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if data then
				vim.list_extend(output_lines, data)
			end
		end,
		on_stderr = function(_, data)
			if data then
				vim.list_extend(output_lines, data)
			end
		end,
		on_exit = function(_, exit_code)
			local output = table.concat(output_lines, "\n")

			local result = nil
			if exit_code == 0 then
				result = {
					success = true,
					error = nil,
					output = output,
					interactive_fallback = true,
				}
			else
				result = {
					success = false,
					error = "Command failed with exit code " .. exit_code .. ": " .. output,
					output = nil,
					interactive_fallback = true,
				}
			end

			-- Trigger auto-refresh hooks after async command completion
			local ok, auto_refresh = pcall(require, "jj.auto_refresh")
			if ok then
				auto_refresh.on_command_complete(command, result.success, result.output or result.error)
			end

			callback(result)
		end,
	})

	if job_id <= 0 then
		callback({
			success = false,
			error = "Failed to start job",
			output = nil,
			interactive_fallback = true,
		})
	end
end

return M
