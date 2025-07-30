# Spec Requirements Document

> Spec: Selection Details Window Positioning Fix
> Created: 2025-07-30
> Status: Planning

## Overview

Fix the positioning of the selection details floating window so it appears on the left side of the log window instead of the right side where it currently covers the log content.

## User Stories

### Improved Selection Details Visibility

As a jj3 plugin user, I want to view commit selection details without having the details window cover the log graph, so that I can see both the log content and the selection details simultaneously.

When a user navigates the log and selects a commit, the selection details window should appear to the left of the log window, providing clear visibility of both the repository graph and the detailed commit information without visual obstruction.

## Spec Scope

1. **Window Positioning Logic** - Update floating window positioning to place selection details on the left side of the log window
2. **Layout Calculations** - Ensure proper spacing and sizing so both windows fit within the available screen space
3. **Edge Case Handling** - Handle scenarios where there isn't enough space on the left side

## Out of Scope

- Changing the content or styling of the selection details window
- Adding new information to the selection details display
- Modifying the log window layout or positioning
- Adding configuration options for window positioning

## Expected Deliverable

1. Selection details window appears on the left side of the log window without covering log content
2. Both windows remain fully visible and usable within the available screen space
3. Window positioning works correctly across different terminal sizes and screen configurations

## Spec Documentation

- Tasks: @.agent-os/specs/2025-07-30-selection-details-positioning/tasks.md
- Technical Specification: @.agent-os/specs/2025-07-30-selection-details-positioning/sub-specs/technical-spec.md
- Tests Specification: @.agent-os/specs/2025-07-30-selection-details-positioning/sub-specs/tests.md