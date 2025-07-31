# Tests Specification

This is the tests coverage details for the spec detailed in @.agent-os/specs/2025-07-31-interactive-terminal-commands/spec.md

> Created: 2025-07-31
> Version: 1.0.0

## Test Coverage

### Unit Tests

**Interactive Command Detection**
- Test `is_interactive_command()` correctly identifies always-interactive commands (`split`, `resolve`, `diffedit`)
- Test conditional logic for `describe` command with various flag combinations (`-m`, `--message`, `--stdin`, `--no-edit`)
- Test conditional logic for `squash` command with interactive flags (`-i`, `--interactive`)
- Test false positives - commands that should not be detected as interactive

**Terminal Window Management** 
- Test floating window creation with proper dimensions and positioning
- Test window cleanup when process exits normally
- Test window cleanup when process is terminated
- Test buffer creation and terminal initialization
- Test window focus management and restoration

**Process Lifecycle**
- Test job creation and monitoring for interactive commands
- Test exit code handling for successful and failed commands  
- Test callback execution on process completion
- Test environment variable preservation (`$EDITOR`, `$VISUAL`, etc.)

### Integration Tests

**Command Execution Flow**
- Test full workflow: command detection → terminal creation → process execution → cleanup → log refresh
- Test integration with existing command execution framework
- Test fallback to standard execution for non-interactive commands
- Test error handling when terminal creation fails

**Editor Integration**
- Test `jj describe` opens configured editor in terminal
- Test `jj split` with diff editor functionality
- Test `jj resolve` with merge tool integration
- Test editor environment receives proper working directory and environment variables

**Log Refresh Integration**
- Test log view refreshes after interactive command completion
- Test appropriate success/error messages are displayed
- Test repository state changes are reflected in UI
- Test concurrent command handling (if interactive command is running, other commands wait or fail gracefully)

### Mocking Requirements

- **Terminal API Mocking** - Mock `vim.api.nvim_open_term()` and `vim.fn.termopen()` for unit tests without spawning real processes
- **Job Control Mocking** - Mock job lifecycle events (`on_exit` callbacks) to test completion handling
- **Editor Environment** - Mock `$EDITOR` and tool configurations to test various editor scenarios
- **Window API Mocking** - Mock window creation and management APIs to test UI behavior without creating actual windows

### Manual Testing Scenarios

1. **Basic Interactive Commands**
   - Run `jj describe` without `-m` flag, verify editor opens in floating terminal
   - Edit commit message and save, verify terminal closes and log refreshes
   - Run `jj split`, interact with diff editor, verify changes apply correctly

2. **Error Conditions**
   - Run interactive command when jj is not available
   - Run command in non-jj repository
   - Cancel/abort interactive process (Ctrl-C), verify graceful cleanup

3. **Editor Configuration**
   - Test with different `$EDITOR` values (vim, nano, code --wait)
   - Test with jj-configured editors
   - Test with tools that require special handling

4. **Window Management**
   - Test terminal window resizing behavior
   - Test focus management when switching between windows
   - Test behavior with different Neovim window layouts