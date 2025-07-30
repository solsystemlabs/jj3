# Tests Specification

This is the tests coverage details for the spec detailed in @.agent-os/specs/2025-07-30-log-window-positioning/spec.md

> Created: 2025-07-30
> Version: 1.0.0

## Test Coverage

### Unit Tests

**ui.lua (Window Management)**
- Test window position calculation with various screen widths
- Test positioning logic with different vim.o.columns values
- Test edge case handling when calculated position exceeds screen bounds
- Test window size preservation during positioning changes
- Test floating window positioning logic
- Test vertical split positioning logic

**config.lua (Configuration)**
- Test default window type configuration (floating)
- Test user configuration override for window type
- Test invalid configuration value handling

### Integration Tests

**Log Window Opening (Floating Mode)**
- Test floating log window opens at correct position from single window state
- Test floating log window opens at correct position with existing horizontal splits
- Test floating log window opens at correct position with existing vertical splits
- Test floating log window opens at correct position with mixed split configurations
- Test floating log window positioning is consistent regardless of current focused window

**Log Window Opening (Split Mode)**
- Test split log window opens at correct position from single window state
- Test split log window opens at correct position with existing splits
- Test split log window positioning is consistent regardless of current focused window

**Configuration Behavior**
- Test window opens in floating mode by default
- Test window opens in split mode when configured
- Test configuration changes take effect on next window open

**Window Focus and Navigation**
- Test log window maintains correct position after focus changes in both modes
- Test log window positioning after closing and reopening in both modes
- Test interaction with existing window management commands

### Mocking Requirements

- **vim.o.columns:** Mock different screen width scenarios (narrow, wide, ultrawide)
- **vim.api.nvim_list_wins():** Mock various window layout configurations
- **vim.api.nvim_open_win():** Verify correct positioning parameters are passed for floating windows
- **vim.cmd('vsplit'):** Verify split command execution for split mode
- **Configuration system:** Mock different user configuration values