-- Main entry point for jj.nvim plugin
local M = {}

-- Plugin setup function
function M.setup(opts)
	opts = opts or {}

	-- Load configuration
	local config = require("jj.config")
	config.setup(opts)

	-- Load commands
	local commands = require("jj.commands")
	commands.setup()
end

return M
