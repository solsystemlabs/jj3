# Tests Specification

This is the tests coverage details for the spec detailed in @.agent-os/specs/2025-07-28-commit-selection-workflow/spec.md

> Created: 2025-07-28
> Version: 1.0.0

## Test Coverage

### Unit Tests

**Selection State Management**
- Test transition from browse mode to selection mode
- Test state cleanup when selection is completed
- Test state cleanup when selection is cancelled
- Test buffer-local state isolation between multiple log buffers

**Command Queue Operations**
- Test command queuing with target requirements
- Test command execution with selected target
- Test command cancellation and queue cleanup

**Commit ID Extraction**
- Test extracting commit ID from cursor position in log buffer
- Test handling invalid cursor positions
- Test handling malformed log entries

### Integration Tests

**Selection Workflow**
- Test complete workflow: menu selection → navigation → commit selection → command execution
- Test cancellation at various stages of the workflow
- Test visual feedback during selection mode
- Test keybinding behavior changes in selection mode

**Command Integration**
- Test integration with existing "squash into selected" command
- Test integration with other target-requiring commands
- Test error handling when commands fail after target selection

**UI Integration**
- Test visual indicators appear and disappear correctly
- Test status line updates during selection mode
- Test highlight changes for selected commit

### Feature Tests

**End-to-End Selection Workflow**
- User selects "squash into selected" from menu
- Menu closes and log enters selection mode
- User navigates to target commit
- User confirms selection
- Squash command executes with correct target
- UI returns to normal browse mode

**Selection Cancellation Workflow**
- User selects command requiring target
- User presses Esc to cancel selection
- UI returns to normal browse mode without executing command
- No state leakage from cancelled selection

### Mocking Requirements

- **jj command execution:** Mock `vim.fn.jobstart()` calls to test command execution without actual jj operations
- **Buffer content:** Mock log buffer content for testing commit ID extraction
- **User input:** Mock keypress events for testing navigation and selection confirmation