-- Tests for selection workflow integration with existing command system
require("tests.helpers.vim_mock")

local selection_integration = require("jj.selection_integration")
local selection_navigation = require("jj.selection_navigation")
local command_context = require("jj.command_context")
local default_commands = require("jj.default_commands")
local types = require("jj.types")

describe("selection workflow integration", function()
  local mock_bufnr = 1
  local mock_winnr = 1000

  before_each(function()
    -- Reset all systems
    selection_integration._reset_for_testing()
    selection_navigation._reset_for_testing()
    command_context._reset_for_testing()
    
    -- Mock vim APIs
    vim.api.nvim_get_current_buf = function()
      return mock_bufnr
    end
    
    vim.api.nvim_get_current_win = function()
      return mock_winnr
    end
    
    vim.api.nvim_win_get_cursor = function(winnr)
      return {1, 0}
    end
    
    vim.api.nvim_buf_get_lines = function(bufnr, start, end_line, strict_indexing)
      return {
        "@  abc123  Current commit",
        "○  def456  Previous commit", 
        "○  ghi789  Older commit"
      }
    end
    
    -- Mock command execution
    local executor = require("jj.log.executor")
    executor.execute_jj_command = function(command)
      return { success = true, output = "Command executed: " .. command }
    end
    
    -- Mock additional vim APIs needed by visual feedback
    vim.api.nvim_create_buf = function(listed, scratch)
      return mock_bufnr + 10
    end
    
    vim.api.nvim_open_win = function(bufnr, enter, config)
      return mock_winnr + 10
    end
    
    vim.api.nvim_win_close = function(winnr, force) end
    vim.api.nvim_buf_set_lines = function(bufnr, start, end_line, strict_indexing, replacement) end
    vim.api.nvim_win_get_config = function(winnr) return { row = 0, col = 0 } end
    vim.api.nvim_buf_set_option = function(bufnr, name, value) end
    vim.api.nvim_win_set_config = function(winnr, config) end
    vim.api.nvim_buf_add_highlight = function(bufnr, ns_id, hl_group, line, col_start, col_end) end
    vim.api.nvim_buf_clear_namespace = function(bufnr, ns_id, start, end_line) end
    vim.keymap.set = function(mode, lhs, rhs, opts) end
    vim.keymap.del = function(mode, lhs, opts) end
  end)

  describe("command triggering", function()
    it("should start selection workflow for commands requiring targets", function()
      -- Register a selection-aware command
      command_context.register_command("test_squash", {
        quick_action = {
          cmd = "squash",
          args = { "--into", "{target}" },
          keymap = "s",
          description = "Squash current working copy into selected",
          phases = {
            { key = "target", prompt = "Select target commit to squash into" }
          }
        }
      })
      
      local result = selection_integration.execute_command("test_squash", mock_bufnr)
      
      assert.is_true(result.requires_selection)
      assert.is_true(selection_navigation.is_selection_mode_enabled(mock_bufnr))
    end)

    it("should execute immediate commands without selection", function()
      command_context.register_command("test_describe", {
        quick_action = {
          cmd = "describe",
          args = {},
          keymap = "d",
          description = "Edit description of current commit"
        }
      })
      
      local result = selection_integration.execute_command("test_describe", mock_bufnr)
      
      assert.is_false(result.requires_selection)
      assert.is_true(result.success)
      assert.is_false(selection_navigation.is_selection_mode_enabled(mock_bufnr))
    end)

    it("should handle unknown commands gracefully", function()
      local result = selection_integration.execute_command("nonexistent_command", mock_bufnr)
      
      assert.is_false(result.success)
      assert.is_not_nil(result.error)
    end)
  end)

  describe("selection workflow completion", function()
    it("should execute command after selection is complete", function()
      -- Register command
      command_context.register_command("test_squash", {
        quick_action = {
          cmd = "squash",
          args = { "--into", "{target}" },
          phases = {
            { key = "target", prompt = "Select target commit" }
          }
        }
      })
      
      -- Start selection
      selection_integration.execute_command("test_squash", mock_bufnr)
      
      -- Complete selection workflow by simulating space key
      vim.api.nvim_win_get_cursor = function(winnr) return {2, 0} end -- def456
      selection_navigation.handle_selection_key(mock_bufnr)
      
      -- Force workflow completion (in real implementation this would be automatic)
      selection_integration._force_workflow_completion(mock_bufnr)
      
      -- Verify command was executed
      local execution_history = selection_integration.get_execution_history()
      assert.are.equal(1, #execution_history)
      assert.are.equal("squash --into def456", execution_history[1].command)
    end)

    it("should handle multi-phase command execution", function()
      command_context.register_command("test_rebase", {
        quick_action = {
          cmd = "rebase",
          args = { "--source", "{source}", "--destination", "{destination}" },
          phases = {
            { key = "source", prompt = "Select source commit" },
            { key = "destination", prompt = "Select destination commit" }
          }
        }
      })
      
      -- Start selection
      selection_integration.execute_command("test_rebase", mock_bufnr)
      
      -- Select source (line 1 = abc123)
      vim.api.nvim_win_get_cursor = function(winnr) return {1, 0} end
      selection_navigation.handle_selection_key(mock_bufnr)
      
      -- Select destination (line 2 = def456)
      vim.api.nvim_win_get_cursor = function(winnr) return {2, 0} end
      selection_navigation.handle_selection_key(mock_bufnr)
      
      -- Force workflow completion
      selection_integration._force_workflow_completion(mock_bufnr)
      
      -- Verify command was executed with both selections
      local execution_history = selection_integration.get_execution_history()
      assert.are.equal(1, #execution_history)
      assert.are.equal("rebase --source abc123 --destination def456", execution_history[1].command)
    end)

    it("should handle multi-select command execution", function()
      command_context.register_command("test_abandon", {
        quick_action = {
          cmd = "abandon",
          args = { "{targets}" },
          phases = {
            { key = "targets", prompt = "Select commits to abandon", multi_select = true }
          }
        }
      })
      
      -- Start selection
      selection_integration.execute_command("test_abandon", mock_bufnr)
      
      -- Select multiple commits
      vim.api.nvim_win_get_cursor = function(winnr) return {1, 0} end -- abc123
      selection_navigation.handle_selection_key(mock_bufnr)
      
      vim.api.nvim_win_get_cursor = function(winnr) return {2, 0} end -- def456
      selection_navigation.handle_selection_key(mock_bufnr)
      
      -- Confirm selection
      selection_navigation.handle_confirmation_key(mock_bufnr)
      
      -- Force workflow completion
      selection_integration._force_workflow_completion(mock_bufnr)
      
      -- Verify command was executed with multiple targets
      local execution_history = selection_integration.get_execution_history()
      assert.are.equal(1, #execution_history)
      assert.are.equal("abandon abc123 def456", execution_history[1].command)
    end)
  end)

  describe("enhanced default commands", function()
    it("should enhance existing squash command with selection", function()
      selection_integration.enhance_default_commands()
      
      local enhanced_squash = command_context.get_command_definition("squash_into_selected")
      assert.is_not_nil(enhanced_squash)
      assert.are.equal(types.CommandTypes.SINGLE_TARGET, enhanced_squash.command_type)
      assert.are.equal("target", enhanced_squash.phases[1].key)
    end)

    it("should preserve existing immediate commands", function()
      selection_integration.enhance_default_commands()
      
      local describe_command = command_context.get_command_definition("describe_current")
      assert.is_not_nil(describe_command)
      assert.are.equal(types.CommandTypes.IMMEDIATE, describe_command.command_type)
    end)

    it("should provide enhanced rebase commands", function()
      selection_integration.enhance_default_commands()
      
      local rebase_command = command_context.get_command_definition("rebase_multi_phase")
      assert.is_not_nil(rebase_command)
      assert.are.equal(types.CommandTypes.MULTI_PHASE, rebase_command.command_type)
      assert.are.equal(2, #rebase_command.phases)
    end)
  end)

  describe("error handling", function()
    it("should handle jj command execution failures", function()
      -- Mock command execution failure
      local executor = require("jj.log.executor")
      executor.execute_jj_command = function(command)
        return { success = false, error = "jj command failed" }
      end
      
      command_context.register_command("test_fail", {
        quick_action = {
          cmd = "test",
          args = { "{target}" },
          phases = {
            { key = "target", prompt = "Select target" }
          }
        }
      })
      
      -- Start selection and complete it
      selection_integration.execute_command("test_fail", mock_bufnr)
      vim.api.nvim_win_get_cursor = function(winnr) return {1, 0} end
      selection_navigation.handle_selection_key(mock_bufnr)
      
      -- Force workflow completion
      selection_integration._force_workflow_completion(mock_bufnr)
      
      -- Verify error was handled
      local execution_history = selection_integration.get_execution_history()
      assert.are.equal(1, #execution_history)
      assert.is_false(execution_history[1].success)
      assert.is_not_nil(execution_history[1].error)
    end)

    it("should handle selection cancellation gracefully", function()
      command_context.register_command("test_cancel", {
        quick_action = {
          cmd = "test",
          args = { "{target}" },
          phases = {
            { key = "target", prompt = "Select target" }
          }
        }
      })
      
      -- Start selection
      selection_integration.execute_command("test_cancel", mock_bufnr)
      assert.is_true(selection_navigation.is_selection_mode_enabled(mock_bufnr))
      
      -- Cancel selection
      selection_navigation.handle_cancellation_key(mock_bufnr)
      
      -- Verify cleanup
      assert.is_false(selection_navigation.is_selection_mode_enabled(mock_bufnr))
      
      -- Verify no command was executed
      local execution_history = selection_integration.get_execution_history()
      assert.are.equal(0, #execution_history)
    end)

    it("should handle invalid selection scenarios", function()
      command_context.register_command("test_invalid", {
        quick_action = {
          cmd = "test",
          args = { "{target}" },
          phases = {
            { key = "target", prompt = "Select target" }
          }
        }
      })
      
      -- Start selection
      selection_integration.execute_command("test_invalid", mock_bufnr)
      
      -- Try to select from a line with no commit ID
      vim.api.nvim_buf_get_lines = function(bufnr, start, end_line, strict_indexing)
        return {"│ This line has no commit ID"}
      end
      
      vim.api.nvim_win_get_cursor = function(winnr) return {1, 0} end
      local result = selection_navigation.handle_selection_key(mock_bufnr)
      
      assert.is_false(result)
      -- Should still be in selection mode
      assert.is_true(selection_navigation.is_selection_mode_enabled(mock_bufnr))
    end)
  end)

  describe("menu integration", function()
    it("should integrate selection commands into menu system", function()
      selection_integration.enhance_default_commands()
      
      -- Test that enhanced commands can be accessed through existing menu system
      local menu_commands = selection_integration.get_menu_compatible_commands()
      
      assert.is_true(#menu_commands > 0)
      
      -- Check that selection-aware commands are included
      local has_selection_command = false
      for _, cmd in ipairs(menu_commands) do
        if cmd.requires_selection then
          has_selection_command = true
          break
        end
      end
      
      assert.is_true(has_selection_command)
    end)

    it("should provide command descriptions for menu display", function()
      selection_integration.enhance_default_commands()
      
      local squash_cmd = command_context.get_command_definition("squash_into_selected")
      assert.is_not_nil(squash_cmd.quick_action.description)
      assert.is_true(squash_cmd.quick_action.description:find("selected") ~= nil)
    end)
  end)

  describe("workflow state management", function()
    it("should track active selection workflows", function()
      command_context.register_command("test_track", {
        quick_action = {
          cmd = "test",
          args = { "{target}" },
          phases = { { key = "target", prompt = "Select target" } }
        }
      })
      
      assert.are.equal(0, #selection_integration.get_active_workflows())
      
      selection_integration.execute_command("test_track", mock_bufnr)
      
      assert.are.equal(1, #selection_integration.get_active_workflows())
      
      -- Complete selection
      vim.api.nvim_win_get_cursor = function(winnr) return {1, 0} end
      selection_navigation.handle_selection_key(mock_bufnr)
      
      assert.are.equal(0, #selection_integration.get_active_workflows())
    end)

    it("should handle multiple concurrent selections in different buffers", function()
      local buffer1 = 1
      local buffer2 = 2
      
      command_context.register_command("test_concurrent", {
        quick_action = {
          cmd = "test",
          args = { "{target}" },
          phases = { { key = "target", prompt = "Select target" } }
        }
      })
      
      -- Start selection in buffer 1
      selection_integration.execute_command("test_concurrent", buffer1)
      
      -- Start selection in buffer 2
      selection_integration.execute_command("test_concurrent", buffer2)
      
      -- Both should be active
      assert.are.equal(2, #selection_integration.get_active_workflows())
      
      -- Complete one selection
      vim.api.nvim_get_current_buf = function() return buffer1 end
      vim.api.nvim_win_get_cursor = function(winnr) return {1, 0} end
      selection_navigation.handle_selection_key(buffer1)
      
      -- Should have one remaining
      assert.are.equal(1, #selection_integration.get_active_workflows())
    end)
  end)
end)