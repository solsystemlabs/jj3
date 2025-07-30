# Technical Specification

This is the technical specification for the spec detailed in @.agent-os/specs/2025-07-30-describe-command-fix/spec.md

> Created: 2025-07-30
> Version: 1.0.0

## Technical Requirements

- **Quick Describe Command**: Update `describe_current` in `default_commands.lua` to use `-m` flag with user input instead of empty args
- **Backward Compatibility**: Maintain existing keymap (`d`) and command structure

## Approach Options

**Option A:** Simple message prompt with vim.fn.input() (Selected)
- Pros: Simple implementation, consistent with existing patterns, immediate user feedback
- Cons: Limited to single-line messages, no syntax highlighting for commit messages

**Option B:** Neovim buffer-based message editing
- Pros: Multi-line support, syntax highlighting, full editing capabilities  
- Cons: Complex implementation, inconsistent with other quick commands, more development time

**Option C:** External editor integration with proper async handling
- Pros: Full editor functionality, matches jj CLI behavior
- Cons: Complex async handling, potential for hanging issues, requires external process management

**Rationale:** Option A provides the quickest fix for the hanging issue while maintaining the "quick action" philosophy of the existing command system. It aligns with other commands that use `vim.fn.input()` for user input and provides immediate value without complex implementation.

## External Dependencies

No new external dependencies required. The fix uses existing functionality:
- **vim.fn.input()** - Built-in Neovim function for user input prompts
- **string escaping utilities** - Standard Lua string handling for command safety