-- Tests for keybind data retrieval functionality
print("Testing Keybind Data Retrieval")

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

-- Mock command definitions with user overrides
local mock_default_commands = {
	new = {
		quick_action = { keymap = "n", description = "Create new commit" },
		menu = { keymap = "N", title = "New Commit Options" }
	},
	rebase = {
		quick_action = { keymap = "r", description = "Rebase current change" },
		menu = { keymap = "R", title = "Rebase Options" }
	},
	abandon = {
		quick_action = { keymap = "a", description = "Abandon selected change" },
		menu = { keymap = "A", title = "Abandon Options" }
	}
}

-- Mock with user overrides (user changed 'a' to 'x' for abandon)
local mock_merged_commands = {
	new = {
		quick_action = { keymap = "n", description = "Create new commit" },
		menu = { keymap = "N", title = "New Commit Options" }
	},
	rebase = {
		quick_action = { keymap = "r", description = "Rebase current change" },
		menu = { keymap = "R", title = "Rebase Options" }
	},
	abandon = {
		quick_action = { keymap = "x", description = "Abandon selected change" }, -- User override
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
		return mock_default_commands
	end 
}

-- Test default vs merged command resolution
local use_merged = false
package.loaded["jj.command_context"] = { 
	get_command_definition = function(name) 
		if use_merged then
			return mock_merged_commands[name]
		else
			return mock_default_commands[name]
		end
	end 
}

local window = require("jj.ui.window")

-- Test 1: Default keybind retrieval
print("Test 1: Default keybind retrieval")
use_merged = false
local default_keybinds = window.get_merged_keybinds(true) -- Skip buffer check for testing
assert(type(default_keybinds) == "table", "Should return a table")
assert(default_keybinds["a"] ~= nil, "Should have abandon quick action 'a'")
assert(default_keybinds["a"].description == "Abandon selected change", "Should have correct description")
print("  PASSED: Default keybinds retrieved correctly")

-- Test 2: Merged keybind retrieval (with user overrides)
print("Test 2: Merged keybind retrieval with user overrides")
use_merged = true
local merged_keybinds = window.get_merged_keybinds(true) -- Skip buffer check for testing
assert(type(merged_keybinds) == "table", "Should return a table")
assert(merged_keybinds["x"] ~= nil, "Should have user override 'x' for abandon")
assert(merged_keybinds["a"] == nil, "Should not have original 'a' binding")
assert(merged_keybinds["x"].description == "Abandon selected change", "Should have correct description")
print("  PASSED: User overrides applied correctly")

-- Test 3: Both quick actions and menus included
print("Test 3: Both quick actions and menus included")
local keybind_count = 0
local quick_actions = 0
local menus = 0

for key, binding in pairs(merged_keybinds) do
	keybind_count = keybind_count + 1
	if binding.action_type == "quick_action" then
		quick_actions = quick_actions + 1
	elseif binding.action_type == "menu" then
		menus = menus + 1
	end
end

assert(keybind_count == 6, "Should have 6 total keybinds (3 commands x 2 actions each)")
assert(quick_actions == 3, "Should have 3 quick actions")
assert(menus == 3, "Should have 3 menus")
print("  PASSED: Both quick actions and menus included")

-- Test 4: Proper command and action_type metadata
print("Test 4: Proper command and action_type metadata")
local n_binding = merged_keybinds["n"]
assert(n_binding.command == "new", "Should have correct command name")
assert(n_binding.action_type == "quick_action", "Should have correct action type")

local N_binding = merged_keybinds["N"]
assert(N_binding.command == "new", "Should have correct command name") 
assert(N_binding.action_type == "menu", "Should have correct action type")
print("  PASSED: Metadata correctly preserved")

-- Test 5: Handle missing command definitions gracefully
print("Test 5: Handle missing command definitions gracefully")

-- Create a limited default commands set for this test
package.loaded["jj.default_commands"].get_all_default_commands = function() 
	return {
		new = mock_default_commands.new
	}
end

-- Reset command_context to return the command
package.loaded["jj.command_context"].get_command_definition = function(name)
	if name == "new" then
		return mock_default_commands[name]
	else
		return nil -- Simulate missing command
	end
end

local partial_keybinds = window.get_merged_keybinds(true) -- Skip buffer check for testing
assert(type(partial_keybinds) == "table", "Should still return a table")
-- Should only have 'new' command keybinds
local count = 0
for key, binding in pairs(partial_keybinds) do 
	count = count + 1
	print("    Found keybind: " .. key .. " -> " .. binding.description)
end
assert(count == 2, "Should have 2 keybinds (new quick_action and menu), got " .. count)
print("  PASSED: Missing commands handled gracefully")

print("\nAll keybind data retrieval tests passed!")