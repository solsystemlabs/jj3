# Tests Specification

This is the tests coverage details for the spec detailed in @.agent-os/specs/2025-07-29-command-menu-refinement/spec.md

> Created: 2025-07-29
> Version: 1.0.0

## Test Coverage

### Unit Tests

**NEW Command Testing**
- Test description prompting workflow for quick action
- Test multi-parent commit creation with multi-select
- Test --no-edit flag functionality  
- Test menu option execution with proper arguments

**REBASE Command Testing**
- Test menu-only workflow (no quick action)
- Test keybinding change from `R` to `r`
- Test all 4 rebase options (current, branch, insert-before, insert-after)
- Test proper argument substitution for rebase targets

**ABANDON Command Testing**
- Test multi-select workflow for multiple commit abandonment
- Test quick action behavior preservation
- Test confirmation prompts for all abandon operations
- Test --retain-bookmarks and --restore-descendants flags

**SQUASH Command Testing**
- Test floating terminal window creation and management
- Test interactive squash command execution
- Test auto-close functionality for terminal window
- Test cursor-based commit selection integration

**STATUS Command Testing**
- Test floating window display for 'jj st' output
- Test removal of menu configuration
- Test proper window cleanup and management
- Test output formatting in floating window

### Integration Tests

**Floating Terminal Window System**
- Test terminal window creation with proper positioning
- Test command execution within terminal environment
- Test auto-close based on command completion detection
- Test terminal session cleanup and resource management

**Multi-Select Workflow Integration**
- Test multi-commit selection and visual feedback
- Test multi-commit argument passing to jj commands
- Test validation of multi-select compatibility
- Test error handling for unsupported multi-select operations

**Enhanced User Input System**
- Test description prompting with validation
- Test input cancellation scenarios
- Test empty input handling
- Test integration with command execution pipeline

**Command Workflow Integration**
- Test complete workflows for each updated command
- Test keybinding registration and conflict detection
- Test menu display and option selection
- Test error conditions and user feedback

### Feature Tests

**Complete User Workflow Testing**
- Test NEW command: select → prompt → execute → verify
- Test REBASE command: select → menu → execute → verify  
- Test ABANDON command: multi-select → confirm → execute → verify
- Test SQUASH command: select → interactive → execute → verify
- Test STATUS command: execute → display → close → verify

**Cross-Command Consistency Testing**
- Test consistent behavior patterns across commands
- Test proper keybinding assignments without conflicts
- Test uniform error handling and user feedback
- Test integration with existing selection system

### Mocking Requirements

**jj Command Execution** - Mock subprocess calls for predictable testing of all command variants
**Floating Window APIs** - Mock vim.api window creation and management functions
**Terminal APIs** - Mock terminal creation and job control for interactive commands
**User Input APIs** - Mock vim.fn.input, vim.fn.confirm, and multi-select workflows
**File System Monitoring** - Mock repository state changes for auto-refresh testing