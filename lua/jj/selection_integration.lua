-- Integration layer connecting selection workflow with existing command system
local M = {}

local selection_navigation = require("jj.selection_navigation")
local command_context = require("jj.command_context")
local selection_state = require("jj.selection_state")
local default_commands = require("jj.default_commands")
local executor = require("jj.log.executor")
local types = require("jj.types")

-- Track active workflows and execution history
local active_workflows = {}
local execution_history = {}

function M.execute_command(command_name, bufnr, command_def_override)
	local command_def = command_def_override or command_context.get_command_definition(command_name)

	if not command_def then
		return {
			success = false,
			error = "Command '" .. command_name .. "' not found",
		}
	end

	if command_def.command_type == types.CommandTypes.IMMEDIATE then
		return M._execute_immediate_command(command_def, bufnr)
	else
		return M._start_selection_workflow(command_name, command_def, bufnr)
	end
end

function M._execute_immediate_command(command_def, bufnr)
	local quick_action = command_def.quick_action
	if not quick_action then
		return {
			success = false,
			error = "Command definition missing quick_action",
		}
	end

	local command_parts = { quick_action.cmd }
	for _, arg in ipairs(quick_action.args or {}) do
		table.insert(command_parts, arg)
	end
	local full_command = table.concat(command_parts, " ")

	local result = executor.execute_jj_command(full_command)

	-- Record execution
	table.insert(execution_history, {
		command = full_command,
		success = result.success,
		output = result.output,
		error = result.error,
		timestamp = os.time(),
	})

	if result.success then
		vim.notify("Command executed successfully", vim.log.levels.INFO)
	else
		vim.notify("Command failed: " .. (result.error or "Unknown error"), vim.log.levels.ERROR)
	end

	return {
		success = result.success,
		requires_selection = false,
		output = result.output,
		error = result.error,
	}
end

-- Start selection workflow for command
function M._start_selection_workflow(command_name, command_def, bufnr)
	-- Start the selection workflow
	local machine = selection_navigation.start_selection_workflow(bufnr, command_def)

	if not machine then
		return {
			success = false,
			error = "Failed to start selection workflow",
		}
	end

	-- Track active workflow
	active_workflows[bufnr] = {
		command_name = command_name,
		command_def = command_def,
		machine = machine,
		started_at = os.time(),
	}

	-- Set up completion callback
	M._setup_workflow_completion(bufnr)

	return {
		success = true,
		requires_selection = true,
		message = "Selection mode started",
	}
end

-- Set up workflow completion monitoring
function M._setup_workflow_completion(bufnr)
	-- This would be called by the selection navigation system when workflow completes
	-- For now, we'll check periodically for EXECUTING_COMMAND state
	local workflow = active_workflows[bufnr]
	if not workflow then
		return
	end

	-- In a real implementation, this would be event-driven
	-- For testing, we'll provide a completion callback
	M._monitor_workflow_completion(bufnr)
end

-- Monitor workflow for completion (simplified for testing)
function M._monitor_workflow_completion(bufnr)
	local workflow = active_workflows[bufnr]
	if not workflow then
		return
	end

	local machine = workflow.machine
	if machine:get_current_state() == types.States.EXECUTING_COMMAND then
		M._complete_workflow(bufnr)
	end
end

-- Complete workflow and execute command
function M._complete_workflow(bufnr)
	local workflow = active_workflows[bufnr]
	if not workflow then
		return
	end

	local machine = workflow.machine
	local context = machine:get_command_context()

	if not context then
		M._cleanup_workflow(bufnr)
		return
	end

	-- Build command with selections
	local success, command_string = M._build_command_string(workflow.command_def, context.selections, context)

	if not success then
		vim.notify("Failed to build command: " .. command_string, vim.log.levels.ERROR)
		M._cleanup_workflow(bufnr)
		return
	end

	-- Execute the command
	local result = executor.execute_jj_command(command_string)

	-- Record execution
	table.insert(execution_history, {
		command = command_string,
		success = result.success,
		output = result.output,
		error = result.error,
		selections = context.selections,
		timestamp = os.time(),
	})

	-- Notify user
	if result.success then
		vim.notify("Command executed successfully", vim.log.levels.INFO)
		
		-- Refresh the log window after successful command execution
		local log = require("jj.log.init")
		log.refresh_log()
	else
		vim.notify("Command failed: " .. (result.error or "Unknown error"), vim.log.levels.ERROR)
	end

	-- Clean up workflow
	M._cleanup_workflow(bufnr)

	-- Signal command completion to state machine
	machine:handle_event(types.Events.COMMAND_COMPLETED, {})
end

-- Build command string with selections substituted and final placeholders resolved
function M._build_command_string(command_def, selections, context)
	local quick_action = command_def.quick_action
	if not quick_action then
		return false, "Command definition missing quick_action"
	end

	local args = quick_action.args or {}
	
	-- Phase 1: Substitute only selection-based placeholders
	local selection_substituted_args = command_context.substitute_selections(args, selections)
	
	-- Phase 2: Substitute all remaining placeholders (user_input, commit_id, etc.)
	local final_args = command_context.substitute_final_placeholders(selection_substituted_args, context or {})

	-- Check for any remaining unsubstituted templates
	for _, arg in ipairs(final_args) do
		if type(arg) == "string" and arg:match("{[^}]+}") then
			return false, "Missing substitution for template: " .. arg
		end
	end

	-- Build final command
	local command_parts = { quick_action.cmd }
	vim.list_extend(command_parts, final_args)

	return true, table.concat(command_parts, " ")
end

-- Clean up workflow state
function M._cleanup_workflow(bufnr)
	active_workflows[bufnr] = nil
	selection_navigation.disable_selection_mode(bufnr)
end

-- Enhance default commands with selection phases
function M.enhance_default_commands()
	-- Register enhanced versions of default commands
	command_context.register_default_commands_with_phases()

	-- Also register existing default commands as immediate commands
	local defaults = default_commands.get_all_default_commands()
	for name, definition in pairs(defaults) do
		-- Register immediate version
		local immediate_def = vim.deepcopy(definition)
		immediate_def.command_type = types.CommandTypes.IMMEDIATE

		command_context.register_command(name .. "_immediate", immediate_def)
	end
end

-- Get commands compatible with menu system
function M.get_menu_compatible_commands()
	local commands = {}
	local all_commands = command_context.get_all_command_definitions()

	for name, definition in pairs(all_commands) do
		table.insert(commands, {
			name = name,
			description = definition.quick_action.description,
			keymap = definition.quick_action.keymap,
			requires_selection = definition.command_type ~= types.CommandTypes.IMMEDIATE,
			command_type = definition.command_type,
		})
	end

	return commands
end

-- Get active workflows
function M.get_active_workflows()
	local workflows = {}
	for bufnr, workflow in pairs(active_workflows) do
		table.insert(workflows, {
			bufnr = bufnr,
			command_name = workflow.command_name,
			started_at = workflow.started_at,
			state = workflow.machine:get_current_state(),
		})
	end
	return workflows
end

-- Get execution history
function M.get_execution_history()
	return execution_history
end

-- Handle workflow cancellation
function M.handle_workflow_cancellation(bufnr)
	local workflow = active_workflows[bufnr]
	if workflow then
		vim.notify("Selection cancelled", vim.log.levels.INFO)
		M._cleanup_workflow(bufnr)
	end
end

-- Integration with selection navigation system
function M.setup_integration()
	-- This would set up callbacks from selection navigation
	-- to complete workflows when they reach EXECUTING_COMMAND state

	-- Override the execution function in selection navigation
	local original_execute = selection_navigation._execute_command_and_cleanup
	selection_navigation._execute_command_and_cleanup = function(bufnr, machine)
		-- Complete the workflow through integration layer
		M._complete_workflow(bufnr)
	end
end

-- Initialize the integration system
function M.setup()
	M.setup_integration()
	M.enhance_default_commands()
end

-- Testing helpers
function M._reset_for_testing()
	active_workflows = {}
	execution_history = {}
end

-- Force workflow completion (for testing)
function M._force_workflow_completion(bufnr)
	M._complete_workflow(bufnr)
end

return M
