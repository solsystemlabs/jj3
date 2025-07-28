# Tests Specification

This is the tests coverage details for the spec detailed in @.agent-os/specs/2025-07-28-command-execution-framework/spec.md

> Created: 2025-07-28
> Version: 1.0.0

## Test Coverage

### Unit Tests - Command Engine

**Command Registry**
- `register_command()` properly stores command definitions with validation
- `get_command()` retrieves commands by name with proper fallback to defaults
- `merge_user_commands()` combines user and default commands with conflict resolution
- Command validation rejects malformed or unsafe command definitions
- Parameter template validation ensures only supported placeholders are used

**Parameter Substitution**
- `substitute_parameters()` correctly replaces `{commit_id}` with cursor context
- `substitute_parameters()` correctly replaces `{change_id}` with cursor context  
- `substitute_parameters()` handles `{user_input}` with proper input prompting
- Parameter substitution handles missing context gracefully with fallback values
- Complex parameter combinations work correctly in single command
- Empty or invalid parameters are handled without command execution

### Unit Tests - Context Detection

**Cursor Position Analysis**
- `get_command_context()` extracts correct commit_id from standard log line format
- `get_command_context()` extracts correct change_id from standard log line format
- Context detection works with graph output format (├─, └─ characters)
- Context detection works with compact output format
- Context detection handles working copy (@) lines correctly
- Context detection falls back to "@" when cursor is on invalid line

**Line Parsing Integration**
- Context detection integrates properly with existing log parser
- Context detection preserves navigation state during command execution
- Context detection works correctly with highlighted/selected lines
- Context detection handles multi-line commit descriptions appropriately

### Unit Tests - Menu System

**Menu Rendering**
- `show_command_menu()` creates floating window with correct dimensions and positioning
- Menu content displays command options with proper formatting and numbering
- Menu window styling (border, colors) matches plugin design standards
- Menu closes properly when user cancels or selects invalid option
- Multiple menus can be handled correctly (close previous when opening new)

**Menu Navigation**
- Number key selection executes corresponding menu option correctly
- j/k navigation moves cursor through menu options appropriately
- Enter key executes currently highlighted menu option
- Escape key closes menu without executing any command
- Menu keybindings don't interfere with underlying buffer navigation

**Menu Context Integration**
- Menu options receive correct commit/change IDs from cursor context
- Parameter substitution works correctly within menu-triggered commands
- Menu execution preserves cursor position and context after command completion

### Unit Tests - Keybinding System

**Dual-Level Keybinding Registration**
- `register_command_keymaps()` creates buffer-local keymaps for both quick actions and menus
- Lowercase keybindings execute quick actions immediately
- Uppercase keybindings open corresponding command menus
- Keybinding registration only affects jj log buffers, not other buffers
- User-defined keybindings properly override default keybindings
- Keybinding conflicts are detected and resolved appropriately
- Keybinding descriptions are set correctly for help integration
- Invalid keybinding definitions are rejected with clear error messages

### Integration Tests - Command Execution

**Complete Command Flow**
- User can execute default commands using keybindings in log buffer
- Commands automatically receive appropriate commit/change IDs from cursor position
- Command execution provides clear feedback on success and failure
- Command execution triggers log refresh when repository state changes
- Multiple rapid command executions are handled gracefully
- Command execution integrates properly with existing auto-refresh system

**Default Quick Actions**
- 'n' key creates new commit on current change using `jj new`
- 'r' key allows rebasing onto selected commit using `jj rebase -d {commit_id}`
- 'a' key abandons selected change using `jj abandon {change_id}` with confirmation
- 'e' key edits selected change using `jj edit {change_id}`
- 's' key squashes into selected commit using `jj squash --into {commit_id}`
- All default commands work with both commit_id and change_id contexts

**Default Menu Actions**
- 'N' key opens new commit menu with options for different creation modes
- 'R' key opens rebase menu with options for different rebase strategies
- 'A' key opens abandon menu with options for different abandon behaviors
- 'E' key opens edit menu with options for different edit workflows
- 'S' key opens squash menu with options for different squash strategies
- All menu options execute correctly with proper parameter substitution

### Integration Tests - Configuration

**User Configuration Loading**
- Plugin loads user-defined commands and menus from configuration correctly
- User commands can override default command keybindings and behavior
- User menu definitions can override default menu options and add new ones
- Invalid user configuration is handled gracefully with error messages
- Configuration changes take effect without requiring plugin restart
- User commands support all parameter substitution features
- Complex user command definitions work correctly with multi-argument commands
- User menu customizations integrate properly with existing menu architecture

### Integration Tests - Error Handling

**Command Execution Errors**
- jj command failures are captured and displayed with appropriate error messages
- Network errors during jj operations are handled gracefully
- Repository state conflicts are detected and reported clearly
- Invalid commit/change IDs result in clear error messages rather than cryptic jj output
- User is provided with recovery suggestions when commands fail
- Plugin state remains stable after command execution errors

**Context Detection Errors**
- Invalid cursor positions don't cause command execution failures  
- Commands requiring specific context fail gracefully when context unavailable
- Ambiguous line formats result in safe fallback behavior
- Commands work correctly when repository is in detached/conflict state

### Mocking Requirements

**Command Execution**
- Mock jj command execution for testing command parameter construction
- Mock command success/failure scenarios for error handling testing
- Mock user input prompting for parameterized command testing
- Mock repository state changes for refresh integration testing

**Neovim APIs**
- Mock `vim.api.nvim_buf_set_keymap()` for keybinding registration testing
- Mock `vim.api.nvim_open_win()` for menu window creation testing
- Mock `vim.api.nvim_create_buf()` for menu buffer creation testing
- Mock `vim.notify()` for user feedback testing
- Mock `vim.fn.input()` for user input prompting in parameterized commands
- Mock cursor position and line content APIs for context detection testing

**Configuration System**
- Mock user configuration loading for testing custom command and menu definitions
- Mock configuration validation for testing error handling
- Mock configuration merging for testing user/default command and menu integration
- Mock menu option validation for testing custom menu definitions

### Performance Tests

**Command Execution Speed**
- Command registration completes within 100ms during plugin initialization
- Context detection completes within 50ms for cursor position analysis
- Parameter substitution completes within 10ms for typical command arguments
- Keybinding response time is under 100ms from keypress to command execution

**Memory Usage**
- Command registry memory usage scales linearly with number of defined commands
- No memory leaks during repeated command execution cycles
- Context detection doesn't accumulate memory during extended usage sessions

### Edge Case Tests

**Repository States**
- Commands work correctly in empty repositories
- Commands handle repository conflicts and invalid states gracefully
- Commands work when repository is in intermediate state (rebase, merge)
- Commands handle very large repositories without performance degradation

**User Input Edge Cases**
- Commands handle very long commit messages and descriptions
- Commands work with unusual characters in commit/change IDs
- Commands handle rapid user input and keyboard interactions
- Commands work correctly when multiple log windows are open simultaneously

### Success Metrics

**Functionality Metrics**
- 100% of default commands execute successfully in normal repository conditions
- User-defined commands work correctly in 95% of valid configuration scenarios
- Context detection accuracy >98% for standard log output formats
- Error handling provides actionable feedback in 90% of failure scenarios

**Performance Metrics**  
- Command execution latency <200ms for typical jj operations
- Plugin initialization with command framework adds <50ms to startup time
- Memory usage for command framework <5MB during typical usage sessions
- No measurable impact on log display rendering performance