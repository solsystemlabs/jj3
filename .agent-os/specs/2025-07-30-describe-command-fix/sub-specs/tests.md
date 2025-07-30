# Tests Specification

This is the tests coverage details for the spec detailed in @.agent-os/specs/2025-07-30-describe-command-fix/spec.md

> Created: 2025-07-30
> Version: 1.0.0

## Test Coverage

### Unit Tests

**default_commands.lua**
- Test describe_current command definition has correct args with `-m` and `{user_input}`
- Test describe_current command definition maintains existing keymap and description
- Test command validation passes for updated describe command structure


### Integration Tests

**Describe Command Workflow**
- Test pressing `d` key triggers input prompt for commit message
- Test entering valid message executes `jj describe -m "<message>"` command
- Test canceling input prompt (empty input) skips command execution
- Test describe command execution triggers auto-refresh of log display
- Test describe command success shows appropriate feedback message
- Test describe command failure shows error message without hanging


### Mocking Requirements

- **jj command execution**: Mock `executor.execute_jj_command()` to simulate command success/failure without actual jj calls
- **User input**: Mock `vim.fn.input()` to simulate user providing commit messages or canceling
- **Auto-refresh system**: Mock auto-refresh hooks to verify they are triggered after command completion