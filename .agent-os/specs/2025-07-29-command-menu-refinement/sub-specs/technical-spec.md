# Technical Specification

This is the technical specification for the spec detailed in @.agent-os/specs/2025-07-29-command-menu-refinement/spec.md

> Created: 2025-07-29
> Version: 1.0.0

## Technical Requirements

### Command-Specific Implementation Requirements

**NEW Command**
- Add user input prompting workflow for description
- Implement multi-parent commit creation using multi-select workflow
- Support --no-edit flag for commits without description prompts
- Maintain proper argument substitution for commit targeting

**REBASE Command**
- Remove quick action, implement menu-only workflow
- Change keybinding from `R` to `r` for menu access
- Implement insert-before and insert-after rebase options
- Support branch rebasing and current commit rebasing variants

**ABANDON Command**
- Integrate multi-select workflow for abandoning multiple commits
- Maintain confirmation prompts for all abandon operations
- Support --retain-bookmarks and --restore-descendants flags
- Keep existing quick action behavior unchanged

**SQUASH Command**
- Implement floating terminal window for interactive squash operations
- Support cursor-based commit selection for squash operations
- Auto-close terminal window when interactive command completes
- Maintain existing quick action squash behavior

**STATUS Command**
- Implement floating window display for 'jj st' output
- Remove menu configuration (quick action only)
- Ensure proper window cleanup and management
- Format output appropriately for floating window display

### New Technical Components Required

**Floating Terminal Window System**
- Create terminal window that executes jj interactive commands
- Implement auto-close functionality based on command completion
- Handle terminal window positioning and sizing
- Manage terminal session cleanup

**Multi-Select Workflow Integration**
- Extend existing selection system to support multiple commits
- Implement visual feedback for multi-select operations
- Handle multi-commit argument passing to jj commands
- Validate multi-select compatibility with command types

**Enhanced User Input System**
- Implement description prompting with proper validation
- Support cancellation of input-dependent operations
- Handle empty input scenarios gracefully
- Integrate with existing command execution pipeline

## Approach Options

**Option A: Incremental Per-Command Updates** (Selected)
- Pros: Allows focused testing of each command change, easier rollback of issues
- Cons: May require multiple integration phases

**Option B: Complete Rewrite of Command System**
- Pros: Clean slate implementation, unified patterns
- Cons: High risk, breaks existing functionality during development

**Rationale:** Option A provides the safest path to implementing the specified changes while maintaining system stability during development.

## External Dependencies

**None** - All required functionality will be implemented using existing Neovim APIs and the current jj command execution framework.

## Implementation Strategy

### Phase 1: Core Infrastructure Updates
1. Implement floating terminal window system for interactive commands
2. Extend multi-select workflow for multi-commit operations  
3. Enhance user input prompting system

### Phase 2: Command-Specific Updates
1. Update each command according to specifications
2. Implement new menu options and keybinding changes
3. Remove/modify quick actions as specified

### Phase 3: Integration and Testing
1. Test all command workflows with new infrastructure
2. Validate keybinding changes and conflict resolution
3. Ensure backward compatibility where specified

### Phase 4: Documentation and Polish
1. Update command documentation and help text
2. Verify all edge cases and error conditions
3. Optimize performance and user experience