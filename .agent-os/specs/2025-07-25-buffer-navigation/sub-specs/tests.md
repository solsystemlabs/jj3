# Tests Specification

This is the tests coverage details for the spec detailed in @.agent-os/specs/2025-07-25-buffer-navigation/spec.md

> Created: 2025-07-25
> Version: 1.0.0

## Test Coverage

### Unit Tests

**Navigation Module**
- `setup_navigation_keymaps()` registers all expected keymaps for given buffer
- `cursor_down()` moves cursor to next line and handles buffer end boundary
- `cursor_up()` moves cursor to previous line and handles buffer start boundary  
- `goto_first_line()` positions cursor at first line of buffer
- `goto_last_line()` positions cursor at last line of buffer
- `half_page_down()` / `half_page_up()` move cursor by half window height
- Navigation functions respect buffer boundaries and don't cause errors
- Keymaps are only registered for jj log buffers, not other buffers

**Window Integration**
- Navigation keymaps are automatically set up when jj log buffer is created
- Keymaps are properly cleaned up when buffer is closed or destroyed
- Navigation works correctly with different window configurations (floating, split)
- Visual feedback (cursor line highlighting) is enabled in navigation-enabled buffers

### Integration Tests

**Complete Navigation Workflow**
- User can open jj log window and immediately use navigation keys
- All basic movement keys (j/k/gg/G) work as expected in log buffer
- Extended movement keys (h/l/Ctrl-d/Ctrl-u) provide appropriate scrolling behavior
- Navigation keys have no effect when focus is outside jj log buffer
- Multiple jj log windows can have independent navigation state

**Buffer State Management**
- Cursor position is maintained when switching between jj log window and other windows
- Navigation state is preserved when window is resized or repositioned
- Buffer content updates (log refresh) don't interfere with navigation functionality

### Mocking Requirements

- **Cursor Position APIs** - Mock `vim.api.nvim_win_set_cursor()` and `vim.api.nvim_win_get_cursor()` for cursor movement testing
- **Keymap Registration** - Mock `vim.api.nvim_buf_set_keymap()` to verify correct keymap registration
- **Window Dimensions** - Mock `vim.api.nvim_win_get_height()` for page-based movement calculations
- **Buffer Content** - Mock buffer with sample jj log content for realistic navigation testing