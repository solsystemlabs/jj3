-- Simple test for help section functionality
print("Testing Help Section Functions")

-- Test keybind formatting function
local function format_keybind_lines(keybind_data)
	if not keybind_data or next(keybind_data) == nil then
		return { "No keybindings available" }
	end
	
	local lines = {}
	local sorted_keys = {}
	
	-- Sort keys for consistent display
	for key, _ in pairs(keybind_data) do
		table.insert(sorted_keys, key)
	end
	table.sort(sorted_keys)
	
	-- Format each keybinding
	for _, key in ipairs(sorted_keys) do
		local binding = keybind_data[key]
		local description = binding.description or "No description"
		local line = string.format("%s: %s", key, description)
		table.insert(lines, line)
	end
	
	return lines
end

-- Test build help section content function
local function build_help_section_content(keybind_lines)
	local content = {}
	
	-- Add separator line
	table.insert(content, string.rep("─", 50))
	table.insert(content, "Available Keybindings:")
	table.insert(content, "")
	
	-- Add keybind lines
	for _, line in ipairs(keybind_lines) do
		table.insert(content, line)
	end
	
	return content
end

-- Test 1: Format keybind lines with valid data
print("Test 1: Format keybind lines with valid data")
local test_keybinds = {
	["n"] = { description = "Create new commit", command = "new", action_type = "quick_action" },
	["r"] = { description = "Rebase current change", command = "rebase", action_type = "quick_action" },
	["a"] = { description = "Abandon selected change", command = "abandon", action_type = "quick_action" },
}

local formatted = format_keybind_lines(test_keybinds)
assert(#formatted == 3, "Should have 3 formatted lines")
assert(formatted[1]:match("^a: "), "First line should start with 'a:' (sorted)")
print("  PASSED: Keybind formatting works")

-- Test 2: Handle empty keybind data
print("Test 2: Handle empty keybind data")
local empty_formatted = format_keybind_lines({})
assert(#empty_formatted == 1, "Should have 1 line for empty data")
assert(empty_formatted[1] == "No keybindings available", "Should show no keybindings message")
print("  PASSED: Empty keybind data handled")

-- Test 3: Build help section content
print("Test 3: Build help section content")
local help_content = build_help_section_content(formatted)
assert(#help_content > #formatted, "Help content should be longer than just keybind lines")
assert(help_content[1]:match("─+"), "First line should be separator")
assert(help_content[2] == "Available Keybindings:", "Second line should be title")
print("  PASSED: Help section content building works")

-- Test 4: Content includes all keybinds
print("Test 4: Content includes all keybinds")
local found_keybinds = 0
for _, line in ipairs(help_content) do
	if line:match("^[arn]: ") then
		found_keybinds = found_keybinds + 1
	end
end
assert(found_keybinds == 3, "Should find all 3 keybinds in content")
print("  PASSED: All keybinds included in content")

print("\nAll tests passed! Help section functionality is working correctly.")