# Spec Tasks

These are the tasks to be completed for the spec detailed in @.agent-os/specs/2025-07-29-command-menu-refinement/spec.md

> Created: 2025-07-29
> Status: Ready for Implementation

## Tasks

- [x] 1. Update NEW Command Implementation (COMPLETED WITH SELECTION INTEGRATION)
  - [x] 1.1 Write tests for NEW command with description prompt workflow
  - [x] 1.2 Implement description prompting for quick action (`n`)
  - [x] 1.3 Add multi-parent option to NEW menu (`N`) with selection state machine integration
  - [x] 1.4 Update menu options to match specification with phases for target selection
  - [x] 1.5 Verify all tests pass
  - [x] 1.6 Integrate with selection state machine for multi-select workflows
  - [x] 1.7 Update menu system to handle phases-based selection workflows
  - [x] 1.8 Test selection integration functionality

- [ ] 2. Update REBASE Command Implementation
  - [ ] 2.1 Write tests for REBASE menu-only workflow
  - [ ] 2.2 Remove quick action for REBASE (menu-only with `r`)
  - [ ] 2.3 Implement 4 rebase menu options including insert before/after
  - [ ] 2.4 Update keybinding from `R` to `r` for menu
  - [ ] 2.5 Verify all tests pass

- [ ] 3. Update ABANDON Command Implementation
  - [ ] 3.1 Write tests for ABANDON multi-select workflow
  - [ ] 3.2 Keep existing quick action behavior (`a`)
  - [ ] 3.3 Implement multi-select option in ABANDON menu (`A`)
  - [ ] 3.4 Update remaining menu options to match specification
  - [ ] 3.5 Verify all tests pass

- [ ] 4. Update SQUASH Command Implementation
  - [ ] 4.1 Write tests for SQUASH interactive workflow
  - [ ] 4.2 Keep existing quick action behavior (`s`)
  - [ ] 4.3 Implement floating terminal window for interactive squash
  - [ ] 4.4 Update SQUASH menu options to match specification
  - [ ] 4.5 Verify all tests pass

- [ ] 5. Update STATUS Command Implementation
  - [ ] 5.1 Write tests for STATUS floating window display
  - [ ] 5.2 Implement floating window display for 'jj st' output
  - [ ] 5.3 Remove menu configuration for STATUS command
  - [ ] 5.4 Ensure proper window cleanup and management
  - [ ] 5.5 Verify all tests pass

- [ ] 6. Validation and Integration Testing
  - [ ] 6.1 Write integration tests for all updated command workflows
  - [ ] 6.2 Test multi-select workflows for applicable commands
  - [ ] 6.3 Test floating window functionality for interactive commands
  - [ ] 6.4 Test keybinding changes and conflict detection
  - [ ] 6.5 Verify all tests pass