# Spec Requirements Document

> Spec: Command Menu Refinement
> Created: 2025-07-29
> Status: Planning

## Overview

Define the exact behavior, menu contents, and keybinding configuration for each supported jj command in the plugin. This collaborative specification will establish the complete command set with user-validated menu options and consistent interaction patterns.

## User Stories

### Complete Command Specification
As a jj.nvim user, I want each command to have well-defined behavior and comprehensive menu options that cover the most useful variations of each operation.

### Consistent Command Interface
As a user, I want all commands to follow consistent patterns for quick actions (lowercase) and menu access (uppercase), with predictable argument handling and confirmation flows.

### Comprehensive Menu Coverage
As a power user, I want menu options that expose the most valuable jj flag combinations without requiring command-line usage for common operations.

## Command Specifications

### NEW Command (`n` / `N`)
**Status:** Defined
**Quick Action:** `n` - Create new commit based on commit under cursor, prompting user for description first, then execute with that description if provided
**Menu Options:** `N` - 
- Option 1: New commit with multiple parents (use multi select workflow)
- Option 2: New commit before selected commit
- Option 3: New commit after selected commit  
- Option 4: New commit without edit (--no-edit flag)

### REBASE Command (`r`)
**Status:** Defined
**Quick Action:** None - too complicated, menu only
**Menu Options:** `r` - 
- Option 1: Rebase current onto selected
- Option 2: Rebase branch onto selected
- Option 3: Rebase current onto selected, insert before
- Option 4: Rebase current onto selected, insert after

### ABANDON Command (`a` / `A`)
**Status:** Defined
**Quick Action:** `a` - Abandon selected commit with confirmation (current behavior)
**Menu Options:** `A` -
- Option 1: Abandon multiple (use multi select workflow)
- Option 2: Abandon but retain bookmarks
- Option 3: Abandon but keep descendants unchanged

### EDIT Command (`e` / `E`)
**Status:** Defined - keep current implementation
**Quick Action:** `e` - Edit selected change (current behavior)
**Menu Options:** `E` - No menu configuration, keep current behavior

### SQUASH Command (`s` / `S`)
**Status:** Defined
**Quick Action:** `s` - Squash selected commit into its parent with confirmation (current behavior)
**Menu Options:** `S` -
- Option 1: Squash current commit under cursor into selected
- Option 2: Squash from selected into selected
- Option 3: Squash interactively (floating terminal window that auto-closes when jj interactive command completes)

### DESCRIBE Command (`d`)
**Status:** Defined - keep current implementation
**Quick Action:** `d` - Edit description of current commit (current behavior)
**Menu Options:** None - no menu configuration

### STATUS Command (`?`)
**Status:** Defined
**Quick Action:** `?` - Run 'jj st' and display output in floating window
**Menu Options:** None - no menu configuration

## Out of Scope

- Adding completely new jj commands not listed above
- Changing the underlying command execution framework  
- Modifying the keybinding registration system architecture
- Creating new UI components or display modes

## Expected Deliverable

1. Complete specification for each command's quick action and menu options
2. Updated default_commands.lua with all refined command definitions
3. All commands tested and validated for proper execution
4. Documentation updated to reflect the final command set

## Spec Documentation

- Tasks: @.agent-os/specs/2025-07-29-command-menu-refinement/tasks.md
- Technical Specification: @.agent-os/specs/2025-07-29-command-menu-refinement/sub-specs/technical-spec.md
- Command Analysis: @.agent-os/specs/2025-07-29-command-menu-refinement/sub-specs/command-analysis.md
- Tests Specification: @.agent-os/specs/2025-07-29-command-menu-refinement/sub-specs/tests.md
