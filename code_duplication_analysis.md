# Code Duplication Analysis for jj3

This document identifies areas of duplicated logic across the jj3 codebase that should be refactored into reusable functions.

## 1. Buffer Validation Patterns

**Files:** `navigation.lua:160-162`, `selection_navigation.lua:64-67`, `keybindings.lua:203-208`, `window.lua:71-73`

### Current Duplicated Code:

**navigation.lua:**
```lua
local function validate_navigation_params(buffer_id, window_id, boundaries)
  return buffer_id and window_id and boundaries and #boundaries > 0
end
```

**selection_navigation.lua:**
```lua
function M.enable_selection_mode(bufnr, state_machine)
  if selection_enabled_buffers[bufnr] then
    return -- Already enabled
  end
```

**keybindings.lua:**
```lua
if not buffer_id or type(buffer_id) ~= "number" then
  return {
    success = false,
    error = "Invalid buffer ID provided",
  }
end
```

**window.lua:**
```lua
if log_buffer_id and vim.api.nvim_buf_is_valid(log_buffer_id) then
  return log_buffer_id
end
```

### Problem:
Each module implements its own buffer validation logic with different return patterns and error handling.

## 2. Error Result Structure Patterns

**Files:** `keybindings.lua`, `command_execution.lua`, `selection_navigation.lua`

### Current Duplicated Code:

**keybindings.lua (multiple locations):**
```lua
return {
  success = false,
  error = "Invalid buffer ID provided",
}
```

**command_execution.lua:**
```lua
return {
  success = false,
  error = "Command '" .. name .. "' not found in registry",
}
```

### Problem:
Inconsistent error result structures across modules. Some use `error`, others might use `message` or other fields.

## 3. Commit ID Extraction Patterns

**Files:** `selection_navigation.lua:36-44`, `keybindings.lua:356-367`, `command_execution.lua:72-84`

### Current Duplicated Code:

**selection_navigation.lua:**
```lua
-- Try each pattern to extract commit ID
for _, pattern in ipairs(COMMIT_ID_PATTERNS) do
  local commit_id = line:match(pattern)
  if commit_id and #commit_id >= 6 then -- Reasonable commit ID length
    return commit_id
  end
end
```

**keybindings.lua:**
```lua
local selection_navigation = require("jj.selection_navigation")
local line_number = vim.api.nvim_win_get_cursor(0)[1]
local commit_id = selection_navigation.get_commit_id_at_cursor(bufnr, line_number)
if commit_id then
  return {
    commit_id = commit_id,
    change_id = commit_id,
    target = commit_id,
  }
end
```

### Problem:
Multiple ways of extracting commit IDs from cursor position with different fallback strategies.

## 4. Window/Buffer State Management

**Files:** `window.lua:338-340`, `navigation.lua:141-144`, `selection_navigation.lua:103-105`

### Current Duplicated Code:

**window.lua:**
```lua
function M.is_log_window_open()
  return log_window_id ~= nil and vim.api.nvim_win_is_valid(log_window_id)
end
```

**selection_navigation.lua:**
```lua
function M.is_selection_mode_enabled(bufnr)
  return selection_enabled_buffers[bufnr] ~= nil
end
```

### Problem:
Similar state checking patterns for different types of windows/buffers.

## 5. Keymap Registration Patterns

**Files:** `navigation.lua:244-254`, `navigation.lua:370-382`, `selection_navigation.lua:204-214`

### Current Duplicated Code:

**navigation.lua:**
```lua
vim.api.nvim_buf_set_keymap(buffer_id, 'n', 'j', '', {
  noremap = true,
  silent = true,
  callback = function()
    local window_id = vim.api.nvim_get_current_win()
    if not M.navigate_to_next_commit(buffer_id, window_id, boundaries) then
      -- If navigation failed, fall back to normal j movement
      vim.api.nvim_feedkeys('j', 'n', false)
    end
  end
})
```

**selection_navigation.lua:**
```lua
vim.keymap.set("n", "<Space>", function()
  M.handle_selection_key(bufnr)
end, opts)
```

### Problem:
Different keymap registration APIs and patterns used inconsistently across modules.

## 6. Success/Failure Result Patterns

**Files:** `keybindings.lua:79-86`, `command_execution.lua:91-95`, `window.lua` (multiple locations)

### Current Duplicated Code:

**keybindings.lua:**
```lua
if success then
  return { success = true }
else
  return {
    success = false,
    error = "Keybinding registration failed: " .. table.concat(errors, ", "),
  }
end
```

**command_execution.lua:**
```lua
return {
  success = false,
  error = "Command '" .. name .. "' not found in registry",
}
```

### Problem:
Repeated success/failure result construction with inconsistent field names.

## 7. Highlight Namespace Management

**Files:** `navigation.lua:5-6`, `visual_feedback.lua:10-15`, `window.lua:594`

### Current Duplicated Code:

**navigation.lua:**
```lua
local HIGHLIGHT_NAMESPACE = vim.api.nvim_create_namespace("jj_commit_navigation")
local HIGHLIGHT_GROUP = "JJCommitBlock"
```

**visual_feedback.lua:**
```lua
local function ensure_highlight_namespace()
  if not highlight_namespace then
    highlight_namespace = vim.api.nvim_create_namespace("jj3_selection_highlights")
  end
  return highlight_namespace
end
```

**window.lua:**
```lua
local namespace = vim.api.nvim_create_namespace("jj_full_width_highlighting")
```

### Problem:
Different patterns for creating and managing highlight namespaces.

## 8. Configuration Merging/Validation

**Files:** `window.lua:188-229`, `window.lua:364-442`, `keybindings.lua:166-199`

### Current Duplicated Code:

**window.lua (repeated pattern):**
```lua
-- Apply global window configuration
if user_global_config.window then
  -- Map window_type from config to style
  if user_global_config.window.window_type == "floating" then
    merged_config.style = "floating"
  elseif user_global_config.window.window_type == "split" then
    merged_config.style = "split"
    merged_config.position = user_global_config.window.position or "right"
  end
  
  -- Apply other window config options
  if user_global_config.window.size then
    merged_config.width = user_global_config.window.size
  end
end
```

### Problem:
Complex configuration merging logic duplicated across different contexts.

## 9. Parameter Substitution Logic (MAJOR DUPLICATION)

**Files:** `default_commands.lua:291-327`, `command_execution.lua:36-69`

### Current Duplicated Code:

**default_commands.lua (lines 291-327):**
```lua
for _, arg in ipairs(args) do
  if arg == "{commit_id}" then
    table.insert(substituted_args, context.commit_id or "@")
  elseif arg == "{change_id}" then
    table.insert(substituted_args, context.change_id or "@")
  elseif arg == "{target}" then
    table.insert(substituted_args, context.target or context.commit_id or "@")
  elseif arg == "{multi_target}" then
    -- Handle multiple targets for multi-parent commits
    if context.multi_target and type(context.multi_target) == "table" then
      for _, target in ipairs(context.multi_target) do
        table.insert(substituted_args, target)
      end
    else
      -- Fallback to single target
      table.insert(substituted_args, context.target or context.commit_id or "@")
    end
  elseif arg == "{user_input}" then
    local input = vim.fn.input("Commit description: ")
    if input ~= "" then
      table.insert(substituted_args, input)
    end
    -- Skip empty input - don't add to substituted args
  else
    table.insert(substituted_args, arg)
  end
end
```

**command_execution.lua (lines 36-69):**
```lua
for _, arg in ipairs(args) do
  if arg == "{commit_id}" then
    table.insert(substituted, context.commit_id or "@")
  elseif arg == "{change_id}" then
    table.insert(substituted, context.change_id or context.commit_id or "@")
  elseif arg == "{target}" then
    table.insert(substituted, context.target or context.commit_id or "@")
  elseif arg == "{multi_target}" then
    -- Handle multiple targets for multi-parent commits
    if context.multi_target and type(context.multi_target) == "table" then
      for _, target in ipairs(context.multi_target) do
        table.insert(substituted, target)
      end
    else
      -- Fallback to single target
      table.insert(substituted, context.target or context.commit_id or "@")
    end
  elseif arg == "{user_input}" then
    local input = vim.fn.input("Enter value: ")
    if input ~= "" then
      table.insert(substituted, input)
    end
    -- Skip empty input - don't add to substituted args
  else
    table.insert(substituted, arg)
  end
end
```

### Problem:
**This is a massive duplication** - essentially identical parameter substitution logic with minor differences (prompt text, variable names). The logic for handling `{commit_id}`, `{change_id}`, `{target}`, `{multi_target}`, and `{user_input}` is nearly identical between both files.

## 10. PCCall Error Handling Patterns

**Files:** `keybindings.lua:217-241`, `window.lua:296-298`, `keybindings.lua:348-388`

### Current Duplicated Code:

**keybindings.lua:**
```lua
local success, error_msg = pcall(function()
  -- ... implementation
end)

if success then
  return { success = true }
else
  local error_string = error_msg and tostring(error_msg) or "unknown error"
  return {
    success = false,
    error = "Failed to register keybinding '" .. (keymap or "unknown") .. "': " .. error_string,
  }
end
```

### Problem:
Repeated pcall patterns with similar error handling and result formatting.

## Recommended Refactoring Strategy

1. **PRIORITY: Create a `jj.utils.parameters` module** for unified parameter substitution logic
   - **This is the most critical fix** - the identical 36-line parameter substitution blocks should be consolidated immediately
   - Consolidate `{commit_id}`, `{change_id}`, `{target}`, `{multi_target}`, and `{user_input}` handling
   - Allow customizable input prompts while maintaining consistent substitution logic

2. **Create a `jj.utils.validation` module** for common buffer/window validation
3. **Create a `jj.utils.results` module** for standardized success/error result structures
4. **Create a `jj.utils.commit_detection` module** for unified commit ID extraction
5. **Create a `jj.utils.keymaps` module** for consistent keymap registration
6. **Create a `jj.utils.config` module** for configuration merging patterns
7. **Create a `jj.utils.highlights` module** for highlight namespace management
8. **Create a `jj.utils.errors` module** for pcall error handling patterns

These utility modules would eliminate the identified duplication and provide consistent interfaces across the codebase.

## CRITICAL ARCHITECTURAL ISSUE: Multiple Command Execution Systems

The codebase has **three overlapping command execution systems** causing massive duplication:

### 1. Legacy System (`command_execution.lua`)
- Original command execution framework
- Contains `substitute_parameters()` function (lines 36-69)
- Used by `keybindings.lua` for backwards compatibility

### 2. Default Commands System (`default_commands.lua`) 
- Contains `execute_with_confirmation()` with **identical parameter substitution** (lines 291-327)
- Registers commands in "both legacy and new command systems" (line 243)
- Supposed to be replaced entirely by new system

### 3. New System (`command_context.lua` + `selection_integration.lua`)
- Modern selection-aware command framework
- Has its own parameter substitution via `substitute_final_placeholders()` (line 204)
- **Still calls the legacy system**: `command_execution.substitute_parameters()` (line 130)

### The Core Problem

The "legacy" system was **never fully replaced**. Instead of eliminating it, the new system:
- **Wraps the legacy system** (`command_context.lua:130` calls `command_execution.substitute_parameters`)
- **Duplicates legacy logic** (`default_commands.lua` re-implements the same substitution)
- **Maintains parallel registrations** (line 243: "Register in both the legacy and new command systems")

### ✅ COMPLETED: Architectural Cleanup

**All major duplications have been eliminated:**

1. ✅ **ELIMINATED** the legacy `command_execution.lua` entirely
2. ✅ **ELIMINATED** the duplicated substitution in `default_commands.lua` 
3. ✅ **CONSOLIDATED** to single command execution system via `command_context.lua`
4. ✅ **REMOVED** all "legacy compatibility" code

**Results:**
- **Eliminated 36+ lines of duplicated parameter substitution code**
- **Removed entire legacy command system** (197 lines deleted)
- **Unified all command execution** through single system
- **Updated 7 files** to use consolidated system

The largest blocks of duplicated code have been eliminated and the command system is now significantly simplified.
