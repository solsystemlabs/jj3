-- Default command set for jj.nvim
local M = {}

-- Import dependencies
local executor = require("jj.log.executor")
local command_execution = require("jj.command_execution")

-- Default command definitions
local DEFAULT_COMMANDS = {
	new = {
		quick_action = {
			cmd = "new",
			args = {},
			keymap = "n",
			description = "Create new commit on current change",
		},
		menu = {
			keymap = "N",
			title = "New Commit Options",
			options = {
				{
					key = "1",
					desc = "New commit (default)",
					cmd = "new",
					args = {},
				},
				{
					key = "2",
					desc = "New commit with message",
					cmd = "new",
					args = { "-m", "{user_input}" },
				},
				{
					key = "3",
					desc = "New commit after current",
					cmd = "new",
					args = { "--insert-after", "{change_id}" },
				},
			},
		},
	},

	rebase = {
		quick_action = {
			cmd = "rebase",
			args = { "-d", "{change_id}" },
			keymap = "r",
			description = "Rebase current change onto selected commit",
		},
		menu = {
			keymap = "R",
			title = "Rebase Options",
			options = {
				{
					key = "1",
					desc = "Rebase current onto selected",
					cmd = "rebase",
					args = { "-d", "{change_id}" },
				},
				{
					key = "2",
					desc = "Rebase branch onto selected",
					cmd = "rebase",
					args = { "-b", "@", "-d", "{change_id}" },
				},
				{
					key = "3",
					desc = "Rebase with descendants",
					cmd = "rebase",
					args = { "-s", "@", "-d", "{change_id}" },
				},
			},
		},
	},

	abandon = {
		quick_action = {
			cmd = "abandon",
			args = { "{change_id}" },
			keymap = "a",
			description = "Abandon selected change",
			confirm = true,
		},
		menu = {
			keymap = "A",
			title = "Abandon Options",
			options = {
				{
					key = "1",
					desc = "Abandon change",
					cmd = "abandon",
					args = { "{change_id}" },
					confirm = true,
				},
				{
					key = "2",
					desc = "Abandon but retain bookmarks",
					cmd = "abandon",
					args = { "{change_id}", "--retain-bookmarks" },
					confirm = true,
				},
				{
					key = "3",
					desc = "Abandon but keep descendants unchanged",
					cmd = "abandon",
					args = { "{change_id}", "--restore-descendants" },
					confirm = true,
				},
			},
		},
	},

	edit = {
		quick_action = {
			cmd = "edit",
			args = { "{change_id}" },
			keymap = "e",
			description = "Edit selected change",
		},
		menu = {
			keymap = "E",
			title = "Edit Options",
			options = {
				{
					key = "1",
					desc = "Edit commit",
					cmd = "edit",
					args = { "{change_id}" },
				},
				{
					key = "2",
					desc = "Edit commit description",
					cmd = "describe",
					args = { "{change_id}", "-m", "{user_input}" },
				},
			},
		},
	},

	squash = {
		quick_action = {
			cmd = "squash",
			args = { "-r", "{change_id}" },
			keymap = "s",
			description = "Squash selected commit into its parent",
			confirm = true,
		},
		menu = {
			keymap = "S",
			title = "Squash Options",
			options = {
				{
					key = "1",
					desc = "Squash selected into its parent",
					cmd = "squash",
					args = { "-r", "{change_id}" },
					confirm = true,
				},
				{
					key = "2",
					desc = "Squash current working copy into selected",
					cmd = "squash",
					args = { "-t", "{change_id}" },
					confirm = true,
				},
				{
					key = "3",
					desc = "Squash selected into current working copy",
					cmd = "squash",
					args = { "-f", "{change_id}" },
					confirm = true,
				},
			},
		},
	},
}

-- Get command definition by name
function M.get_command_definition(name)
	return DEFAULT_COMMANDS[name]
end

-- Get all default command definitions
function M.get_all_default_commands()
	return DEFAULT_COMMANDS
end

-- Register all default commands in the command execution framework
function M.register_all_defaults()
	for name, definition in pairs(DEFAULT_COMMANDS) do
		command_execution.register_command(name, definition)
	end
end

-- Execute command with confirmation prompt for destructive operations
function M.execute_with_confirmation(command_name, context)
	local command_def = DEFAULT_COMMANDS[command_name]

	if not command_def then
		return {
			success = false,
			error = "Command '" .. command_name .. "' not found in defaults",
		}
	end

	-- Check if confirmation is required
	local requires_confirmation = command_def.quick_action and command_def.quick_action.confirm

	if requires_confirmation then
		local commit_info = context.commit_id or context.change_id or "current"
		local confirmation_msg = string.format(
			"Are you sure you want to %s %s?\n\nThis operation cannot be undone.",
			command_name,
			commit_info
		)

		local choice = vim.fn.confirm(confirmation_msg, "&Yes\n&No", 2)

		if choice ~= 1 then
			return {
				success = false,
				error = "Operation cancelled by user",
			}
		end
	end

	-- Build and execute command
	local args = command_def.quick_action.args or {}
	local substituted_args = {}

	for _, arg in ipairs(args) do
		if arg == "{commit_id}" then
			table.insert(substituted_args, context.commit_id or "@")
		elseif arg == "{change_id}" then
			table.insert(substituted_args, context.change_id or "@")
		elseif arg == "{user_input}" then
			local input = vim.fn.input("Enter value: ")
			if input ~= "" then
				table.insert(substituted_args, input)
			end
		else
			table.insert(substituted_args, arg)
		end
	end

	-- Build command string
	local command_parts = { command_def.quick_action.cmd }
	for _, arg in ipairs(substituted_args) do
		table.insert(command_parts, arg)
	end
	local full_command = table.concat(command_parts, " ")

	-- Execute through executor
	return executor.execute_jj_command(full_command)
end

-- Validate default command definitions
function M._validate_all_defaults()
	local errors = {}

	for name, definition in pairs(DEFAULT_COMMANDS) do
		-- Validate quick action
		if not definition.quick_action then
			table.insert(errors, name .. ": missing quick_action")
		else
			local qa = definition.quick_action
			if not qa.cmd or not qa.keymap or not qa.description then
				table.insert(errors, name .. ": quick_action missing required fields")
			end
		end

		-- Validate menu
		if not definition.menu then
			table.insert(errors, name .. ": missing menu")
		else
			local menu = definition.menu
			if not menu.keymap or not menu.title or not menu.options then
				table.insert(errors, name .. ": menu missing required fields")
			elseif #menu.options == 0 then
				table.insert(errors, name .. ": menu has no options")
			else
				-- Validate menu options
				for i, option in ipairs(menu.options) do
					if not option.key or not option.desc or not option.cmd then
						table.insert(errors, name .. ": menu option " .. i .. " missing required fields")
					end
				end
			end
		end
	end

	return #errors == 0, errors
end

return M
