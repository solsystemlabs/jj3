# Tests Specification

This is the tests coverage details for the spec detailed in @.agent-os/specs/2025-07-30-selection-details-positioning/spec.md

> Created: 2025-07-30
> Version: 1.0.0

## Test Coverage

### Unit Tests

**Window Positioning Functions**
- Test calculation of left-side window coordinates based on log window position
- Test window sizing calculations for different terminal widths
- Test spacing calculations between windows
- Test edge case handling for narrow terminals

**Layout Calculation Logic**  
- Test available space calculation
- Test minimum width requirements
- Test fallback positioning logic

### Integration Tests

**Window Creation and Positioning**
- Test floating window creation with left-side positioning
- Test simultaneous display of log window and selection details window
- Test window positioning across different terminal sizes
- Test proper spacing and non-overlapping layout

**User Interaction Scenarios**
- Test selection details display when navigating log entries
- Test window positioning consistency during selection changes
- Test behavior when resizing terminal while windows are open

### Manual Testing Scenarios

**Visual Verification**
- Verify selection details window appears on left side of log window
- Verify both windows are fully visible and readable
- Verify appropriate spacing between windows
- Test behavior on various terminal sizes (narrow, wide, standard)

**Edge Case Testing**
- Test behavior when terminal is too narrow for both windows
- Test positioning when log window is at different positions
- Test consistent behavior across multiple selection operations

### Mocking Requirements

- **Terminal Dimensions:** Mock `vim.api.nvim_get_option('columns')` for different screen sizes
- **Window Properties:** Mock existing window configurations for positioning calculations
- **Neovim API Calls:** Mock window creation and positioning API responses for unit testing