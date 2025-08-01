-- Dual-level keybinding system for jj.nvim
local M = {}

-- Import dependencies
local command_context = require("jj.command_context")
local selection_integration = require("jj.selection_integration")
local menu = require("jj.menu")

-- Internal keybinding registry to track registered keymaps
local keybinding_registry = {}
local user_overrides = {}

-- Register keybindings for a single command
function M.register_command_keybindings(buffer_id, command_name)
	if not buffer_id or type(buffer_id) ~= "number" then
		return {
			success = false,
			error = "Invalid buffer ID provided",
		}
	end

	local command_def = command_context.get_command(command_name)
	if not command_def then
		return {
			success = false,
			error = "Command '" .. command_name .. "' not found in registry",
		}
	end

	local success = true
	local errors = {}

	-- Register quick action keybinding (lowercase)
	if command_def.quick_action and command_def.quick_action.keymap then
		local keymap = M._get_effective_keymap(command_name, "quick_action")

		if keymap and keymap ~= "" then
			local quick_action_result = M._register_single_keybinding(
				buffer_id,
				keymap,
				command_name,
				"quick_action",
				command_def.quick_action.description
			)

			if not quick_action_result.success then
				success = false
				table.insert(errors, quick_action_result.error)
			end
		else
			success = false
			table.insert(errors, "Invalid keymap for " .. command_name .. " quick_action: " .. tostring(keymap))
		end
	end

	-- Register menu keybinding (uppercase)
	if command_def.menu and command_def.menu.keymap then
		local keymap = M._get_effective_keymap(command_name, "menu")

		if keymap and keymap ~= "" then
			local menu_result = M._register_single_keybinding(
				buffer_id,
				keymap,
				command_name,
				"menu",
				command_def.menu.title or (command_name .. " Options")
			)

			if not menu_result.success then
				success = false
				table.insert(errors, menu_result.error)
			end
		else
			success = false
			table.insert(errors, "Invalid keymap for " .. command_name .. " menu: " .. tostring(keymap))
		end
	end

	if success then
		return { success = true }
	else
		return {
			success = false,
			error = "Keybinding registration failed: " .. table.concat(errors, ", "),
		}
	end
end

-- Register keybindings for multiple commands
function M.register_all_command_keybindings(buffer_id, commands)
	local results = {}
	local overall_success = true

	for _, command_name in ipairs(commands) do
		local result = M.register_command_keybindings(buffer_id, command_name)
		results[command_name] = result

		if not result.success then
			overall_success = false
		end
	end

	return {
		success = overall_success,
		results = results,
	}
end

-- Register all default keybindings for jj log buffer
function M.register_all_default_keybindings(buffer_id)
	-- Auto-discover all commands from default_commands module
	local default_commands_module = require("jj.default_commands")
	local all_default_commands = default_commands_module.get_all_default_commands()
	
	-- Extract command names from the table
	local command_names = {}
	for command_name, _ in pairs(all_default_commands) do
		table.insert(command_names, command_name)
	end
	
	return M.register_all_command_keybindings(buffer_id, command_names)
end

-- Setup keybindings for jj buffer (integration point)
function M.setup_jj_buffer_keybindings(buffer_id)
	return M.register_all_default_keybindings(buffer_id)
end

-- Detect keybinding conflicts for a command
function M.detect_keybinding_conflicts(buffer_id, command_name)
	local conflicts = {}
	local command_def = command_context.get_command(command_name)

	if not command_def then
		return conflicts
	end

	-- Check quick action conflicts
	if command_def.quick_action and command_def.quick_action.keymap then
		local keymap = M._get_effective_keymap(command_name, "quick_action")
		if keybinding_registry[buffer_id] and keybinding_registry[buffer_id][keymap] then
			table.insert(conflicts, {
				key = keymap,
				type = "quick_action",
				existing_command = keybinding_registry[buffer_id][keymap].command,
			})
		end
	end

	-- Check menu conflicts
	if command_def.menu and command_def.menu.keymap then
		local keymap = M._get_effective_keymap(command_name, "menu")
		if keybinding_registry[buffer_id] and keybinding_registry[buffer_id][keymap] then
			table.insert(conflicts, {
				key = keymap,
				type = "menu",
				existing_command = keybinding_registry[buffer_id][keymap].command,
			})
		end
	end

	return conflicts
end

-- Apply user keybinding overrides
function M.apply_user_keybinding_overrides(overrides)
	if type(overrides) ~= "table" then
		return {
			success = false,
			error = "User overrides must be a table",
		}
	end

	-- Validate overrides
	for command_name, command_overrides in pairs(overrides) do
		if type(command_overrides) ~= "table" then
			return {
				success = false,
				error = "Invalid override for command '" .. command_name .. "': must be a table",
			}
		end

		for action_type, action_override in pairs(command_overrides) do
			if action_type == "quick_action" or action_type == "menu" then
				if action_override.keymap and action_override.keymap == "" then
					return {
						success = false,
						error = "Invalid keymap for " .. command_name .. " " .. action_type .. ": cannot be empty",
					}
				end
			end
		end
	end

	-- Apply valid overrides
	user_overrides = vim.tbl_deep_extend("force", user_overrides, overrides)

	return { success = true }
end

-- Internal function to register a single keybinding
function M._register_single_keybinding(buffer_id, keymap, command_name, action_type, description)
	if not buffer_id or type(buffer_id) ~= "number" then
		return {
			success = false,
			error = "Invalid buffer_id: " .. tostring(buffer_id),
		}
	end

	if not keymap or keymap == "" then
		return {
			success = false,
			error = "Invalid keymap: " .. tostring(keymap),
		}
	end

	local success, error_msg = pcall(function()
		local rhs

		if action_type == "quick_action" then
			rhs = string.format('<cmd>lua require("jj.keybindings")._execute_quick_action("%s")<CR>', command_name)
		elseif action_type == "menu" then
			rhs = string.format('<cmd>lua require("jj.keybindings")._show_command_menu("%s")<CR>', command_name)
		else
			error("Invalid action type: " .. action_type)
		end

		vim.api.nvim_buf_set_keymap(buffer_id, "n", keymap, rhs, {
			silent = true,
			noremap = true,
			desc = description,
		})

		-- Track in registry
		keybinding_registry[buffer_id] = keybinding_registry[buffer_id] or {}
		keybinding_registry[buffer_id][keymap] = {
			command = command_name,
			action_type = action_type,
			description = description,
		}
	end)

	if success then
		return { success = true }
	else
		local error_string = error_msg and tostring(error_msg) or "unknown error"
		return {
			success = false,
			error = "Failed to register keybinding '" .. (keymap or "unknown") .. "': " .. error_string,
		}
	end
end

-- Internal function to get effective keymap (considering user overrides)
function M._get_effective_keymap(command_name, action_type)
	local command_def = command_context.get_command(command_name)
	local default_keymap

	if action_type == "quick_action" and command_def.quick_action then
		default_keymap = command_def.quick_action.keymap
	elseif action_type == "menu" and command_def.menu then
		default_keymap = command_def.menu.keymap
	end

	-- Check for user override
	if
		user_overrides[command_name]
		and user_overrides[command_name][action_type]
		and user_overrides[command_name][action_type].keymap
	then
		return user_overrides[command_name][action_type].keymap
	end

	return default_keymap
end

-- Internal function to execute quick action (called by keybinding)
function M._execute_quick_action(command_name)
	local bufnr = vim.api.nvim_get_current_buf()

	-- Get command definition to check if it needs selection workflow
	local command_def = command_context.get_command(command_name)

	if not command_def then
		vim.notify("Command not found: " .. command_name, vim.log.levels.ERROR)
		return
	end

	-- Check if this command has phases (needs selection workflow)
	if command_def.quick_action and command_def.quick_action.phases then
		-- Use the selection integration system for commands with phases
		local result = selection_integration.execute_command(command_name, bufnr)

		-- Provide user feedback based on result type
		if result.success then
			if result.requires_selection then
				-- Selection workflow started - user feedback handled by selection system
				vim.notify(result.message or "Selection mode started", vim.log.levels.INFO)
			else
				-- Immediate command executed - show command details if available
				local success_msg = "Command executed successfully"
				if result.executed_command then
					success_msg = "Successfully executed: " .. result.executed_command
				end
				vim.notify(success_msg, vim.log.levels.INFO)

				-- Refresh the log window after successful immediate command
				local log = require("jj.log.init")
				log.refresh_log()
			end
		else
			local message = "Command failed: " .. command_name
			if result.error then
				message = message .. " (" .. result.error .. ")"
			end
			vim.notify(message, vim.log.levels.ERROR)
		end
	else
		-- Execute immediately using the old system for commands without phases
		local default_commands = require("jj.default_commands")
		local context = M._get_current_cursor_context()
		local result = default_commands.execute_with_confirmation(command_name, context)

		if result.success then
			-- For interactive commands, don't show success message since terminal handles the interaction
			-- For non-interactive commands, only refresh the log
			if not result.interactive then
				local commit_info = context.change_id or context.commit_id or "@"
				local success_msg = string.format("jj %s %s executed successfully", command_name, commit_info)
				vim.notify(success_msg, vim.log.levels.INFO)
			end

			-- Refresh the log window for non-interactive commands
			if not result.interactive then
				local log = require("jj.log.init")
				log.refresh_log()
			end
		elseif result.queued then
			-- Command was queued - this is normal during refresh, don't show error
		else
			local message = "Command failed: " .. command_name
			if result.error then
				message = message .. " (" .. result.error .. ")"
			end
			vim.notify(message, vim.log.levels.ERROR)
		end
	end
end

-- Get context from current cursor position using proper line-to-commit mapping
function M._get_current_cursor_context()
	local bufnr = vim.api.nvim_get_current_buf()
	local window_id = vim.api.nvim_get_current_win()

	local success, result = pcall(function()
		local navigation_integration = require("jj.ui.navigation_integration")

		-- Check if navigation is enabled for this buffer
		local is_nav_enabled = navigation_integration.is_navigation_enabled(bufnr)

		if not is_nav_enabled then
			-- Fall back to text parsing method
			local selection_navigation = require("jj.selection_navigation")
			local line_number = vim.api.nvim_win_get_cursor(0)[1]
			local commit_id = selection_navigation.get_commit_id_at_cursor(bufnr, line_number)
			if commit_id then
				return {
					commit_id = commit_id,
					change_id = commit_id,
					target = commit_id,
				}
			else
				return {}
			end
		end

		-- Get the commit object at cursor position using the proper navigation system
		local current_commit = navigation_integration.get_current_commit(bufnr, window_id)

		if current_commit and current_commit.commit_id then
			-- Use nested commit_data if available, fallback to top-level values
			local commit_data = current_commit.commit_data or current_commit
			local commit_id = current_commit.commit_id
			local change_id = (commit_data.change_id and commit_data.change_id ~= "") and commit_data.change_id
				or commit_id

			return {
				commit_id = commit_id,
				change_id = change_id,
				target = commit_id,
			}
		else
			return {}
		end
	end)

	if not success then
		return {}
	end

	return result
end

-- Internal function to show command menu (called by keybinding)
function M._show_command_menu(command_name)
	menu.show_command_menu(command_name)
end

return M
