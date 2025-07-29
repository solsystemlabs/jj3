# Spec Requirements Document

> Spec: Commit Selection Workflow
> Created: 2025-07-28
> Status: Planning

## Overview

Implement a comprehensive commit selection workflow that supports single and multi-target command execution. Users should be able to select commands requiring one or more target commits, then navigate through multi-phase selection workflows to choose all required targets for complex jj operations.

## User Stories

### Single Target Command Selection

As a jj user, I want to select a command from the menu that requires a target commit (like "squash current working copy into selected"), then navigate the log to choose the target commit, so that I can execute operations without manually typing commit IDs.

When a user selects a single-target command:
1. The command menu closes
2. The log window becomes active with a selection mode indicator
3. User can navigate using existing keybindings (j/k, gg/G)
4. User can confirm selection (Enter) or cancel (Esc)
5. The selected command executes with the chosen commit ID
6. Success/error feedback is displayed

### Multi-Phase Command Selection

As a jj user, I want to select commands requiring multiple targets (like rebase with -f and -t flags), then navigate through each selection phase, so that I can execute complex operations with clear guidance.

When a user selects a multi-phase command:
1. The command menu closes and enters first selection phase
2. Status shows "Select source commit (-f flag)"
3. User navigates and selects first target
4. Status updates to "Select target commit (-t flag)" 
5. User navigates and selects second target
6. Command executes with both selections
7. User can cancel at any phase to abort the entire operation

### Visual Selection Feedback

As a jj user, I want clear visual feedback during selection workflows, so that I understand which phase I'm in and what action is expected.

The interface should clearly indicate:
- Current selection phase ("Select source commit", "Select target commit")
- Which command is being configured
- Progress through multi-phase selections (Phase 1 of 2)
- The currently highlighted commit with phase-specific highlighting
- Available actions (confirm/cancel/previous phase)

## Spec Scope

1. **State Machine Framework** - Implement robust state management for complex multi-phase selection workflows
2. **Multi-Phase Command Support** - Handle commands requiring multiple sequential target selections (source then target)
3. **Command Context Management** - Store and manage complex command execution contexts with multiple parameters
4. **Phase-Aware Visual Feedback** - Display selection phase progress and context-specific highlighting
5. **Selection Navigation and Confirmation** - Support navigation, confirmation, and cancellation at any phase
6. **Command Definition Framework** - Define command selection requirements (single, multi-phase, multi-select)

## Out of Scope

- Multi-select operations within a single phase (selecting multiple commits simultaneously)
- Selection persistence across plugin sessions  
- Undo/redo for selection operations
- Graphical selection tools (mouse/visual selection)
- Command composition (chaining multiple commands with selections)

## Expected Deliverable

1. Users can execute single-target commands through guided selection workflow
2. Users can execute multi-phase commands (like rebase -f -t) through sequential selection phases
3. Clear visual feedback distinguishes selection phases and provides progress indicators
4. Robust state management prevents invalid states and handles cancellation at any phase
5. Extensible command definition system supports adding new multi-phase commands

## Spec Documentation

- Tasks: @.agent-os/specs/2025-07-28-commit-selection-workflow/tasks.md
- Technical Specification: @.agent-os/specs/2025-07-28-commit-selection-workflow/sub-specs/technical-spec.md
- Tests Specification: @.agent-os/specs/2025-07-28-commit-selection-workflow/sub-specs/tests.md
