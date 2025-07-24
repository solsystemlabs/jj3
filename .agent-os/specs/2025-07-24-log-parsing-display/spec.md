# Spec Requirements Document

> Spec: jj Log Parsing and Rendering
> Created: 2025-07-24
> Status: Planning

## Overview

Implement core jj log parsing and rendering functionality that executes jj log commands, parses output into structured data, and renders the log graph with proper formatting and ANSI colors in a dedicated Neovim buffer using the default jj log format.

## User Stories

### Core Log Display

As a jujutsu user in Neovim, I want to see my repository's log graph displayed in a dedicated window, so that I can visualize the commit history and branching structure without leaving my editor.

The log should display with the same visual fidelity as the command line, including graph characters, colors, and commit information using jj's default log format.

### Repository Context Awareness

As a user, I want the plugin to detect when I'm not in a jj repository and show an appropriate message instead of attempting to display a log, so that I understand why the log isn't appearing.

## Spec Scope

1. **jj Log Execution and Parsing** - Execute jj log commands and parse output into structured commit objects with graph information
2. **Dual-Pass Log Processing** - First pass to get commit IDs and graph structure, second pass to get detailed commit information using default template
3. **Buffer Rendering Engine** - Render parsed log data with proper graph formatting, ANSI colors, and layout
4. **Repository Detection** - Detect jj repository context and display appropriate messages
5. **Window Management Integration** - Display log in configurable split window with proper buffer management

## Out of Scope

- Custom template support (separate future spec)
- Template input interface and management
- Auto-refresh functionality (deferred to command execution implementation)
- Commit selection and interaction (future feature)
- Performance optimization for large repositories
- Advanced error recovery and repository repair

## Expected Deliverable

1. `:JJ` command and `<leader>jl` keybinding display the parsed log in a split window with proper formatting
2. Log displays with same visual fidelity as command line including colors and graph characters using default jj format
3. Plugin detects non-jj directories and displays appropriate message instead of log
4. Buffer is properly managed (non-modifiable, reusable) with correct rendering of ANSI colors

## Spec Documentation

- Tasks: @.agent-os/specs/2025-07-24-log-parsing-display/tasks.md
- Technical Specification: @.agent-os/specs/2025-07-24-log-parsing-display/sub-specs/technical-spec.md
- Tests Specification: @.agent-os/specs/2025-07-24-log-parsing-display/sub-specs/tests.md