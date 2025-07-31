-- Configuration management for jj.nvim
local M = {}

-- Default configuration
M.defaults = {
	-- Default keybindings
	keymaps = {
		toggle_log = "<leader>jl",
	},

	-- Window options
	window = {
		position = "right",
		size = 50,
		window_type = "floating", -- "floating" or "split"
		border = {"", "", "", "│", "", "", "", ""}, -- Default: left border only
		title = nil, -- No title by default
		title_pos = "center",
	},

	-- Command customization (user-defined commands)
	commands = {},

	-- Keybinding overrides for default commands
	keybinding_overrides = {},
}

-- Current configuration (starts with defaults)
M.options = vim.deepcopy(M.defaults)

-- Setup configuration
function M.setup(opts)
	opts = opts or {}
	-- Always start with a fresh copy of defaults
	local merged_opts = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts)
	
	-- Validate window_type if provided or ensure it exists
	if merged_opts.window then
		if merged_opts.window.window_type then
			local valid_types = { floating = true, split = true }
			if not valid_types[merged_opts.window.window_type] then
				-- Invalid type, fall back to default
				merged_opts.window.window_type = M.defaults.window.window_type
			end
		else
			-- Ensure window_type is set to default if not provided
			merged_opts.window.window_type = M.defaults.window.window_type
		end
	end
	
	M.options = merged_opts
end

-- Get current configuration
function M.get()
	return M.options
end

return M
