# Spec Requirements Document

> Spec: Fix Rebase Command Substitution
> Created: 2025-07-31
> Status: Planning

## Overview

Fix the command variable substitution system to properly replace `{target}` with actual commit IDs when executing jj rebase operations. This bug prevents users from rebasing commits onto selected targets, causing the command to fail with a revset syntax error.

## User Stories

### Successful Rebase Operation

As a jj3 plugin user, I want to select a commit and rebase it onto another commit, so that I can reorganize my commit history without switching to the terminal.

When a user selects a commit in the log view and chooses the rebase option with a target commit, the plugin should properly substitute the `{target}` placeholder with the actual commit ID and execute `jj rebase -d <actual_commit_id>` successfully.

## Spec Scope

1. **Variable Substitution System** - Fix the command template system to properly replace placeholder variables like `{target}` with actual values
2. **Rebase Command Execution** - Ensure rebase operations work correctly with proper commit ID substitution
3. **Error Handling** - Improve error messages when command substitution fails or when invalid commit IDs are provided
4. **Command Validation** - Validate that required variables are available before executing commands

## Out of Scope

- Adding new rebase options or flags
- Implementing interactive rebase functionality
- Supporting complex revset expressions in rebase targets
- Adding rebase conflict resolution UI

## Expected Deliverable

1. Rebase command executes successfully with proper commit ID substitution instead of literal `{target}` text
2. Clear error messages when substitution variables are missing or invalid
3. All existing rebase functionality continues to work as expected

## Spec Documentation

- Tasks: @.agent-os/specs/2025-07-31-fix-rebase-command-substitution/tasks.md
- Technical Specification: @.agent-os/specs/2025-07-31-fix-rebase-command-substitution/sub-specs/technical-spec.md
- Tests Specification: @.agent-os/specs/2025-07-31-fix-rebase-command-substitution/sub-specs/tests.md