# Spec Requirements Document

> Spec: Interactive Terminal Commands
> Created: 2025-07-31
> Status: Planning

## Overview

Implement a floating terminal window system for jj commands that require interactive user input, allowing users to complete interactive workflows without leaving Neovim while maintaining full terminal functionality and automatically refreshing the log view upon completion.

## User Stories

### Interactive Command Execution

As a jj user in Neovim, I want to execute interactive jj commands (like `jj describe`, `jj split`, `jj resolve`) so that I can complete complex workflows without switching to an external terminal.

When I trigger an interactive command from the jj3 plugin, a floating terminal window opens with the command running. I can interact with editors, diff tools, and prompts normally. When I complete the interaction and the command finishes, the floating terminal closes automatically, the log view refreshes to show my changes, and I see any success/error messages from the command.

### Seamless Editor Integration

As a power user, I want interactive commands to respect my configured editors and tools so that my existing jj workflow remains consistent within Neovim.

When jj opens an editor for commit messages or diff editing, it should use my configured `$EDITOR` or jj's configured editor, and the editing experience should be identical to running the command in a standalone terminal.

## Spec Scope

1. **Floating Terminal Management** - Create and manage floating terminal windows for interactive jj commands with proper sizing and positioning
2. **Interactive Command Detection** - Identify which jj commands require interactive input and handle them appropriately  
3. **Process Lifecycle Management** - Monitor command execution, detect completion, and handle cleanup automatically
4. **Editor Integration** - Ensure interactive editors and tools work seamlessly within the floating terminal environment
5. **Auto-refresh Integration** - Refresh the log view and display appropriate feedback when interactive commands complete

## Out of Scope

- Custom editor implementations (use existing configured editors)
- Interactive command customization beyond standard jj functionality
- Multi-step interactive workflows that span multiple commands
- Integration with non-jj interactive commands

## Expected Deliverable

1. Interactive jj commands open in floating terminal windows that close automatically upon completion
2. Log view refreshes automatically after interactive command completion with updated repository state
3. Success/error messages are displayed appropriately after command completion

## Spec Documentation

- Tasks: @.agent-os/specs/2025-07-31-interactive-terminal-commands/tasks.md
- Technical Specification: @.agent-os/specs/2025-07-31-interactive-terminal-commands/sub-specs/technical-spec.md
- Tests Specification: @.agent-os/specs/2025-07-31-interactive-terminal-commands/sub-specs/tests.md