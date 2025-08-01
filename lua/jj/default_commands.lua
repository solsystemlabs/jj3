-- Default command set for jj.nvim
local M = {}

-- Import dependencies
local executor = require("jj.log.executor")
local command_context = require("jj.command_context")

-- Default command definitions (enhanced with selection phases)
local DEFAULT_COMMANDS = {
	new = {
		quick_action = {
			cmd = "new",
			args = { "-m", "{user_input}", "{change_id}" },
			keymap = "n",
			description = "Create new commit based on commit under cursor, prompting for description",
		},
		menu = {
			keymap = "N",
			title = "New Commit Options",
			options = {
				{
					key = "1",
					desc = "New commit with multiple parents",
					cmd = "new",
					args = { "-m", "{user_input}", "{multi_target}" },
					phases = {
						{
							key = "multi_target",
							prompt = "Select multiple parent commits (Enter to confirm)",
							multi_select = true,
						},
					},
				},
				{
					key = "2",
					desc = "New commit before selected",
					cmd = "new",
					args = { "-m", "{user_input}", "--insert-before", "{target}" },
					phases = {
						{ key = "target", prompt = "Select target commit to create new commit before" },
					},
				},
				{
					key = "3",
					desc = "New commit after selected",
					cmd = "new",
					args = { "-m", "{user_input}", "--insert-after", "{target}" },
					phases = {
						{ key = "target", prompt = "Select target commit to create new commit after" },
					},
				},
				{
					key = "4",
					desc = "New commit without edit",
					cmd = "new",
					args = { "-m", "{user_input}", "--no-edit", "{target}" },
					phases = {
						{ key = "target", prompt = "Select target commit for new commit (no edit)" },
					},
				},
			},
		},
	},

	rebase = {
		quick_action = {
			cmd = "rebase",
			args = { "-d", "{target}" },
			keymap = "r",
			description = "Rebase current change onto selected commit",
			phases = {
				{ key = "target", prompt = "Select target commit to rebase onto" },
			},
		},
		menu = {
			keymap = "R",
			title = "Rebase Options",
			options = {
				{
					key = "1",
					desc = "Rebase current onto selected",
					cmd = "rebase",
					args = { "-r", "{change_id}", "-d", "{target}" },
					phases = {
						{ key = "target", prompt = "Select target commit to rebase onto" },
					},
				},
				{
					key = "2",
					desc = "Rebase branch onto selected",
					cmd = "rebase",
					args = { "-b", "@", "-d", "{target}" },
					phases = {
						{ key = "target", prompt = "Select target commit to rebase branch onto" },
					},
				},
				{
					key = "3",
					desc = "Rebase with descendants",
					cmd = "rebase",
					args = { "-s", "@", "-d", "{target}" },
					phases = {
						{ key = "target", prompt = "Select target commit to rebase with descendants onto" },
					},
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
					args = { "{target}" },
					confirm = true,
				},
				{
					key = "2",
					desc = "Abandon but retain bookmarks",
					cmd = "abandon",
					args = { "{target}", "--retain-bookmarks" },
					confirm = true,
				},
				{
					key = "3",
					desc = "Abandon but keep descendants unchanged",
					cmd = "abandon",
					args = { "{target}", "--restore-descendants" },
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
			description = "Edit change",
		},
	},

	squash = {
		quick_action = {
			cmd = "squash",
			args = { "-r", "{change_id}" },
			keymap = "s",
			description = "Squash into parent",
			confirm = true,
		},
		menu = {
			keymap = "S",
			title = "Squash Options",
			options = {
				{
					key = "1",
					desc = "Squash into selected commit",
					cmd = "squash",
					args = { "-r", "{change_id}", "-d", "{target}" },
					phases = {
						{ key = "target", prompt = "Select commit to squash into" },
					},
				},
			},
		},
	},

	commit = {
		quick_action = {
			cmd = "commit",
			args = { "-m", "{user_input}" },
			keymap = "c",
			description = "Commit changes",
		},
	},

	-- Immediate commands (no selection needed)
	describe_current = {
		quick_action = {
			cmd = "describe",
			args = { "-r", "{change_id}", "-m", "{user_input}" },
			keymap = "d",
			description = "Edit description of current commit",
		},
	},

	status = {
		quick_action = {
			cmd = "status",
			args = {},
			keymap = "?",
			description = "Show current repository status",
		},
		menu = {
			keymap = "?",
			title = "Status Options",
			options = {
				{
					key = "1",
					desc = "Show repository status",
					cmd = "status",
					args = {},
				},
			},
		},
	},

	split = {
		quick_action = {
			cmd = "split",
			args = { "-r", "{change_id}", "-i" },
			keymap = "x",
			description = "Split commit interactively",
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

-- Register all default commands in the unified command system
function M.register_all_defaults()
	-- Register in command context system with proper phase processing
	for name, definition in pairs(DEFAULT_COMMANDS) do
		command_context.register_command(name, definition)
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

	-- Build and execute command using unified parameter substitution
	local args = command_def.quick_action.args or {}
	local substituted_args = command_context.substitute_final_placeholders(args, context)

	-- Build command string
	local command_parts = { command_def.quick_action.cmd }
	for _, arg in ipairs(substituted_args) do
		-- Quote arguments that contain spaces or are empty strings
		if arg == "" or string.match(arg, "%s") then
			table.insert(command_parts, '"' .. arg .. '"')
		else
			table.insert(command_parts, arg)
		end
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
