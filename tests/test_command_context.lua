-- Tests for command context management and unified command definitions
require("tests.helpers.vim_mock")

local command_context = require("jj.command_context")
local types = require("jj.types")

describe("command context management", function()
  before_each(function()
    -- Reset any global state
    command_context._reset_for_testing()
  end)

  describe("unified command definitions", function()
    it("should extend existing command structure with phases", function()
      local extended_command = {
        quick_action = {
          cmd = "squash",
          args = { "-t", "{target}" },
          keymap = "s",
          description = "Squash current working copy into selected"
        },
        menu = {
          keymap = "S",
          title = "Squash Options",
          options = {
            {
              key = "1",
              desc = "Squash current working copy into selected",
              cmd = "squash",
              args = { "-t", "{target}" },
              phases = {
                { key = "target", prompt = "Select target commit to squash into" }
              }
            }
          }
        }
      }
      
      local processed = command_context.process_command_definition("squash_into", extended_command)
      
      assert.is_not_nil(processed)
      assert.are.equal(types.CommandTypes.SINGLE_TARGET, processed.command_type)
      assert.are.equal(1, #processed.phases)
    end)

    it("should handle commands with no phases (immediate execution)", function()
      local immediate_command = {
        quick_action = {
          cmd = "describe",
          args = {},
          keymap = "d",
          description = "Edit description of current commit"
        }
      }
      
      local processed = command_context.process_command_definition("describe", immediate_command)
      
      assert.are.equal(types.CommandTypes.IMMEDIATE, processed.command_type)
      assert.is_nil(processed.phases)
    end)

    it("should handle multi-phase commands", function()
      local multi_phase_command = {
        quick_action = {
          cmd = "rebase",
          args = { "-s", "{source}", "-d", "{destination}" },
          keymap = "r",
          description = "Rebase source onto destination",
          phases = {
            { key = "source", prompt = "Select source commit" },
            { key = "destination", prompt = "Select destination commit" }
          }
        }
      }
      
      local processed = command_context.process_command_definition("rebase_multi", multi_phase_command)
      
      assert.are.equal(types.CommandTypes.MULTI_PHASE, processed.command_type)
      assert.are.equal(2, #processed.phases)
      assert.are.equal("source", processed.phases[1].key)
      assert.are.equal("destination", processed.phases[2].key)
    end)

    it("should handle multi-select commands", function()
      local multi_select_command = {
        quick_action = {
          cmd = "abandon",
          args = { "{targets}" },
          keymap = "a",
          description = "Abandon multiple commits",
          phases = {
            { key = "targets", prompt = "Select commits to abandon", multi_select = true }
          }
        }
      }
      
      local processed = command_context.process_command_definition("abandon_multi", multi_select_command)
      
      assert.are.equal(types.CommandTypes.MULTI_SELECT, processed.command_type)
      assert.is_true(processed.phases[1].multi_select)
    end)
  end)

  describe("command registration", function()
    it("should register commands with the existing system", function()
      local test_command = {
        quick_action = {
          cmd = "test",
          args = { "{target}" },
          phases = {
            { key = "target", prompt = "Select target" }
          }
        }
      }
      
      command_context.register_command("test_cmd", test_command)
      
      local registered = command_context.get_command_definition("test_cmd")
      assert.is_not_nil(registered)
      assert.are.equal(types.CommandTypes.SINGLE_TARGET, registered.command_type)
    end)

    it("should integrate with default commands", function()
      -- Load default commands with selection phases
      command_context.register_default_commands_with_phases()
      
      local squash_command = command_context.get_command_definition("squash_into_selected")
      assert.is_not_nil(squash_command)
      assert.are.equal(types.CommandTypes.SINGLE_TARGET, squash_command.command_type)
    end)
  end)

  describe("argument template processing", function()
    it("should identify required selections from command templates", function()
      local args = { "-s", "{source}", "-d", "{destination}", "--message", "{user_input}" }
      
      local required_selections = command_context.extract_required_selections(args)
      
      assert.are.equal(2, #required_selections)
      assert.is_true(vim.tbl_contains(required_selections, "source"))
      assert.is_true(vim.tbl_contains(required_selections, "destination"))
      assert.is_false(vim.tbl_contains(required_selections, "user_input"))
    end)

    it("should substitute selections in command arguments", function()
      local args = { "-s", "{source}", "-d", "{destination}" }
      local selections = { source = "abc123", destination = "def456" }
      
      local substituted = command_context.substitute_selections(args, selections)
      
      assert.are.same({ "-s", "abc123", "-d", "def456" }, substituted)
    end)

    it("should handle missing selections gracefully", function()
      local args = { "-s", "{source}", "-d", "{destination}" }
      local selections = { source = "abc123" } -- missing destination
      
      local substituted = command_context.substitute_selections(args, selections)
      
      -- Should preserve template for missing selections
      assert.are.same({ "-s", "abc123", "-d", "{destination}" }, substituted)
    end)
  end)

  describe("command validation", function()
    it("should validate that all required phases are defined", function()
      local command_def = {
        quick_action = {
          cmd = "rebase",
          args = { "-s", "{source}", "-d", "{destination}" },
          phases = {
            { key = "source", prompt = "Select source" }
            -- Missing destination phase
          }
        }
      }
      
      local is_valid, errors = command_context.validate_command_definition(command_def)
      
      assert.is_false(is_valid)
      assert.is_true(#errors > 0)
      assert.is_true(vim.tbl_contains(errors, "Missing phase definition for required selection: destination"))
    end)

    it("should validate phase key uniqueness", function()
      local command_def = {
        quick_action = {
          cmd = "test",
          args = { "{target}" },
          phases = {
            { key = "target", prompt = "Select first target" },
            { key = "target", prompt = "Select second target" } -- Duplicate key
          }
        }
      }
      
      local is_valid, errors = command_context.validate_command_definition(command_def)
      
      assert.is_false(is_valid)
      assert.is_true(vim.tbl_contains(errors, "Duplicate phase key: target"))
    end)

    it("should accept valid command definitions", function()
      local command_def = {
        quick_action = {
          cmd = "rebase",
          args = { "-s", "{source}", "-d", "{destination}" },
          phases = {
            { key = "source", prompt = "Select source commit" },
            { key = "destination", prompt = "Select destination commit" }
          }
        }
      }
      
      local is_valid, errors = command_context.validate_command_definition(command_def)
      
      assert.is_true(is_valid)
      assert.are.equal(0, #errors)
    end)
  end)

  describe("backward compatibility", function()
    it("should work with existing commands that have no phases", function()
      local legacy_command = {
        quick_action = {
          cmd = "describe",
          args = {},
          keymap = "d",
          description = "Edit description"
        }
      }
      
      local processed = command_context.process_command_definition("describe", legacy_command)
      
      assert.are.equal(types.CommandTypes.IMMEDIATE, processed.command_type)
      assert.is_nil(processed.phases)
    end)

    it("should preserve all existing command properties", function()
      local original_command = {
        quick_action = {
          cmd = "abandon",
          args = { "{change_id}" },
          keymap = "a",
          description = "Abandon selected change",
          confirm = true
        },
        menu = {
          keymap = "A",
          title = "Abandon Options",
          options = {}
        }
      }
      
      local processed = command_context.process_command_definition("abandon", original_command)
      
      assert.are.equal("abandon", processed.quick_action.cmd)
      assert.are.equal("a", processed.quick_action.keymap)
      assert.is_true(processed.quick_action.confirm)
      assert.are.equal("Abandon Options", processed.menu.title)
    end)
  end)
end)