# Spec Requirements Document

> Spec: Buffer Navigation
> Created: 2025-07-25
> Status: Planning

## Overview

Implement commit-aware navigation within the jj log buffer that treats each commit as a logical block for vertical movement, while preserving all native Neovim functionality for text operations. This enhances the user experience by providing intuitive commit-level navigation with visual highlighting, while maintaining full compatibility with standard Vim commands like selection (v/V) and yanking (y).

## User Stories

### Developer Navigating Between Commits

As a Neovim user viewing the jj log, I want to use enhanced j/k keys to jump between entire commits (not just lines), so that I can quickly browse through my repository history at the commit level while seeing clear visual feedback about which commit is currently selected.

The user opens the jj log window and can use j/k to move between commits, with all lines belonging to the current commit highlighted together. The cursor intelligently jumps to the next/previous commit, skipping over wrapped lines and focusing on commit boundaries. Standard Neovim commands like gg/G, search, and text operations work normally.

### Developer Using Standard Vim Operations

As a Neovim power user, I want all standard Vim text operations (visual selection, yanking, searching, etc.) to work normally within the jj log buffer, so that I can copy commit IDs, select text, and use familiar editing commands without any interference from the commit navigation features.

The user can use v/V for visual selection, y for yanking commit IDs or descriptions, / for searching, and all other standard Neovim commands work exactly as expected, while the enhanced j/k navigation provides commit-level movement when desired.

## Spec Scope

1. **Commit-Aware j/k Navigation** - Override j/k keys to jump between entire commits, with all commit lines highlighted as a block
2. **Commit Block Detection** - Parse jj log structure to identify commit boundaries and associated lines (including wrapped content)
3. **Visual Highlighting** - Highlight all lines belonging to the current commit to show selection scope
4. **Native Vim Compatibility** - Preserve all standard Neovim functionality (v/V selection, y yanking, search, etc.) 
5. **Buffer-Specific Enhancement** - Commit navigation only active in jj log buffers, no interference with other buffers

## Out of Scope

- Overriding other Vim navigation keys (gg/G, Ctrl-d/Ctrl-u work as normal Neovim behavior)
- Commit selection for operations (will be handled by future command framework features)  
- Editing or modifying log content (buffer remains read-only)
- Complex graph navigation (following branch lines) - reserved for advanced visualization features

## Expected Deliverable

1. Users can use j/k keys to jump between commits with all commit lines highlighted as a visual block
2. All standard Neovim text operations (selection, yanking, search) work normally without interference
3. Commit-aware navigation is properly scoped to only enhance jj log buffers

## Spec Documentation

- Tasks: @.agent-os/specs/2025-07-25-buffer-navigation/tasks.md
- Technical Specification: @.agent-os/specs/2025-07-25-buffer-navigation/sub-specs/technical-spec.md
- Tests Specification: @.agent-os/specs/2025-07-25-buffer-navigation/sub-specs/tests.md