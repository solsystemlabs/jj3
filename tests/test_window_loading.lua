-- Test that window module can be loaded with help section functions
print("Testing Window Module Loading")

-- Set up package path
package.path = "lua/?.lua;" .. package.path

-- Mock vim global to prevent errors
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

-- Mock required modules
package.loaded["jj.log.renderer"] = { render_to_buffer = function() return true end }
package.loaded["jj.ui.navigation_integration"] = { 
	setup_navigation_integration = function() end,
	cleanup_navigation_for_buffer = function() end
}
package.loaded["jj.config"] = { get = function() return {} end }
package.loaded["jj.default_commands"] = { 
	get_all_default_commands = function() 
		return {
			new = {
				quick_action = { keymap = "n", description = "Create new commit" },
				menu = { keymap = "N", title = "New Commit Options" }
			}
		}
	end 
}
package.loaded["jj.command_context"] = { 
	get_command_definition = function(name) 
		local commands = package.loaded["jj.default_commands"].get_all_default_commands()
		return commands[name]
	end 
}

print("Test 1: Loading window module")
local success, window = pcall(require, "jj.ui.window")
if success then
	print("  PASSED: Window module loaded successfully")
else
	print("  FAILED: " .. tostring(window))
	return
end

print("Test 2: Help section functions exist")
assert(type(window.get_merged_keybinds) == "function", "get_merged_keybinds should be a function")
assert(type(window.format_keybind_lines) == "function", "format_keybind_lines should be a function")
assert(type(window.build_help_section_content) == "function", "build_help_section_content should be a function")
assert(type(window.render_help_section) == "function", "render_help_section should be a function")
assert(type(window.toggle_help_section) == "function", "toggle_help_section should be a function")
print("  PASSED: All help section functions exist")

print("Test 3: Get merged keybinds works")
local keybinds = window.get_merged_keybinds()
assert(type(keybinds) == "table", "Should return a table")
print("  PASSED: get_merged_keybinds returns table")

print("Test 4: Format keybind lines works")
local test_data = { n = { description = "Test", command = "test", action_type = "quick_action" } }
local lines = window.format_keybind_lines(test_data)
assert(type(lines) == "table", "Should return a table")
assert(#lines > 0, "Should return at least one line")
print("  PASSED: format_keybind_lines works")

print("\nAll module loading tests passed!")