# Technical Specification

This is the technical specification for the spec detailed in @.agent-os/specs/2025-07-28-command-execution-framework/spec.md

> Created: 2025-07-28
> Version: 1.0.0

## Technical Requirements

### Core Command Engine
- **Generic Executor**: Use existing `log/executor.lua` as foundation but extend for interactive command execution
- **Parameter Substitution**: Template system supporting `{commit_id}`, `{change_id}`, and `{user_input}` placeholders
- **Error Handling**: Comprehensive error capture with user-friendly messages and fallback behaviors
- **Output Processing**: Parse jj command output for success/failure status and extract relevant information

### Menu Architecture
- **Menu System**: Floating window-based menu for command options using `vim.api.nvim_open_win()`
- **Menu Navigation**: Vim-style navigation (j/k, numbers) with immediate key selection support
- **Menu Rendering**: Dynamic menu generation based on command definitions and user customizations
- **Menu Context**: Pass cursor context (commit/change IDs) to menu options automatically

### Keybinding System
- **Dual-Level Keybindings**: Lowercase keys for quick actions, uppercase keys for advanced menus
- **Buffer-Local Registration**: Use `vim.api.nvim_buf_set_keymap()` for jj log buffer-specific keybindings
- **Configuration Integration**: Load custom keybindings from user configuration with validation
- **Mode Support**: Support for normal mode keybindings with potential future visual mode support
- **Conflict Prevention**: Ensure custom keybindings don't override essential navigation keys

### Context Detection
- **Cursor Position Analysis**: Parse current line to extract commit_id and change_id using existing parser utilities
- **Line Format Recognition**: Handle different log output formats (graph, compact, detailed)
- **Fallback Strategies**: Default to working copy (@) when cursor position is ambiguous
- **Validation**: Verify extracted IDs are valid before command execution

### User Feedback System
- **Status Messages**: Use `vim.notify()` or similar for command feedback with appropriate log levels
- **Progress Indicators**: Show command execution progress for longer-running operations
- **Output Display**: Present command output in appropriate format (popup, buffer, or status line)
- **Error Recovery**: Provide clear error messages with suggested actions when commands fail

## Approach Options

**Option A: Extend Existing Executor** (Selected)
- Pros: Leverages existing infrastructure, maintains consistency, easier integration
- Cons: May require refactoring existing code, potential coupling issues
- **Rationale**: Building on existing `log/executor.lua` ensures consistency and reduces duplication

**Option B: Create Separate Command System**
- Pros: Clean separation of concerns, independent development, no risk to existing functionality
- Cons: Code duplication, potential inconsistencies, more complex integration
- **Rejected**: Unnecessary complexity and duplication

**Option C: Configuration-Driven Command Files**
- Pros: Ultimate flexibility, commands defined in external files, easy sharing
- Cons: Complex configuration parsing, harder to debug, potential security issues
- **Rejected**: Over-engineering for initial implementation

## External Dependencies

- **Existing Components**
  - `log/executor.lua` - Foundation for command execution
  - `log/parser.lua` - For extracting commit/change IDs from cursor position
  - `config.lua` - For loading user-defined commands and keybindings
  - `ui/window.lua` - For integration with log display windows

- **Neovim APIs**
  - `vim.api.nvim_buf_set_keymap()` - Buffer-local keybinding registration
  - `vim.notify()` - User feedback and status messages
  - `vim.fn.input()` - User input prompting for parameterized commands
  - `vim.api.nvim_get_current_line()` - Cursor position and line content analysis

### Menu System Architecture
```lua
-- Menu rendering and interaction system
local function show_command_menu(command_name, context)
  local menu_def = default_commands[command_name].menu
  local menu_lines = {}
  
  -- Build menu content
  table.insert(menu_lines, menu_def.title)
  table.insert(menu_lines, string.rep("-", #menu_def.title))
  
  for _, option in ipairs(menu_def.options) do
    table.insert(menu_lines, string.format("%s) %s", option.key, option.desc))
  end
  
  -- Create floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, menu_lines)
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'cursor',
    width = 50,
    height = #menu_lines,
    row = 1,
    col = 0,
    style = 'minimal',
    border = 'rounded'
  })
  
  -- Set up menu keybindings
  setup_menu_keybindings(buf, menu_def.options, context)
end
```

## Implementation Details

### Command Definition Structure
```lua
-- Dual-level command definitions with quick actions and menus
local default_commands = {
  new = {
    quick_action = {
      cmd = "new",
      args = {},
      keymap = "n",
      description = "Create new commit on current change"
    },
    menu = {
      keymap = "N",
      title = "New Commit Options",
      options = {
        { key = "1", desc = "New commit (default)", cmd = "new", args = {} },
        { key = "2", desc = "New commit with message", cmd = "new", args = {"-m", "{user_input}"} },
        { key = "3", desc = "New commit after current", cmd = "new", args = {"{commit_id}"} }
      }
    }
  },
  rebase = {
    quick_action = {
      cmd = "rebase",
      args = {"-d", "{commit_id}"},
      keymap = "r",
      description = "Rebase current change onto selected commit",
      requires_target = true
    },
    menu = {
      keymap = "R",
      title = "Rebase Options",
      options = {
        { key = "1", desc = "Rebase onto commit", cmd = "rebase", args = {"-d", "{commit_id}"} },
        { key = "2", desc = "Rebase with conflicts", cmd = "rebase", args = {"-d", "{commit_id}", "--allow-conflicts"} },
        { key = "3", desc = "Rebase all descendants", cmd = "rebase", args = {"-d", "{commit_id}", "-s", "{change_id}"} }
      }
    }
  }
}
```

### Parameter Substitution System
```lua
-- Template processing for command arguments
local function substitute_parameters(args, context)
  local substituted = {}
  for _, arg in ipairs(args) do
    if arg == "{commit_id}" then
      table.insert(substituted, context.commit_id)
    elseif arg == "{change_id}" then
      table.insert(substituted, context.change_id)
    elseif arg == "{user_input}" then
      local input = vim.fn.input("Enter value: ")
      if input ~= "" then
        table.insert(substituted, input)
      end
    else
      table.insert(substituted, arg)
    end
  end
  return substituted
end
```

### Keybinding Registration
```lua
-- Register commands as buffer-local keymaps
local function register_command_keymaps(bufnr, commands)
  for name, command in pairs(commands) do
    if command.keymap then
      vim.api.nvim_buf_set_keymap(bufnr, 'n', command.keymap, 
        string.format('<cmd>lua require("jj.commands").execute("%s")<CR>', name),
        { noremap = true, silent = true, desc = command.description }
      )
    end
  end
end
```

### Context Detection Integration
```lua
-- Extract context from current cursor position
local function get_command_context()
  local line = vim.api.nvim_get_current_line()
  local parser = require("jj.log.parser")
  
  -- Parse line to extract commit and change IDs
  local commit_data = parser.parse_log_line(line)
  
  return {
    commit_id = commit_data and commit_data.commit_id or "@",
    change_id = commit_data and commit_data.change_id or "@",
    line_content = line
  }
end
```

## Integration Architecture

### Quick Action Flow
```
Lowercase Key → Command Registry → Context Detection → Parameter Substitution → 
Executor → jj Command → Output Processing → User Feedback → Log Refresh
```

### Menu Action Flow
```
Uppercase Key → Menu Display → User Selection → Command Registry → Context Detection → 
Parameter Substitution → Executor → jj Command → Output Processing → User Feedback → Log Refresh
```

### Configuration Integration
```
Plugin Init → Load Default Commands → Load User Config → Merge Commands → 
Register Quick Action Keybindings → Register Menu Keybindings → Setup Context Detection
```

### Error Handling Flow
```
Command Execution → Error Detection → Error Classification → User Notification → 
Recovery Suggestion → Log State Preservation
```

## Performance Considerations

- **Lazy Loading**: Load command definitions only when needed
- **Caching**: Cache parsed command configurations to avoid repeated processing
- **Async Execution**: Use Neovim job control for non-blocking command execution
- **Debouncing**: Prevent rapid repeated command execution

## Security Considerations

- **Command Validation**: Validate all user-defined commands to prevent shell injection
- **Parameter Sanitization**: Sanitize user input and extracted IDs before command execution
- **Command Whitelist**: Restrict command execution to jj operations only
- **Input Limits**: Limit parameter length and complexity to prevent abuse

## Testing Strategy

- **Unit Tests**: Command parsing, parameter substitution, context detection
- **Integration Tests**: Full command execution cycle, keybinding registration
- **Error Scenario Tests**: Invalid commands, missing context, jj failures
- **Configuration Tests**: User-defined commands, keybinding conflicts, validation
