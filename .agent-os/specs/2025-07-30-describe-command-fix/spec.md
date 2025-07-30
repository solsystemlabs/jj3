# Spec Requirements Document

> Spec: Describe Command Fix
> Created: 2025-07-30
> Status: Planning

## Overview

Fix the describe command to use quick describe mode (`jj describe -m <message>`) instead of opening an editor that causes Neovim to hang.

## User Stories

### Quick Describe Functionality

As a jj3 plugin user, I want to quickly update commit descriptions with a simple message prompt, so that I can efficiently edit commit messages without leaving Neovim or dealing with external editors.

When I press the describe keybinding (`d`), the plugin should prompt me for a commit message using Neovim's input function, then execute `jj describe -m "<my_message>"` to update the current commit's description directly.


## Spec Scope

1. **Quick Describe Implementation** - Replace editor-based describe with message prompt approach using `jj describe -m` flag

## Out of Scope

- Full editor integration for complex commit message editing
- Multi-line commit message support through external editors
- Advanced describe command options (templates, etc.)

## Expected Deliverable

1. Pressing `d` in jj3 prompts for message and executes `jj describe -m "<message>"` without hanging
2. All existing tests pass and new tests verify the describe command works correctly
3. Plugin remains responsive during and after describe command execution

## Spec Documentation

- Tasks: @.agent-os/specs/2025-07-30-describe-command-fix/tasks.md
- Technical Specification: @.agent-os/specs/2025-07-30-describe-command-fix/sub-specs/technical-spec.md
- Tests Specification: @.agent-os/specs/2025-07-30-describe-command-fix/sub-specs/tests.md