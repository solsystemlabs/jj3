-- Type definitions for selection state management
local M = {}

-- State definitions for selection workflow
M.States = {
  BROWSE = "browse",
  SELECTING_SOURCE = "selecting_source",
  SELECTING_TARGET = "selecting_target",
  SELECTING_MULTIPLE = "selecting_multiple",
  CONFIRMING_MULTIPLE = "confirming_multiple",
  EXECUTING_COMMAND = "executing_command"
}

-- Event definitions for state transitions
M.Events = {
  COMMAND_STARTED = "command_started",
  TARGET_SELECTED = "target_selected",
  SELECTION_CANCELLED = "selection_cancelled",
  COMMAND_COMPLETED = "command_completed",
  COMMAND_FAILED = "command_failed"
}

-- Command type definitions (inferred from phases)
M.CommandTypes = {
  SINGLE_TARGET = "single_target",    -- One target selection
  MULTI_PHASE = "multi_phase",        -- Sequential selections (source->target)
  MULTI_SELECT = "multi_select",      -- Multiple commits in one phase  
  IMMEDIATE = "immediate"             -- No selection needed
}

return M