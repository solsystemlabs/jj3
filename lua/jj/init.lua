-- Main entry point for jj.nvim plugin
local M = {}

-- Plugin setup function
function M.setup(opts)
	opts = opts or {}

	-- Load configuration
	local config = require("jj.config")
	config.setup(opts)

	-- Setup auto-refresh system
	local auto_refresh = require("jj.auto_refresh")
	auto_refresh.setup_default_auto_refresh()

	-- Load commands
	local commands = require("jj.commands")
	commands.setup()
end

return M
