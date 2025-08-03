-- Debug keybind retrieval
print("Debugging Keybind Retrieval")

-- Set up package path
package.path = "lua/?.lua;" .. package.path

-- Mock vim global
_G.vim = {
	api = {
		nvim_buf_get_lines = function() return {} end,
		nvim_buf_set_lines = function() end,
		nvim_buf_set_option = function() end,
		nvim_create_buf = function() return 1234 end,
		nvim_buf_is_valid = function() return true end,
	},
	deepcopy = function(t) return t end,
	tbl_isempty = function(t) return next(t) == nil end,
}

-- Mock command definitions
local mock_default_commands = {
	new = {
		quick_action = { keymap = "n", description = "Create new commit" },
		menu = { keymap = "N", title = "New Commit Options" }
	},
	abandon = {
		quick_action = { keymap = "a", description = "Abandon selected change" },
		menu = { keymap = "A", title = "Abandon Options" }
	}
}

-- Mock required modules
package.loaded["jj.log.renderer"] = { render_to_buffer = function() return true end }
package.loaded["jj.ui.navigation_integration"] = { 
	setup_navigation_integration = function() end,
	cleanup_navigation_for_buffer = function() end
}
package.loaded["jj.config"] = { get = function() return {} end }
package.loaded["jj.default_commands"] = { 
	get_all_default_commands = function() 
		print("get_all_default_commands called")
		return mock_default_commands
	end 
}
package.loaded["jj.command_context"] = { 
	get_command_definition = function(name) 
		print("get_command_definition called with:", name)
		return mock_default_commands[name]
	end 
}

local window = require("jj.ui.window")

print("Calling get_merged_keybinds...")
local keybinds = window.get_merged_keybinds(true) -- Skip buffer check for testing

print("Returned keybinds:")
for key, binding in pairs(keybinds) do
	print("  " .. key .. ": " .. binding.description .. " (" .. binding.action_type .. ")")
end

print("Total keybinds:", vim.tbl_count and vim.tbl_count(keybinds) or "unknown")