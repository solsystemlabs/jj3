# Technical Specification

This is the technical specification for the spec detailed in @.agent-os/specs/2025-07-25-buffer-navigation/spec.md

> Created: 2025-07-25
> Version: 1.0.0

## Technical Requirements

- **Commit Boundary Detection** - Parse jj log output to identify which lines belong to each commit block
- **Buffer-Local j/k Override** - Use `vim.api.nvim_buf_set_keymap()` to override only j/k keys in jj log buffers  
- **Multi-Line Highlighting** - Use `vim.api.nvim_buf_add_highlight()` to highlight entire commit blocks visually
- **Cursor Positioning** - Use `vim.api.nvim_win_set_cursor()` to jump cursor to appropriate line within commit blocks
- **Native Vim Preservation** - Ensure all other Neovim functionality (v/V, y, /, gg/G, etc.) works unchanged
- **Integration Points** - Work with existing log parsing and window management without disruption

## Approach Options

**Option A: Override All Navigation Keys**
- Pros: Complete control over navigation behavior, consistent experience
- Cons: Breaks user expectations, interferes with standard Vim operations, complex to implement

**Option B: Minimal j/k Override with Full Vim Compatibility** (Selected)
- Pros: Enhances most common navigation without breaking Vim workflow, preserves user muscle memory
- Cons: Limited to vertical navigation, requires careful commit boundary detection

**Option C: Alternative Key Mappings**
- Pros: No interference with existing keys, completely additive
- Cons: Requires learning new keybindings, doesn't enhance intuitive j/k usage

**Rationale:** Option B provides the most value with minimal disruption to established Neovim workflows, focusing on enhancing the most commonly used navigation keys while preserving all other functionality.

## External Dependencies

- **Neovim 0.11+** - Required for buffer-local keymap APIs and cursor management functions
- **Justification:** Already established as minimum requirement, provides stable APIs for navigation

## Implementation Details

### Commit Structure Detection
```lua
-- Example commit block structure in jj log
local commit_structure = {
  start_line = 5,     -- Line where commit begins
  end_line = 8,       -- Last line of commit (including wrapped content)
  commit_id = "abc123", -- Extracted commit ID
  header_line = 5,    -- Line with commit header info
  content_lines = {6, 7, 8} -- Lines with description/metadata
}
```

### Core Functions
- `detect_commit_boundaries(buffer_id)` - Parse buffer content to identify commit blocks
- `get_commit_at_cursor()` - Determine which commit block contains current cursor position
- `navigate_to_next_commit()` / `navigate_to_prev_commit()` - Move cursor to next/previous commit block
- `highlight_commit_block(buffer_id, start_line, end_line)` - Highlight entire commit visually
- `setup_commit_navigation(buffer_id)` - Register j/k overrides for commit-aware movement
- `clear_commit_highlights(buffer_id)` - Remove existing commit highlighting

### Integration with Existing Systems
- Navigation setup called when jj log buffer content is rendered
- Uses existing log parsing infrastructure to understand commit structure
- Integrates with buffer lifecycle management for cleanup
- Works alongside existing window management without modification