-- Command context management for unified command definitions with selection phases
local M = {}

local types = require("jj.types")
local selection_state = require("jj.selection_state")

-- Registry for processed command definitions
local command_registry = {}

-- Process a command definition to add selection metadata
function M.process_command_definition(name, command_def)
	local processed = vim.deepcopy(command_def)

	-- Extract phases from quick_action or menu options
	local phases = M._extract_phases_from_command(command_def)

	if phases and #phases > 0 then
		processed.phases = phases
		processed.command_type = selection_state.infer_command_type(processed)
	else
		processed.command_type = types.CommandTypes.IMMEDIATE
	end

	return processed
end

-- Extract phase definitions from various parts of command structure
function M._extract_phases_from_command(command_def)
	-- Check quick_action first
	if command_def.quick_action and command_def.quick_action.phases then
		return command_def.quick_action.phases
	end

	-- Check for phases at the top level (for menu-generated command definitions)
	if command_def.phases then
		return command_def.phases
	end

	-- Check if we can infer phases from args that use selection templates
	if command_def.quick_action and command_def.quick_action.args then
		local required_selections = M.extract_required_selections(command_def.quick_action.args)
		if #required_selections > 0 then
			-- Generate phases for required selections
			local phases = {}
			for _, selection_key in ipairs(required_selections) do
				table.insert(phases, {
					key = selection_key,
					prompt = "Select " .. selection_key .. " commit",
				})
			end
			return phases
		end
	end

	return nil
end

-- Extract required selection keys from command argument templates
function M.extract_required_selections(args)
	local selections = {}
	local seen = {}

	for _, arg in ipairs(args) do
		if type(arg) == "string" then
			-- Match {selection_key} patterns, excluding {user_input} and {change_id}
			for selection_key in arg:gmatch("{([^}]+)}") do
				if selection_key ~= "user_input" and selection_key ~= "change_id" and not seen[selection_key] then
					table.insert(selections, selection_key)
					seen[selection_key] = true
				end
			end
		end
	end

	return selections
end

-- Selection-based placeholders that are handled during selection workflow
local SELECTION_PLACEHOLDERS = {
	"target",
	"multi_target",
	"source",
	"destination",
}

-- Check if a placeholder is selection-based
local function is_selection_placeholder(placeholder)
	for _, sel_placeholder in ipairs(SELECTION_PLACEHOLDERS) do
		if placeholder == sel_placeholder then
			return true
		end
	end
	return false
end

-- Substitute only selection values into command argument templates (phase 1)
function M.substitute_selections(args, selections)
	local substituted = {}

	for _, arg in ipairs(args) do
		if type(arg) == "string" then
			local substituted_arg = arg

			-- Only replace selection-based templates with actual values
			for key, value in pairs(selections) do
				if is_selection_placeholder(key) then
					if type(value) == "table" then
						-- Multi-select: join with spaces
						substituted_arg = substituted_arg:gsub("{" .. key .. "}", table.concat(value, " "))
					else
						-- Single selection
						substituted_arg = substituted_arg:gsub("{" .. key .. "}", value)
					end
				end
			end

			table.insert(substituted, substituted_arg)
		else
			table.insert(substituted, arg)
		end
	end

	return substituted
end

-- Substitute all remaining placeholders after selections are complete (phase 2)
function M.substitute_final_placeholders(args, context)
	local substituted = {}

	for _, arg in ipairs(args) do
		if type(arg) == "string" then
			local substituted_arg = arg

			-- Handle user input prompt
			if substituted_arg:match("{user_input}") then
				local input = vim.fn.input("Commit description: ")
				if input and input ~= "" then
					substituted_arg = substituted_arg:gsub("{user_input}", input)
				else
					-- If no input provided, skip this argument and the preceding -m flag if present
					if #substituted > 0 and substituted[#substituted] == "-m" then
						table.remove(substituted)
					end
					goto continue
				end
			end

			-- Handle other context-based placeholders
			if substituted_arg:match("{commit_id}") then
				substituted_arg = substituted_arg:gsub("{commit_id}", context.commit_id or "@")
			end
			if substituted_arg:match("{change_id}") then
				substituted_arg = substituted_arg:gsub("{change_id}", context.change_id or "@")
			end

			table.insert(substituted, substituted_arg)
			::continue::
		else
			table.insert(substituted, arg)
		end
	end

	return substituted
end

-- Validate a command definition for consistency
function M.validate_command_definition(command_def)
	local errors = {}

	if not command_def.quick_action then
		table.insert(errors, "Command definition missing quick_action")
		return false, errors
	end

	local quick_action = command_def.quick_action

	-- Get required selections from args
	local required_selections = {}
	if quick_action.args then
		required_selections = M.extract_required_selections(quick_action.args)
	end

	-- Get defined phases
	local defined_phases = {}
	local phase_keys = {}
	if quick_action.phases then
		for _, phase in ipairs(quick_action.phases) do
			if not phase.key then
				table.insert(errors, "Phase missing required 'key' field")
			elseif phase_keys[phase.key] then
				table.insert(errors, "Duplicate phase key: " .. phase.key)
			else
				phase_keys[phase.key] = true
				table.insert(defined_phases, phase.key)
			end

			if not phase.prompt then
				table.insert(errors, "Phase '" .. (phase.key or "unknown") .. "' missing required 'prompt' field")
			end
		end
	end

	-- Check that all required selections have corresponding phases
	for _, required_key in ipairs(required_selections) do
		if not vim.tbl_contains(defined_phases, required_key) then
			table.insert(errors, "Missing phase definition for required selection: " .. required_key)
		end
	end

	return #errors == 0, errors
end

-- Register a command definition in the system
function M.register_command(name, command_def)
	local processed = M.process_command_definition(name, command_def)
	local is_valid, errors = M.validate_command_definition(command_def)

	if not is_valid then
		error("Invalid command definition for '" .. name .. "': " .. table.concat(errors, ", "))
	end

	command_registry[name] = processed
end

-- Get a registered command definition
function M.get_command_definition(name)
	return command_registry[name]
end

-- Get all registered command definitions
function M.get_all_command_definitions()
	return command_registry
end

-- Register default commands with selection phase support
function M.register_default_commands_with_phases()
	-- Enhanced squash command with selection phase
	M.register_command("squash_into_selected", {
		quick_action = {
			cmd = "squash",
			args = { "--into", "{target}" },
			keymap = "s",
			description = "Squash current working copy into selected commit",
			confirm = true,
			phases = {
				{ key = "target", prompt = "Select target commit to squash into" },
			},
		},
		menu = {
			keymap = "S",
			title = "Squash Options",
			options = {
				{
					key = "1",
					desc = "Squash current working copy into selected",
					cmd = "squash",
					args = { "--into", "{target}" },
					confirm = true,
				},
			},
		},
	})

	-- Enhanced rebase command with multi-phase selection
	M.register_command("rebase_multi_phase", {
		quick_action = {
			cmd = "rebase",
			args = { "--source", "{source}", "--destination", "{destination}" },
			keymap = "r",
			description = "Rebase source commit onto destination",
			phases = {
				{ key = "source", prompt = "Select source commit to rebase" },
				{ key = "destination", prompt = "Select destination commit" },
			},
		},
		menu = {
			keymap = "R",
			title = "Rebase Options",
			options = {
				{
					key = "1",
					desc = "Rebase source onto destination",
					cmd = "rebase",
					args = { "--source", "{source}", "--destination", "{destination}" },
				},
			},
		},
	})

	-- Multi-select abandon command
	M.register_command("abandon_multiple", {
		quick_action = {
			cmd = "abandon",
			args = { "{targets}" },
			keymap = "a",
			description = "Abandon multiple selected commits",
			confirm = true,
			phases = {
				{
					key = "targets",
					prompt = "Select commits to abandon (Enter to add, 'c' to confirm)",
					multi_select = true,
				},
			},
		},
		menu = {
			keymap = "A",
			title = "Abandon Options",
			options = {
				{
					key = "1",
					desc = "Abandon multiple selected commits",
					cmd = "abandon",
					args = { "{targets}" },
					confirm = true,
				},
			},
		},
	})

	-- Immediate command (no selection needed)
	M.register_command("describe_current", {
		quick_action = {
			cmd = "describe",
			args = {},
			keymap = "d",
			description = "Edit description of current commit",
		},
		menu = {
			keymap = "D",
			title = "Describe Options",
			options = {
				{
					key = "1",
					desc = "Edit current commit description",
					cmd = "describe",
					args = {},
				},
			},
		},
	})
end

-- Check if a command requires selection phases
function M.command_requires_selection(command_name)
	local command_def = command_registry[command_name]
	if not command_def then
		return false
	end

	return command_def.command_type ~= types.CommandTypes.IMMEDIATE
end

-- Get the current phase information for a command execution
function M.get_phase_info(command_name, phase_index)
	local command_def = command_registry[command_name]
	if not command_def or not command_def.phases or phase_index > #command_def.phases then
		return nil
	end

	local phase = command_def.phases[phase_index]
	return {
		key = phase.key,
		prompt = phase.prompt,
		multi_select = phase.multi_select or false,
		phase_number = phase_index,
		total_phases = #command_def.phases,
	}
end

-- Testing helper
function M._reset_for_testing()
	command_registry = {}
end

return M
