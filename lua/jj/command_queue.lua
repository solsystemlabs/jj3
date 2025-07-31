-- Command queue system to manage concurrent operations during refresh
local M = {}

-- Queue state
local queue_state = {
	commands = {}, -- Array of queued commands
	is_refresh_active = false,
	queue_history = {}, -- History of processed commands for debugging
	max_history_size = 50, -- Limit history size
}

-- Command structure: { command, callback, timestamp, id }
local next_command_id = 1

-- Queue a command for execution after refresh completes
function M.queue_command(command, callback)
	if not M.is_refresh_active() then
		return false -- Don't queue if refresh is not active
	end

	if type(command) ~= "string" or type(callback) ~= "function" then
		vim.notify("jj.nvim: Invalid command or callback for queuing", vim.log.levels.ERROR)
		return false
	end

	local queued_command = {
		command = command,
		callback = callback,
		timestamp = os.time(),
		id = next_command_id,
	}
	next_command_id = next_command_id + 1

	table.insert(queue_state.commands, queued_command)

	-- Provide user feedback
	vim.notify("jj.nvim: Command queued during refresh: " .. command, vim.log.levels.INFO)

	return true
end

-- Check if a command should be executed immediately or queued
function M.should_execute_command(command)
	return not M.is_refresh_active()
end

-- Process all queued commands in FIFO order
function M.process_queue()
	if M.is_empty() then
		return true
	end

	local queue_size = #queue_state.commands
	vim.notify("jj.nvim: Processing " .. queue_size .. " queued command(s)", vim.log.levels.INFO)

	local successful_count = 0
	local failed_count = 0

	-- Process commands in FIFO order
	for _, queued_command in ipairs(queue_state.commands) do
		local success, error_msg = pcall(function()
			vim.notify("jj.nvim: Executing queued command: " .. queued_command.command, vim.log.levels.INFO)
			queued_command.callback()
		end)

		-- Add to history
		local history_entry = {
			command = queued_command.command,
			timestamp = queued_command.timestamp,
			executed_at = os.time(),
			success = success,
			error = error_msg,
		}

		M._add_to_history(history_entry)

		if success then
			successful_count = successful_count + 1
		else
			failed_count = failed_count + 1
			vim.notify(
				"jj.nvim: Queued command failed: " .. queued_command.command .. " - " .. (error_msg or "unknown error"),
				vim.log.levels.ERROR
			)
		end
	end

	-- Clear the queue
	queue_state.commands = {}

	-- Provide summary feedback
	if failed_count > 0 then
		vim.notify(
			"jj.nvim: Queue processed: " .. successful_count .. " succeeded, " .. failed_count .. " failed",
			vim.log.levels.WARN
		)
	else
		vim.notify("jj.nvim: All " .. successful_count .. " queued commands executed successfully", vim.log.levels.INFO)
	end

	return failed_count == 0
end

-- Set refresh active state
function M.set_refresh_active(active)
	queue_state.is_refresh_active = active
end

-- Check if refresh is currently active
function M.is_refresh_active()
	return queue_state.is_refresh_active
end

-- Check if queue is empty
function M.is_empty()
	return #queue_state.commands == 0
end

-- Get current queue size
function M.get_queue_size()
	return #queue_state.commands
end

-- Get queue statistics for debugging
function M.get_queue_stats()
	local oldest_timestamp = nil
	if not M.is_empty() then
		oldest_timestamp = queue_state.commands[1].timestamp
	end

	return {
		queue_size = #queue_state.commands,
		is_refresh_active = queue_state.is_refresh_active,
		oldest_command_age = oldest_timestamp and (os.time() - oldest_timestamp) or nil,
		next_command_id = next_command_id,
	}
end

-- Get queue history for debugging
function M.get_queue_history()
	return queue_state.queue_history
end

-- Clear queue and reset state
function M.reset()
	queue_state.commands = {}
	queue_state.is_refresh_active = false
	queue_state.queue_history = {}
	next_command_id = 1
end

-- Add entry to history (internal function)
function M._add_to_history(entry)
	table.insert(queue_state.queue_history, entry)

	-- Limit history size
	if #queue_state.queue_history > queue_state.max_history_size then
		table.remove(queue_state.queue_history, 1)
	end
end

-- Integration functions for auto-refresh system
function M.on_refresh_start()
	M.set_refresh_active(true)
end

function M.on_refresh_complete()
	M.set_refresh_active(false)

	-- Process any queued commands
	if not M.is_empty() then
		M.process_queue()
	end
end

function M.on_refresh_error(error_msg)
	M.set_refresh_active(false)

	-- Still process queued commands even if refresh failed
	if not M.is_empty() then
		M.process_queue()
	end
end

-- Get pending commands info for user feedback
function M.get_pending_commands_info()
	if M.is_empty() then
		return "No commands queued"
	end

	local commands = {}
	for _, queued_command in ipairs(queue_state.commands) do
		table.insert(commands, queued_command.command)
	end

	return "Pending commands (" .. #commands .. "): " .. table.concat(commands, ", ")
end

-- Clear specific command from queue (useful for cancellation)
function M.cancel_command(command_id)
	for i, queued_command in ipairs(queue_state.commands) do
		if queued_command.id == command_id then
			table.remove(queue_state.commands, i)
			vim.notify("jj.nvim: Cancelled queued command: " .. queued_command.command, vim.log.levels.INFO)
			return true
		end
	end
	return false
end

-- Get all queued commands (for display purposes)
function M.get_queued_commands()
	local commands = {}
	for _, queued_command in ipairs(queue_state.commands) do
		table.insert(commands, {
			id = queued_command.id,
			command = queued_command.command,
			timestamp = queued_command.timestamp,
			age = os.time() - queued_command.timestamp,
		})
	end
	return commands
end

-- Set maximum queue size (for safety)
function M.set_max_queue_size(size)
	if type(size) == "number" and size > 0 then
		-- This could be implemented to prevent queue from growing too large
		-- For now, just store the preference
		queue_state.max_queue_size = size
		return true
	end
	return false
end

-- Check if queue is near capacity (if max size is set)
function M.is_queue_near_capacity()
	if queue_state.max_queue_size then
		return #queue_state.commands >= (queue_state.max_queue_size * 0.8)
	end
	return false
end

return M
