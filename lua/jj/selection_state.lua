-- Selection state machine for commit targeting workflows
local M = {}

local types = require("jj.types")

-- Buffer-local state machine instances
local buffer_machines = {}

-- State transition table
local transitions = {
  [types.States.BROWSE] = {
    [types.Events.COMMAND_STARTED] = function(machine, event_data)
      local command_type = M.infer_command_type(event_data.command_def)
      
      if command_type == types.CommandTypes.IMMEDIATE then
        return types.States.EXECUTING_COMMAND
      elseif command_type == types.CommandTypes.SINGLE_TARGET then
        return types.States.SELECTING_TARGET
      elseif command_type == types.CommandTypes.MULTI_PHASE then
        return types.States.SELECTING_SOURCE
      elseif command_type == types.CommandTypes.MULTI_SELECT then
        return types.States.SELECTING_MULTIPLE
      end
      
      return nil -- Invalid transition
    end
  },
  
  [types.States.SELECTING_SOURCE] = {
    [types.Events.TARGET_SELECTED] = function(machine, event_data)
      local context = machine.command_context
      if context and context.phase_index < #context.command_def.phases then
        return types.States.SELECTING_TARGET
      else
        return types.States.EXECUTING_COMMAND
      end
    end,
    [types.Events.SELECTION_CANCELLED] = types.States.BROWSE
  },
  
  [types.States.SELECTING_TARGET] = {
    [types.Events.TARGET_SELECTED] = types.States.EXECUTING_COMMAND,
    [types.Events.SELECTION_CANCELLED] = types.States.BROWSE
  },
  
  [types.States.SELECTING_MULTIPLE] = {
    [types.Events.TARGET_SELECTED] = function(machine, event_data)
      if event_data.confirm_multi_select then
        return types.States.EXECUTING_COMMAND
      else
        return types.States.SELECTING_MULTIPLE -- Stay in same state for multi-select
      end
    end,
    [types.Events.SELECTION_CANCELLED] = types.States.BROWSE
  },
  
  [types.States.CONFIRMING_MULTIPLE] = {
    [types.Events.TARGET_SELECTED] = types.States.EXECUTING_COMMAND, -- Confirmation selected
    [types.Events.SELECTION_CANCELLED] = types.States.BROWSE
  },
  
  [types.States.EXECUTING_COMMAND] = {
    [types.Events.COMMAND_COMPLETED] = types.States.BROWSE,
    [types.Events.COMMAND_FAILED] = types.States.BROWSE
  }
}

-- State entry callbacks
local state_entry_callbacks = {
  [types.States.SELECTING_SOURCE] = function(machine, event_data)
    if event_data.command_def and not machine.command_context then
      machine:_initialize_command_context(event_data.command_def)
    end
  end,
  
  [types.States.SELECTING_TARGET] = function(machine, event_data)
    if event_data.command_def and not machine.command_context then
      machine:_initialize_command_context(event_data.command_def)
    end
  end,
  
  [types.States.SELECTING_MULTIPLE] = function(machine, event_data)
    if event_data.command_def and not machine.command_context then
      machine:_initialize_command_context(event_data.command_def)
    end
  end,
  
  [types.States.EXECUTING_COMMAND] = function(machine, event_data)
    -- Command execution will be handled by other systems
  end
}

-- State exit callbacks
local state_exit_callbacks = {
  [types.States.BROWSE] = function(machine, event_data)
    -- Clear any previous context when leaving browse mode
  end
}

-- State machine class
local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine:new(buffer_id)
  local instance = {
    buffer_id = buffer_id,
    current_state = types.States.BROWSE,
    command_context = nil
  }
  setmetatable(instance, StateMachine)
  return instance
end

function StateMachine:get_current_state()
  return self.current_state
end

function StateMachine:get_command_context()
  return self.command_context
end

function StateMachine:handle_event(event, event_data)
  local current_transitions = transitions[self.current_state]
  if not current_transitions then
    return false
  end
  
  local transition = current_transitions[event]
  if not transition then
    return false
  end
  
  local new_state
  if type(transition) == "function" then
    new_state = transition(self, event_data)
  else
    new_state = transition
  end
  
  if not new_state then
    return false
  end
  
  -- Execute exit callback for current state
  local exit_callback = state_exit_callbacks[self.current_state]
  if exit_callback then
    exit_callback(self, event_data)
  end
  
  -- Transition to new state
  local old_state = self.current_state
  self.current_state = new_state
  
  -- Handle state-specific logic
  if event == types.Events.TARGET_SELECTED and self.command_context then
    self:_handle_target_selection(event_data)
  elseif event == types.Events.SELECTION_CANCELLED then
    self:_clear_command_context()
  end
  
  -- Execute entry callback for new state
  local entry_callback = state_entry_callbacks[new_state]
  if entry_callback then
    entry_callback(self, event_data)
  end
  
  return true
end

function StateMachine:_initialize_command_context(command_def)
  self.command_context = {
    command_def = command_def,
    selections = {},
    current_phase = command_def.phases and command_def.phases[1].key or nil,
    phase_index = 1
  }
end

function StateMachine:_handle_target_selection(event_data)
  if not self.command_context or not event_data.commit_id then
    return
  end
  
  local context = self.command_context
  local current_phase_key = context.current_phase
  
  -- Store the selection
  if context.command_def.phases[context.phase_index].multi_select then
    -- Multi-select: add to array
    context.selections[current_phase_key] = context.selections[current_phase_key] or {}
    table.insert(context.selections[current_phase_key], event_data.commit_id)
  else
    -- Single selection: store directly
    context.selections[current_phase_key] = event_data.commit_id
  end
  
  -- Advance to next phase if available
  if context.phase_index < #context.command_def.phases then
    context.phase_index = context.phase_index + 1
    context.current_phase = context.command_def.phases[context.phase_index].key
  end
end

function StateMachine:_clear_command_context()
  self.command_context = nil
end

-- Module functions

function M.new(buffer_id)
  local machine = StateMachine:new(buffer_id)
  buffer_machines[buffer_id] = machine
  return machine
end

function M.get_machine(buffer_id)
  return buffer_machines[buffer_id]
end

function M.infer_command_type(command_def)
  if not command_def.phases or #command_def.phases == 0 then
    return types.CommandTypes.IMMEDIATE
  elseif #command_def.phases == 1 then
    if command_def.phases[1].multi_select then
      return types.CommandTypes.MULTI_SELECT
    else
      return types.CommandTypes.SINGLE_TARGET
    end
  else
    return types.CommandTypes.MULTI_PHASE
  end
end

-- Testing helper
function M._reset_for_testing()
  buffer_machines = {}
end

return M