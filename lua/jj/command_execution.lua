-- Core command execution framework for jj.nvim
local M = {}

-- Import dependencies
local executor = require("jj.log.executor")
local parser = require("jj.log.parser")

-- Internal command registry
local command_registry = {}

-- Register a command definition
function M.register_command(name, definition)
	if not M._validate_command_definition(definition) then
		return false
	end

	command_registry[name] = definition
	return true
end

-- Get a registered command
function M.get_command(name)
	return command_registry[name]
end

-- Merge user-defined commands with existing commands
function M.merge_user_commands(user_commands)
	for name, definition in pairs(user_commands) do
		if M._validate_command_definition(definition) then
			command_registry[name] = definition
		end
	end
end

-- Substitute parameters in command arguments (unified system)
function M.substitute_parameters(args, context)
	local substituted = {}
	context = context or {}

	for _, arg in ipairs(args) do
		if arg == "{commit_id}" then
			table.insert(substituted, context.commit_id or "@")
		elseif arg == "{change_id}" then
			table.insert(substituted, context.change_id or context.commit_id or "@")
		elseif arg == "{target}" then
			table.insert(substituted, context.target or context.commit_id or "@")
		elseif arg == "{multi_target}" then
			-- Handle multiple targets for multi-parent commits
			if context.multi_target and type(context.multi_target) == "table" then
				for _, target in ipairs(context.multi_target) do
					table.insert(substituted, target)
				end
			else
				-- Fallback to single target
				table.insert(substituted, context.target or context.commit_id or "@")
			end
		elseif arg == "{user_input}" then
			local input = vim.fn.input("Enter value: ")
			if input ~= "" then
				table.insert(substituted, input)
			end
			-- Skip empty input - don't add to substituted args
		else
			table.insert(substituted, arg)
		end
	end

	return substituted
end

-- Get command context from current cursor position
function M.get_command_context()
	local line = vim.api.nvim_get_current_line()
	local basic_info = parser.extract_basic_commit_info(line)

	local commit_id = basic_info and basic_info.commit_id or "@"
	local change_id = basic_info and basic_info.change_id or basic_info and basic_info.commit_id or "@"

	return {
		commit_id = commit_id,
		change_id = change_id,
		line_content = line,
	}
end

-- Execute a command with the given action type and context
function M.execute_command(name, action_type, context)
	-- Validate command exists
	local command_def = command_registry[name]
	if not command_def then
		return {
			success = false,
			error = "Command '" .. name .. "' not found in registry",
		}
	end

	local action = nil

	-- Handle special menu_option action type
	if action_type == "menu_option" then
		-- For menu options, we use the cmd and args from the context (passed from menu)
		if not context.cmd then
			return {
				success = false,
				error = "Menu option context missing cmd field",
			}
		end

		action = {
			cmd = context.cmd,
			args = context.args or {},
		}
	else
		-- Validate action type exists in command definition
		action = command_def[action_type]
		if not action then
			return {
				success = false,
				error = "Action type '" .. action_type .. "' not found for command '" .. name .. "'",
			}
		end
	end

	-- Substitute parameters in arguments
	local args = M.substitute_parameters(action.args or {}, context)

	-- Build command string
	local command_parts = { action.cmd }
	for _, arg in ipairs(args) do
		table.insert(command_parts, arg)
	end
	local full_command = table.concat(command_parts, " ")

	-- Execute through existing executor
	local result = executor.execute_jj_command(full_command)

	-- Add the executed command to the result for user feedback
	result.executed_command = "jj " .. full_command

	return result
end

-- Internal function to validate command definition structure
function M._validate_command_definition(definition)
	if type(definition) ~= "table" then
		return false
	end

	-- Must have at least quick_action
	if not definition.quick_action then
		return false
	end

	-- Validate quick_action structure
	local quick_action = definition.quick_action
	if type(quick_action) ~= "table" then
		return false
	end

	-- Must have cmd field
	if not quick_action.cmd or type(quick_action.cmd) ~= "string" then
		return false
	end

	-- args should be table if present
	if quick_action.args and type(quick_action.args) ~= "table" then
		return false
	end

	-- Validate menu structure if present
	if definition.menu then
		local menu = definition.menu
		if type(menu) ~= "table" then
			return false
		end

		-- Menu should have title and options
		if not menu.title or type(menu.title) ~= "string" then
			return false
		end

		if not menu.options or type(menu.options) ~= "table" then
			return false
		end

		-- Validate each menu option
		for _, option in ipairs(menu.options) do
			if type(option) ~= "table" or not option.key or not option.desc or not option.cmd then
				return false
			end
		end
	end

	return true
end

return M
