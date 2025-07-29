# Command Analysis and Refinement Plan

This document analyzes the current command implementations and proposes specific refinements for each command in the jj.nvim plugin.

> Created: 2025-07-29
> Version: 1.0.0

## Current Command Inventory

Based on the code analysis, the plugin currently supports these commands:

### Fully Implemented Commands
1. **new** - Create new commits with various options
2. **rebase** - Rebase operations with destination options  
3. **abandon** - Abandon changes with retention options
4. **edit** - Edit selected changes (minimal implementation)
5. **squash** - Squash commits with directional options
6. **describe_current** - Edit current commit description (minimal implementation)
7. **status** - Show repository status (minimal implementation)

## Command-by-Command Analysis

### 1. NEW Command

**Current State:** Well-implemented with comprehensive menu options
- Quick action: `n` - Create new commit after selected change
- Menu: `N` - 3 options (with message, before selected, after selected)

**Proposed Refinements:**
- Add option for creating empty commit (`--no-edit`)
- Add option for creating commit with specific author
- Add option for inserting at root (`--insert-before root()`)

**New Menu Options:**
```lua
{
  key = "4",
  desc = "New empty commit", 
  cmd = "new",
  args = { "--no-edit", "{target}" }
},
{
  key = "5",
  desc = "New commit at root",
  cmd = "new", 
  args = { "--insert-before", "root()" }
}
```

### 2. REBASE Command

**Current State:** Good foundation with 3 menu options
- Quick action: `r` - Rebase current change onto selected
- Menu: `R` - 3 options (current onto selected, branch onto selected, with descendants)

**Proposed Refinements:**
- Add interactive rebase option
- Add option to skip empty commits
- Add option to rebase with conflict resolution strategy

**New Menu Options:**
```lua
{
  key = "4",
  desc = "Interactive rebase",
  cmd = "rebase",
  args = { "-d", "{target}", "--interactive" }
},
{
  key = "5", 
  desc = "Rebase skipping empty",
  cmd = "rebase",
  args = { "-d", "{target}", "--skip-empty" }
}
```

### 3. ABANDON Command

**Current State:** Well-implemented with safety features
- Quick action: `a` - Abandon selected change (with confirmation)
- Menu: `A` - 3 options (abandon, retain bookmarks, restore descendants)

**Proposed Refinements:**
- Add option to abandon multiple revisions
- Add option to abandon with summary message
- Consider adding dry-run option

**Status:** Minimal changes needed - current implementation is comprehensive

### 4. EDIT Command

**Current State:** Minimal implementation - only quick action
- Quick action: `e` - Edit selected change
- Menu: Missing

**Proposed Refinements:**
- Add comprehensive menu with edit options
- Add option to edit with specific tool
- Add option to edit message only

**New Menu Implementation:**
```lua
menu = {
  keymap = "E",
  title = "Edit Options", 
  options = {
    {
      key = "1",
      desc = "Edit selected commit",
      cmd = "edit",
      args = { "{target}" }
    },
    {
      key = "2", 
      desc = "Edit commit message only",
      cmd = "describe",
      args = { "{target}" }
    },
    {
      key = "3",
      desc = "Edit with external tool",
      cmd = "edit",
      args = { "{target}", "--tool", "{user_input}" }
    }
  }
}
```

### 5. SQUASH Command

**Current State:** Good directional options
- Quick action: `s` - Squash selected into parent (with confirmation)  
- Menu: `S` - 3 options (into parent, from working copy, into working copy)

**Proposed Refinements:**
- Add option to squash with message editing
- Add option to squash interactive mode
- Clarify descriptions for better understanding

**Updated Menu Options:**
```lua
{
  key = "1",
  desc = "Squash into parent (keep parent message)",
  cmd = "squash",
  args = { "-r", "{target}" },
  confirm = true
},
{
  key = "4",
  desc = "Squash into parent (edit message)",
  cmd = "squash", 
  args = { "-r", "{target}", "--interactive" },
  confirm = true
}
```

### 6. DESCRIBE_CURRENT Command

**Current State:** Minimal implementation
- Quick action: `d` - Edit current commit description
- Menu: `D` - Single option (redundant with quick action)

**Proposed Refinements:**
- Rename to just "describe" for consistency
- Add options for describing other commits
- Add template options

**Enhanced Implementation:**
```lua
describe = {
  quick_action = {
    cmd = "describe",
    args = { "{target}" },
    keymap = "d",
    description = "Edit description of selected commit",
    phases = {
      { key = "target", prompt = "Select commit to describe" }
    }
  },
  menu = {
    keymap = "D",
    title = "Describe Options",
    options = {
      {
        key = "1",
        desc = "Edit commit description",
        cmd = "describe", 
        args = { "{target}" }
      },
      {
        key = "2",
        desc = "Edit current working copy",
        cmd = "describe",
        args = {}
      },
      {
        key = "3",
        desc = "Set description from template",
        cmd = "describe",
        args = { "{target}", "-m", "{user_input}" }
      }
    }
  }
}
```

### 7. STATUS Command

**Current State:** Minimal implementation
- Quick action: `?` - Show repository status
- Menu: `?` - Single redundant option

**Proposed Refinements:**
- Add comprehensive status options
- Add conflict and bookmark status views
- Add path-specific status options

**Enhanced Menu:**
```lua
{
  key = "1",
  desc = "Show repository status",
  cmd = "status",
  args = {}
},
{
  key = "2", 
  desc = "Show status with conflicts",
  cmd = "status",
  args = { "--conflicts" }
},
{
  key = "3",
  desc = "Show detailed status",
  cmd = "status", 
  args = { "--detailed" }
},
{
  key = "4",
  desc = "Show status for path",
  cmd = "status",
  args = { "{user_input}" }
}
```

## Missing Commands to Consider

Based on common jj workflows, consider adding these commands:

### 1. SPLIT Command
```lua
split = {
  quick_action = {
    cmd = "split",
    args = { "{target}" },
    keymap = "p", 
    description = "Split selected commit interactively"
  }
}
```

### 2. DUPLICATE Command  
```lua
duplicate = {
  quick_action = {
    cmd = "duplicate", 
    args = { "{target}" },
    keymap = "u",
    description = "Duplicate selected commit"
  }
}
```

### 3. BOOKMARK Commands
```lua
bookmark_create = {
  quick_action = {
    cmd = "bookmark",
    args = { "create", "{user_input}", "-r", "{target}" },
    keymap = "b",
    description = "Create bookmark on selected commit"
  }
}
```

## Keybinding Consistency Review

**Current Assignments:**
- `n/N` - new
- `r/R` - rebase  
- `a/A` - abandon
- `e/E` - edit (E needs menu implementation)
- `s/S` - squash
- `d/D` - describe
- `?` - status

**Available Letters:** 
- `c/C` - could be "commit" or "change"
- `f/F` - could be "fix" or "fetch"
- `g/G` - reserved for navigation
- `h/H` - reserved for help
- `i/I` - could be "interactive" 
- `j/J/k/K` - reserved for navigation
- `l/L` - could be "log" related
- `m/M` - could be "merge" or "message"
- `o/O` - could be "open" or "operation"
- `p/P` - could be "split" (split -> p)
- `q/Q` - reserved for quit
- `t/T` - could be "tag" or "tree"
- `u/U` - could be "undo" or "duplicate" 
- `v/V` - reserved for visual mode
- `w/W` - could be "working copy"
- `x/X` - could be "execute" or "extract"
- `y/Y` - could be "yank" or "yes"
- `z/Z` - could be "zip" or "zone"

## Implementation Priority

1. **High Priority:** Complete missing menus for edit, describe, status
2. **Medium Priority:** Enhance existing menus with additional useful options
3. **Low Priority:** Add new commands (split, duplicate, bookmark)

## Validation Checklist

For each refined command:
- [ ] Has both quick_action and menu definitions
- [ ] Menu has 2-5 meaningful options
- [ ] Descriptions follow standardized format
- [ ] Keybindings don't conflict
- [ ] Destructive operations have confirmation
- [ ] Arguments use proper placeholder syntax
- [ ] Compatible with jj 0.31+ flags