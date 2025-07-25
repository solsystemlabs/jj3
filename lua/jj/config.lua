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
	},
}

-- Current configuration (starts with defaults)
M.options = vim.deepcopy(M.defaults)

-- Setup configuration
function M.setup(opts)
	opts = opts or {}
	M.options = vim.tbl_deep_extend("force", M.defaults, opts)
end

-- Get current configuration
function M.get()
	return M.options
end

return M
