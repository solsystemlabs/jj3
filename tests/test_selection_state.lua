-- Tests for selection state machine
require("tests.helpers.vim_mock")

local state_machine = require("jj.selection_state")
local types = require("jj.types")

describe("selection state machine", function()
  before_each(function()
    -- Reset any global state
    state_machine._reset_for_testing()
  end)

  describe("state definitions", function()
    it("should define all required states", function()
      assert.are.equal("browse", types.States.BROWSE)
      assert.are.equal("selecting_source", types.States.SELECTING_SOURCE)
      assert.are.equal("selecting_target", types.States.SELECTING_TARGET)
      assert.are.equal("selecting_multiple", types.States.SELECTING_MULTIPLE)
      assert.are.equal("confirming_multiple", types.States.CONFIRMING_MULTIPLE)
      assert.are.equal("executing_command", types.States.EXECUTING_COMMAND)
    end)

    it("should define all required events", function()
      assert.are.equal("command_started", types.Events.COMMAND_STARTED)
      assert.are.equal("target_selected", types.Events.TARGET_SELECTED)
      assert.are.equal("selection_cancelled", types.Events.SELECTION_CANCELLED)
      assert.are.equal("command_completed", types.Events.COMMAND_COMPLETED)
      assert.are.equal("command_failed", types.Events.COMMAND_FAILED)
    end)

    it("should define command types", function()
      assert.are.equal("single_target", types.CommandTypes.SINGLE_TARGET)
      assert.are.equal("multi_phase", types.CommandTypes.MULTI_PHASE)
      assert.are.equal("multi_select", types.CommandTypes.MULTI_SELECT)
      assert.are.equal("immediate", types.CommandTypes.IMMEDIATE)
    end)
  end)

  describe("command type inference", function()
    it("should infer IMMEDIATE for commands with no phases", function()
      local command_def = {
        description = "Simple command",
        jj_command = "describe"
      }
      assert.are.equal(types.CommandTypes.IMMEDIATE, state_machine.infer_command_type(command_def))
    end)

    it("should infer SINGLE_TARGET for commands with one phase", function()
      local command_def = {
        description = "Single target command",
        jj_command = "squash --into {target}",
        phases = {
          { key = "target", prompt = "Select target commit" }
        }
      }
      assert.are.equal(types.CommandTypes.SINGLE_TARGET, state_machine.infer_command_type(command_def))
    end)

    it("should infer MULTI_PHASE for commands with multiple phases", function()
      local command_def = {
        description = "Multi-phase command",
        jj_command = "rebase --source {source} --destination {destination}",
        phases = {
          { key = "source", prompt = "Select source commit" },
          { key = "destination", prompt = "Select destination commit" }
        }
      }
      assert.are.equal(types.CommandTypes.MULTI_PHASE, state_machine.infer_command_type(command_def))
    end)

    it("should infer MULTI_SELECT for commands with multi_select flag", function()
      local command_def = {
        description = "Multi-select command",
        jj_command = "abandon {targets}",
        phases = {
          { key = "targets", prompt = "Select commits to abandon", multi_select = true }
        }
      }
      assert.are.equal(types.CommandTypes.MULTI_SELECT, state_machine.infer_command_type(command_def))
    end)
  end)

  describe("state machine creation", function()
    it("should create a new state machine in BROWSE state", function()
      local machine = state_machine.new(0) -- buffer 0
      assert.are.equal(types.States.BROWSE, machine:get_current_state())
    end)

    it("should store buffer-local state", function()
      local machine1 = state_machine.new(1)
      local machine2 = state_machine.new(2)
      
      -- Should be independent instances
      assert.are_not.equal(machine1, machine2)
    end)
  end)

  describe("state transitions", function()
    local machine

    before_each(function()
      machine = state_machine.new(0)
    end)

    it("should transition from BROWSE to SELECTING_TARGET for single target commands", function()
      local command_def = {
        description = "Single target command",
        phases = { { key = "target", prompt = "Select target" } }
      }
      
      local success = machine:handle_event(types.Events.COMMAND_STARTED, { command_def = command_def })
      
      assert.is_true(success)
      assert.are.equal(types.States.SELECTING_TARGET, machine:get_current_state())
    end)

    it("should transition from BROWSE to SELECTING_SOURCE for multi-phase commands", function()
      local command_def = {
        description = "Multi-phase command",
        phases = {
          { key = "source", prompt = "Select source" },
          { key = "destination", prompt = "Select destination" }
        }
      }
      
      local success = machine:handle_event(types.Events.COMMAND_STARTED, { command_def = command_def })
      
      assert.is_true(success)
      assert.are.equal(types.States.SELECTING_SOURCE, machine:get_current_state())
    end)

    it("should transition through multi-phase workflow", function()
      local command_def = {
        description = "Multi-phase command",
        phases = {
          { key = "source", prompt = "Select source" },
          { key = "destination", prompt = "Select destination" }
        }
      }
      
      -- Start command
      machine:handle_event(types.Events.COMMAND_STARTED, { command_def = command_def })
      assert.are.equal(types.States.SELECTING_SOURCE, machine:get_current_state())
      
      -- Select source
      machine:handle_event(types.Events.TARGET_SELECTED, { commit_id = "abc123" })
      assert.are.equal(types.States.SELECTING_TARGET, machine:get_current_state())
      
      -- Select destination
      machine:handle_event(types.Events.TARGET_SELECTED, { commit_id = "def456" })
      assert.are.equal(types.States.EXECUTING_COMMAND, machine:get_current_state())
    end)

    it("should handle cancellation from any selection state", function()
      local command_def = {
        phases = { { key = "target", prompt = "Select target" } }
      }
      
      machine:handle_event(types.Events.COMMAND_STARTED, { command_def = command_def })
      assert.are.equal(types.States.SELECTING_TARGET, machine:get_current_state())
      
      machine:handle_event(types.Events.SELECTION_CANCELLED, {})
      assert.are.equal(types.States.BROWSE, machine:get_current_state())
    end)

    it("should reject invalid transitions", function()
      -- Try to select target when in BROWSE state (no command started)
      local success = machine:handle_event(types.Events.TARGET_SELECTED, { commit_id = "abc123" })
      
      assert.is_false(success)
      assert.are.equal(types.States.BROWSE, machine:get_current_state())
    end)
  end)

  describe("command context management", function()
    local machine

    before_each(function()
      machine = state_machine.new(0)
    end)

    it("should store command context when starting a command", function()
      local command_def = {
        description = "Test command",
        jj_command = "test {target}",
        phases = { { key = "target", prompt = "Select target" } }
      }
      
      machine:handle_event(types.Events.COMMAND_STARTED, { command_def = command_def })
      
      local context = machine:get_command_context()
      assert.are.equal(command_def, context.command_def)
      assert.are.equal("target", context.current_phase)
      assert.are.equal(1, context.phase_index)
    end)

    it("should store selections during multi-phase workflow", function()
      local command_def = {
        phases = {
          { key = "source", prompt = "Select source" },
          { key = "destination", prompt = "Select destination" }
        }
      }
      
      machine:handle_event(types.Events.COMMAND_STARTED, { command_def = command_def })
      machine:handle_event(types.Events.TARGET_SELECTED, { commit_id = "abc123" })
      
      local context = machine:get_command_context()
      assert.are.equal("abc123", context.selections.source)
      assert.are.equal("destination", context.current_phase)
      assert.are.equal(2, context.phase_index)
    end)

    it("should clear context on cancellation", function()
      local command_def = {
        phases = { { key = "target", prompt = "Select target" } }
      }
      
      machine:handle_event(types.Events.COMMAND_STARTED, { command_def = command_def })
      machine:handle_event(types.Events.SELECTION_CANCELLED, {})
      
      local context = machine:get_command_context()
      assert.is_nil(context)
    end)
  end)
end)