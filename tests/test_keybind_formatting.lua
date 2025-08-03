-- Tests for keybind formatting functionality
print("Testing Keybind Formatting")

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

-- Mock required modules
package.loaded["jj.log.renderer"] = { render_to_buffer = function() return true end }
package.loaded["jj.ui.navigation_integration"] = { 
	setup_navigation_integration = function() end,
	cleanup_navigation_for_buffer = function() end
}
package.loaded["jj.config"] = { get = function() return {} end }
package.loaded["jj.default_commands"] = { 
	get_all_default_commands = function() return {} end 
}
package.loaded["jj.command_context"] = { 
	get_command_definition = function() return nil end 
}
package.loaded["jj.keybindings"] = {
	_get_effective_keymap = function() return nil end
}

local window = require("jj.ui.window")

-- Test 1: Format valid keybind data
print("Test 1: Format valid keybind data")
local test_keybinds = {
	["n"] = { description = "Create new commit", command = "new", action_type = "quick_action" },
	["R"] = { description = "Rebase Options", command = "rebase", action_type = "menu" },
	["x"] = { description = "Split commit interactively", command = "split", action_type = "quick_action" },
}

local formatted_lines = window.format_keybind_lines(test_keybinds)
assert(type(formatted_lines) == "table", "Should return a table")
assert(#formatted_lines == 3, "Should have 3 formatted lines")

-- Check sorting (keys should be alphabetical)
assert(formatted_lines[1]:match("^R:"), "First line should start with 'R' (sorted)")
assert(formatted_lines[2]:match("^n:"), "Second line should start with 'n' (sorted)")
assert(formatted_lines[3]:match("^x:"), "Third line should start with 'x' (sorted)")

-- Check format: "key: description"
for _, line in ipairs(formatted_lines) do
	assert(line:match("^.: "), "Each line should have format 'key: description'")
end
print("  PASSED: Valid keybind data formatted correctly")

-- Test 2: Handle empty keybind data
print("Test 2: Handle empty keybind data")
local empty_lines = window.format_keybind_lines({})
assert(type(empty_lines) == "table", "Should return a table")
assert(#empty_lines == 1, "Should have 1 line for empty data")
assert(empty_lines[1] == "No keybindings available", "Should show appropriate message")
print("  PASSED: Empty keybind data handled")

-- Test 3: Handle nil keybind data
print("Test 3: Handle nil keybind data")
local nil_lines = window.format_keybind_lines(nil)
assert(type(nil_lines) == "table", "Should return a table")
assert(#nil_lines == 1, "Should have 1 line for nil data")
assert(nil_lines[1] == "No keybindings available", "Should show appropriate message")
print("  PASSED: Nil keybind data handled")

-- Test 4: Handle keybinds with missing descriptions
print("Test 4: Handle keybinds with missing descriptions")
local missing_desc_keybinds = {
	["t"] = { command = "test", action_type = "quick_action" }, -- No description
	["s"] = { description = "Valid description", command = "save", action_type = "quick_action" },
}

local desc_lines = window.format_keybind_lines(missing_desc_keybinds)
assert(#desc_lines == 2, "Should have 2 lines")
assert(desc_lines[1]:match("s: Valid description"), "Valid description should be shown")
assert(desc_lines[2]:match("t: No description"), "Missing description should show fallback")
print("  PASSED: Missing descriptions handled")

-- Test 5: Build complete help section content
print("Test 5: Build complete help section content")
local help_content = window.build_help_section_content(formatted_lines)
assert(type(help_content) == "table", "Should return a table")
assert(#help_content > #formatted_lines, "Should be longer than just keybind lines")

-- Check structure
assert(help_content[1]:match("─+"), "First line should be separator")
assert(help_content[2] == "Available Keybindings:", "Second line should be title")
assert(help_content[3] == "", "Third line should be empty")

-- Check that all keybind lines are included
local keybind_lines_found = 0
for i = 4, #help_content do
	if help_content[i]:match("^.: ") then
		keybind_lines_found = keybind_lines_found + 1
	end
end
assert(keybind_lines_found == 3, "Should include all 3 keybind lines")
print("  PASSED: Help section content built correctly")

-- Test 6: Build help section with empty keybinds
print("Test 6: Build help section with empty keybinds")
local empty_help = window.build_help_section_content({"No keybindings available"})
assert(type(empty_help) == "table", "Should return a table")
assert(#empty_help == 4, "Should have separator, title, empty line, and message")
assert(empty_help[4] == "No keybindings available", "Should include the no keybindings message")
print("  PASSED: Help section with empty keybinds handled")

print("\nAll keybind formatting tests passed!")