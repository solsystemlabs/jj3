# Spec Tasks

These are the tasks to be completed for the spec detailed in @.agent-os/specs/2025-07-28-command-execution-framework/spec.md

> Created: 2025-07-28
> Status: Ready for Implementation

## Tasks

- [x] 1. Implement core command execution engine
  - [x] 1.1 Write tests for generic command execution with parameter substitution
  - [x] 1.2 Create `command_execution.lua` module with command registry and execution functions
  - [x] 1.3 Implement parameter substitution system supporting `{commit_id}`, `{change_id}`, and `{user_input}`
  - [x] 1.4 Add command validation and error handling with user-friendly messages
  - [x] 1.5 Integrate with existing `log/executor.lua` for jj command execution
  - [x] 1.6 Verify all command execution tests pass

- [x] 2. Build menu architecture system
  - [x] 2.1 Write tests for menu rendering, navigation, and option selection
  - [x] 2.2 Create `menu.lua` module using Neovim's built-in vim.ui.select
  - [x] 2.3 Implement menu option generation and formatting with native navigation
  - [x] 2.4 Add menu context integration to pass commit/change IDs to menu options
  - [x] 2.5 Integrate with command execution framework for menu option execution
  - [x] 2.6 Verify all menu system tests pass

- [x] 3. Implement dual-level keybinding system
  - [x] 3.1 Write tests for quick action and menu keybinding registration
  - [x] 3.2 Create keybinding registry system to support dual-level commands
  - [x] 3.3 Implement buffer-local registration for both lowercase (quick) and uppercase (menu) keys
  - [x] 3.4 Add keybinding conflict detection and user override capabilities
  - [x] 3.5 Integrate keybinding system with command registry and menu architecture
  - [x] 3.6 Verify all keybinding system tests pass

- [x] 4. Create default command set with menus
  - [x] 4.1 Write tests for all default commands and their menu options
  - [x] 4.2 Define default quick actions for common operations (n, r, a, e, s)
  - [x] 4.3 Create menu definitions for advanced options (N, R, A, E, S)
  - [x] 4.4 Implement context-aware parameter passing for all commands
  - [x] 4.5 Add confirmation prompts for destructive operations (abandon, squash)
  - [x] 4.6 Verify all default command tests pass

- [x] 5. Build user customization framework
  - [x] 5.1 Write tests for configuration loading and user command/menu definitions
  - [x] 5.2 Extend configuration system to support user-defined commands and menus
  - [x] 5.3 Implement user command/menu validation and conflict resolution
  - [x] 5.4 Add configuration merging system for user and default definitions
  - [x] 5.5 Create examples and documentation for user customization
  - [x] 5.6 Verify all customization framework tests pass

- [ ] 6. Integrate with existing plugin architecture
  - [ ] 6.1 Write integration tests for command system with log display and navigation
  - [ ] 6.2 Integrate command framework with existing window management system
  - [ ] 6.3 Connect command execution with auto-refresh system for repository updates
  - [ ] 6.4 Add command framework initialization to main plugin setup
  - [ ] 6.5 Ensure command system works with all window configurations (split, floating)
  - [ ] 6.6 Verify complete integration tests pass and all existing functionality remains intact