# Spec Requirements Document

> Spec: Log Window Toggle Improvements
> Created: 2025-07-30
> Status: Planning

## Overview

Improve the log window toggle functionality to make `<leader>jl` (or configured keybinding) work as a true toggle between open and closed states, while ensuring ESC key closes the window when the log buffer is focused. This enhancement will provide a more intuitive user experience for window management within the jj3 plugin.

## User Stories

### Improved Window Toggle Experience

As a Neovim user with jj3, I want to use the same keybinding to both open and close the log window, so that I can quickly toggle the log view without needing to remember separate keybindings for opening and closing.

The user presses `<leader>jl` (or their configured toggle keybinding) and if the log window is closed, it opens. If the log window is already open, it closes. This provides a consistent toggle behavior that matches user expectations from other Neovim plugins.

### Consistent ESC Key Behavior

As a Neovim user with jj3, I want the ESC key to close the log window when I'm focused in the log buffer, so that I can quickly dismiss the window using standard Vim navigation patterns.

When the cursor is in the log buffer, pressing ESC closes the log window, providing an intuitive escape mechanism that aligns with Vim's modal editing philosophy.

## Spec Scope

1. **True Toggle Functionality** - Modify the keybinding handler to check window state and toggle accordingly
2. **ESC Key Integration** - Ensure ESC key consistently closes the log window when log buffer is focused
3. **Configuration Preservation** - Maintain existing user configuration options for the toggle keybinding

## Out of Scope

- Changing the default keybinding from `<leader>jl`
- Adding new configuration options for ESC key behavior
- Modifying window positioning or sizing behavior
- Adding toggle functionality for other windows or UI components

## Expected Deliverable

1. The configured toggle keybinding (default `<leader>jl`) opens the log window when closed and closes it when open
2. ESC key closes the log window when the log buffer is focused, maintaining existing behavior
3. All existing functionality and keybindings continue to work without regression

## Spec Documentation

- Tasks: @.agent-os/specs/2025-07-30-log-window-toggle-improvements/tasks.md
- Technical Specification: @.agent-os/specs/2025-07-30-log-window-toggle-improvements/sub-specs/technical-spec.md
- Tests Specification: @.agent-os/specs/2025-07-30-log-window-toggle-improvements/sub-specs/tests.md