# Spec Requirements Document

> Spec: Log Window Positioning
> Created: 2025-07-30
> Status: Planning

## Overview

Fix the log window positioning to appear at the right edge of the entire Neovim window instead of relative to the currently focused window. This improvement will provide consistent window placement regardless of which window has focus when the log is opened.

## User Stories

### Consistent Log Window Placement

As a jj3 plugin user, I want the log window to always appear at the right edge of my entire Neovim interface, so that I have predictable window placement regardless of my current window focus or split configuration.

When opening the log window, it should consistently position itself at the rightmost edge of the Neovim interface, creating a dedicated sidebar-style view of the jj log that doesn't interfere with the existing window layout or depend on which window currently has focus.

## Spec Scope

1. **Window Positioning Logic** - Modify window creation to position relative to the entire Neovim interface
2. **Configurable Window Type** - Support both floating window and vertical split modes with user configuration
3. **Default Floating Behavior** - Set floating window as the default positioning mode
4. **Edge Case Handling** - Handle scenarios with multiple splits, floating windows, and different window configurations
5. **Consistent Behavior** - Ensure the same positioning behavior regardless of current focus state

## Out of Scope

- Changes to window resizing behavior
- Modifications to log content display or parsing  
- Updates to keybinding or command execution functionality
- Advanced positioning options beyond floating/split choice

## Expected Deliverable

1. Log window consistently appears at the right edge of the entire Neovim window in both floating and split modes
2. User configuration option to choose between floating window (default) and vertical split positioning
3. Window positioning works correctly with various split configurations and focus states
4. No regression in existing log display or navigation functionality

## Spec Documentation

- Tasks: @.agent-os/specs/2025-07-30-log-window-positioning/tasks.md
- Technical Specification: @.agent-os/specs/2025-07-30-log-window-positioning/sub-specs/technical-spec.md
- Tests Specification: @.agent-os/specs/2025-07-30-log-window-positioning/sub-specs/tests.md