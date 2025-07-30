-- Debug script to trace selection workflow issue
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

-- Mock vim functions
vim = {
    deepcopy = function(t)
        local copy = {}
        for k, v in pairs(t) do
            if type(v) == "table" then
                copy[k] = vim.deepcopy(v)
            else
                copy[k] = v
            end
        end
        return copy
    end,
    inspect = function(t)
        if type(t) ~= "table" then
            return tostring(t)
        end
        local result = "{"
        for k, v in pairs(t) do
            result = result .. " " .. tostring(k) .. "=" .. vim.inspect(v) .. ","
        end
        return result .. " }"
    end,
    tbl_keys = function(t)
        local keys = {}
        for k, _ in pairs(t) do
            table.insert(keys, k)
        end
        return keys
    end,
    log = {
        levels = {
            INFO = 1,
            WARN = 2,
            ERROR = 3
        }
    },
    notify = function(msg, level) print("NOTIFY:", msg) end
}

local selection_state = require("jj.selection_state")
local types = require("jj.types")
local default_commands = require("jj.default_commands")

print("=== Debugging Selection Flow ===")

-- Get the multi-parent command definition
local new_def = default_commands.get_command_definition("new")
if not new_def then
    print("ERROR: Could not find 'new' command definition")
    return
end

print("Command definition found:")
print("Quick action phases:", new_def.quick_action.phases and #new_def.quick_action.phases or "none")
print("Menu options:", new_def.menu and #new_def.menu.options or "none")

-- Get the multi-parent menu option
local multi_parent_option = new_def.menu.options[1]
print("\nMulti-parent option:")
print("Description:", multi_parent_option.desc)
print("Args:", vim.inspect(multi_parent_option.args))
print("Phases:", multi_parent_option.phases and vim.inspect(multi_parent_option.phases) or "none")

-- Test command type inference
local command_type = selection_state.infer_command_type(multi_parent_option)
print("Inferred command type:", command_type)
print("Expected command type:", types.CommandTypes.MULTI_SELECT)

-- Test state machine transitions
print("\n=== Testing State Machine ===")
local machine = selection_state.new(1) -- buffer_id = 1

-- Start command
print("Starting command...")
local success = machine:handle_event(types.Events.COMMAND_STARTED, {
    command_def = multi_parent_option
})
print("Command started:", success)
print("Current state:", machine:get_current_state())
print("Expected state:", types.States.SELECTING_MULTIPLE)

-- Make first selection
print("\nMaking first selection...")
local success2 = machine:handle_event(types.Events.TARGET_SELECTED, {
    commit_id = "abc123",
    command_def = multi_parent_option
})
print("Selection made:", success2)
print("Current state after selection:", machine:get_current_state())
print("Expected state:", types.States.SELECTING_MULTIPLE)

-- Check context
local context = machine:get_command_context()
if context then
    print("Selections:", vim.inspect(context.selections))
    print("Current phase:", context.current_phase)
    print("Phase index:", context.phase_index)
else
    print("No context available")
end