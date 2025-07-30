# Spec Tasks

These are the tasks to be completed for the spec detailed in @.agent-os/specs/2025-07-30-selection-details-positioning/spec.md

> Created: 2025-07-30
> Status: Ready for Implementation

## Tasks

- [ ] 1. Analyze Current Window Positioning Code
  - [ ] 1.1 Write tests for current window positioning behavior
  - [ ] 1.2 Locate existing floating window creation code in UI module
  - [ ] 1.3 Identify current positioning logic and coordinate calculations
  - [ ] 1.4 Document current window sizing and spacing logic
  - [ ] 1.5 Verify all positioning tests pass with current implementation

- [ ] 2. Implement Left-Side Positioning Logic
  - [ ] 2.1 Write tests for left-side positioning calculations
  - [ ] 2.2 Create function to calculate left-side window coordinates
  - [ ] 2.3 Implement terminal width detection and available space calculation
  - [ ] 2.4 Add proper spacing calculation between windows
  - [ ] 2.5 Verify all left-positioning tests pass

- [ ] 3. Add Edge Case Handling
  - [ ] 3.1 Write tests for narrow terminal edge cases
  - [ ] 3.2 Implement fallback positioning when insufficient horizontal space
  - [ ] 3.3 Add minimum width requirements and validation
  - [ ] 3.4 Handle window positioning when log window varies in size
  - [ ] 3.5 Verify all edge case tests pass

- [ ] 4. Update Window Creation Integration
  - [ ] 4.1 Write integration tests for selection details window positioning
  - [ ] 4.2 Modify existing floating window creation to use new positioning logic
  - [ ] 4.3 Update window management code to handle left-side placement
  - [ ] 4.4 Ensure backward compatibility with existing window functionality
  - [ ] 4.5 Verify all integration tests pass