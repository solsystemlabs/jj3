# Technical Specification

This is the technical specification for the spec detailed in @.agent-os/specs/2025-07-30-selection-details-positioning/spec.md

> Created: 2025-07-30
> Version: 1.0.0

## Technical Requirements

- Modify floating window positioning logic to calculate left-side placement relative to log window
- Update window sizing calculations to ensure both windows fit within terminal dimensions  
- Implement proper coordinate calculation for left-positioned floating window
- Ensure consistent spacing between the two windows
- Handle edge cases where terminal width is insufficient for both windows

## Approach Options

**Option A:** Absolute positioning based on log window coordinates
- Pros: Simple coordinate calculation, predictable placement
- Cons: May not handle all edge cases, less flexible for future layout changes

**Option B:** Relative positioning with dynamic layout calculation (Selected)  
- Pros: Handles various screen sizes gracefully, more maintainable, adapts to different log window sizes
- Cons: Slightly more complex implementation, requires more comprehensive testing

**Rationale:** Option B provides better user experience across different terminal configurations and is more robust for handling edge cases like narrow terminals or varying log window sizes.

## Technical Implementation Details

### Window Positioning Logic
- Calculate available terminal width using `vim.api.nvim_get_option('columns')`
- Determine log window position and dimensions
- Position selection details window to the left with appropriate margin
- Implement fallback positioning if insufficient space on left side

### Layout Calculations
- Selection details window width: Fixed or percentage-based
- Minimum spacing between windows: 1-2 columns
- Fallback behavior: Position above/below if horizontal space insufficient

### Integration Points
- Modify existing floating window creation code in UI management module
- Update window positioning functions to use left-side calculations
- Ensure compatibility with existing window management logic

## External Dependencies

No new external dependencies required - using existing Neovim API functions:
- `vim.api.nvim_open_win()` for window creation
- `vim.api.nvim_get_option()` for terminal dimensions
- `vim.api.nvim_win_get_config()` for existing window properties