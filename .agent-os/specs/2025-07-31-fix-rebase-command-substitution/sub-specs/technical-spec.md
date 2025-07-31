# Technical Specification

This is the technical specification for the spec detailed in @.agent-os/specs/2025-07-31-fix-rebase-command-substitution/spec.md

> Created: 2025-07-31
> Version: 1.0.0

## Technical Requirements

- **Command Template Processing** - Implement a robust string substitution system that replaces placeholder variables (e.g., `{target}`, `{source}`) with actual commit IDs before command execution
- **Context-Aware Variable Resolution** - Ensure the system can access the currently selected commit ID and any target commit ID from the UI state
- **Error Handling** - Validate that all required variables are available and properly formatted before attempting command execution
- **Backwards Compatibility** - Maintain compatibility with existing command configurations that don't use variable substitution
- **Lua String Pattern Matching** - Use Lua's string.gsub() or similar pattern matching for reliable variable substitution

## Approach Options

**Option A: Simple String Replacement**
- Pros: Easy to implement, minimal code changes, fast execution
- Cons: Limited flexibility, no validation of variable availability, potential security issues with unescaped substitution

**Option B: Template Engine with Validation** (Selected)
- Pros: Robust variable validation, better error messages, extensible for future variables, secure substitution
- Cons: More complex implementation, requires additional error handling logic

**Rationale:** Option B provides the reliability and user experience needed for a production plugin. The variable validation prevents confusing error messages like the current revset syntax error, and the extensible design supports future command customization features mentioned in the roadmap.

## External Dependencies

This fix requires no new external dependencies - it will use:
- **Lua built-in string functions** - For pattern matching and substitution (string.gsub, string.match)
- **Existing Neovim APIs** - For accessing UI state and displaying error messages
- **Existing jj command execution framework** - The substitution happens before passing commands to the existing execution system