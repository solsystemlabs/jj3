# Tests Specification

This is the tests coverage details for the spec detailed in @.agent-os/specs/2025-07-25-basic-window-management/spec.md

> Created: 2025-07-25
> Version: 1.0.0

## Test Coverage

### Unit Tests

**ui.lua Module**
- `create_window()` function delegates correctly based on configuration type
- `create_float_window()` creates floating window with correct dimensions and options
- `create_split_window()` creates splits with correct sizing and direction
- `setup_buffer()` configures buffer with proper options (nomodifiable, buftype, etc.)
- `close_window()` properly cleans up window and buffer handles
- `toggle_window()` correctly opens closed windows and closes open windows
- `is_window_open()` accurately reports window state
- Configuration validation rejects invalid window types and dimensions

**config.lua Module**
- Window configuration merges user settings with sensible defaults
- Invalid configuration values are rejected with helpful error messages
- Configuration changes are properly applied to existing windows

### Integration Tests

**Window Creation Workflow**
- Complete window creation process from command execution to displayed window
- Window appears with correct content from existing log parsing module
- Multiple window type configurations (float, vsplit, hsplit) work correctly
- Window can be successfully closed and reopened without errors

**Configuration Integration**
- User configuration changes take effect on next window creation
- Default configuration provides working window without user customization
- Edge cases like very small or large dimensions are handled gracefully

### Mocking Requirements

- **Neovim API calls** - Mock `vim.api.nvim_open_win()`, `vim.api.nvim_create_buf()`, and related buffer/window functions for unit tests
- **Window dimensions** - Mock `vim.api.nvim_get_option()` for screen size calculations
- **Existing log content** - Mock log parsing module to provide test content for integration tests