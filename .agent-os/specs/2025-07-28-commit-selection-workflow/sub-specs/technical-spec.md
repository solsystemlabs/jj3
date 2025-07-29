# Technical Specification

This is the technical specification for the spec detailed in @.agent-os/specs/2025-07-28-commit-selection-workflow/spec.md

> Created: 2025-07-28
> Version: 1.0.0

## Technical Requirements

- **State Management System** - Track selection mode state with clear transitions between browse/selection modes
- **Command Queue Implementation** - Store pending commands with their arguments and target requirements
- **Visual Feedback System** - Modify log display to show selection indicators and mode status
- **Keybinding Context Switching** - Handle different keybinding behaviors for selection vs browse mode
- **Commit ID Extraction** - Extract commit IDs from log buffer positions for command execution
- **Integration with Existing Commands** - Modify existing command execution to support queued target selection

## Approach Options

**Option A: Global State with Mode Switching**
- Pros: Simple to implement, clear state transitions, easy to debug
- Cons: Global state can be fragile, requires careful cleanup, doesn't scale to multi-selection workflows

**Option B: Buffer-local State Management**
- Pros: Isolated state per log buffer, better encapsulation, easier testing
- Cons: Complex to manage multi-phase selections, difficult to handle commands requiring multiple targets

**Option C: Event-driven State Machine** (Selected)
- Pros: Handles complex multi-selection workflows, formal state transitions, extensible for new command patterns, prevents invalid states
- Cons: More complex implementation, requires state machine framework

**Rationale:** Option C is necessary given the complexity of jj commands that require multiple selections (abandon, new) and commands with multiple flag targets (-f then -t). A state machine provides the robust foundation needed for multi-phase selection workflows while preventing invalid states and enabling clear error recovery.

## External Dependencies

- **No new external dependencies required**
- **Justification:** We'll implement a lightweight state machine framework as part of the plugin rather than adding external dependencies. This builds entirely on existing Neovim APIs and the current plugin architecture.

## Implementation Details

### State Machine Architecture
```lua
-- Selection state machine
local SelectionStates = {
  BROWSE = "browse",
  SELECTING_SOURCE = "selecting_source", 
  SELECTING_TARGET = "selecting_target",
  SELECTING_MULTIPLE = "selecting_multiple",
  CONFIRMING_MULTI_SELECTION = "confirming_multi_selection",
  EXECUTING_COMMAND = "executing_command"
}

local SelectionEvents = {
  COMMAND_SELECTED = "command_selected",
  TARGET_SELECTED = "target_selected", 
  MULTI_SELECTION_CONFIRMED = "multi_selection_confirmed",
  SELECTION_CANCELLED = "selection_cancelled",
  COMMAND_COMPLETED = "command_completed",
  COMMAND_FAILED = "command_failed"
}
```

### Command Context Structure
```lua
-- Command execution context
local command_context = {
  command_name = "squash",
  selections = {
    source = nil,     -- commit ID for -f flag
    target = nil,     -- commit ID for -t flag
    multiple = {}     -- array of commit IDs for multi-select commands
  },
  current_phase = "source",  -- which selection we're currently gathering
  phases = {"source", "target"}  -- ordered list of required selections
}
```

### Visual Feedback System
- State-specific status line messages ("Select source commit", "Select target commit")
- Different highlight colors for each selection phase
- Progress indicators for multi-phase selections
- Selection history display for multi-select operations

### Integration Points
- New `selection_state.lua` module for state machine implementation
- Modify `ui.lua` for state-aware visual feedback
- Extend `keymaps.lua` for state-specific keybindings
- Update `operations.lua` to handle complex command contexts
- Add state transition handling to `log.lua`
