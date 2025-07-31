# Tests Specification

This is the tests coverage details for the spec detailed in @.agent-os/specs/2025-07-31-fix-rebase-command-substitution/spec.md

> Created: 2025-07-31
> Version: 1.0.0

## Test Coverage

### Unit Tests

**Variable Substitution System**
- Test successful substitution of single variable `{target}` with commit ID
- Test substitution of multiple variables in one command
- Test handling of missing variables (should error gracefully)
- Test handling of malformed variable syntax
- Test escaping of special characters in commit IDs
- Test empty string handling

**Command Template Processing**
- Test commands with no variables (should pass through unchanged)
- Test commands with valid variables and available context
- Test commands with undefined variables
- Test nested or complex command structures

### Integration Tests

**Rebase Command Flow**
- Test complete rebase workflow from UI selection to command execution
- Test rebase with valid target commit ID
- Test rebase with invalid/non-existent target commit ID
- Test rebase error handling and user feedback
- Test UI state after successful rebase
- Test UI state after failed rebase

**Command Execution Framework**
- Test integration between variable substitution and existing command execution
- Test error propagation from substitution to UI
- Test command validation before execution

### Mocking Requirements

- **jj command execution:** Mock subprocess calls to jj to test command formation without actual repository changes
- **UI state:** Mock selected commit IDs and target commit selection
- **Error scenarios:** Mock various failure conditions for robust error handling testing