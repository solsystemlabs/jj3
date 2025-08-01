-- Main entry point for jj.nvim plugin
local M = {}

-- Plugin setup function
function M.setup(opts)
	opts = opts or {}

	-- Load configuration
	local config = require("jj.config")
	config.setup(opts)

	-- Initialize selection integration system (must be done first)
	local selection_integration = require("jj.selection_integration")
	selection_integration.setup()

	-- Initialize command execution framework
	local default_commands = require("jj.default_commands")
	default_commands.register_all_defaults()

	-- Load user customizations if provided
	local user_config = config.get()
	if user_config.commands then
		local command_context = require("jj.command_context")
		command_context.merge_user_commands(user_config.commands)
	end

	-- Apply user keybinding overrides if provided
	if user_config.keybinding_overrides then
		local keybindings = require("jj.keybindings")
		keybindings.apply_user_keybinding_overrides(user_config.keybinding_overrides)
	end

	-- Configure interactive command detection if available
	if user_config.interactive then
		local ok, interactive_detection = pcall(require, "jj.interactive_detection")
		if ok then
			interactive_detection.set_user_config(user_config.interactive)
		end
	end

	-- Note: Auto-refresh is handled by individual commands, not globally
	-- This provides better control over when refresh happens

	-- Load commands
	local commands = require("jj.commands")
	commands.setup()
end

return M
