-- Tests for jj command execution framework
local helpers = require("tests.helpers.vim_mock")

describe("jj command execution framework", function()
  local commands
  local mock_executor
  local mock_parser

  before_each(function()
    -- Reset modules
    package.loaded["jj.command_execution"] = nil
    package.loaded["jj.log.executor"] = nil
    package.loaded["jj.log.parser"] = nil
    
    -- Mock dependencies
    mock_executor = {
      execute_jj_command = function(cmd) 
        return { success = true, output = "mocked output for: " .. cmd }
      end
    }
    
    mock_parser = {
      extract_basic_commit_info = function(line)
        if line:match("commit_123") then
          return {
            commit_id = "commit_123"
          }
        end
        return nil
      end
    }
    
    package.loaded["jj.log.executor"] = mock_executor
    package.loaded["jj.log.parser"] = mock_parser
    
    commands = require("jj.command_execution")
  end)

  describe("command registry", function()
    it("should register a command definition", function()
      local cmd_def = {
        quick_action = {
          cmd = "new",
          args = {},
          description = "Create new commit"
        }
      }
      
      commands.register_command("new", cmd_def)
      local registered = commands.get_command("new")
      
      assert.is_not_nil(registered)
      assert.are.equal("new", registered.quick_action.cmd)
      assert.are.equal("Create new commit", registered.quick_action.description)
    end)
    
    it("should validate command definitions", function()
      local invalid_cmd = {
        quick_action = {
          -- missing required cmd field
          args = {},
          description = "Invalid command"
        }
      }
      
      local success = commands.register_command("invalid", invalid_cmd)
      assert.is_false(success)
    end)
    
    it("should merge user commands with defaults", function()
      -- Set up default command
      local default_cmd = {
        quick_action = {
          cmd = "new",
          args = {},
          description = "Default new commit"
        }
      }
      commands.register_command("new", default_cmd)
      
      -- Override with user command
      local user_cmd = {
        quick_action = {
          cmd = "new",
          args = {"-m", "Custom message"},
          description = "User new commit"
        }
      }
      
      commands.merge_user_commands({ new = user_cmd })
      local merged = commands.get_command("new")
      
      assert.are.equal("User new commit", merged.quick_action.description)
      assert.are.same({"-m", "Custom message"}, merged.quick_action.args)
    end)
  end)

  describe("parameter substitution", function()
    it("should substitute {commit_id} with context", function()
      local args = {"rebase", "-d", "{commit_id}"}
      local context = {
        commit_id = "commit_123",
        change_id = "commit_123"
      }
      
      local result = commands.substitute_parameters(args, context)
      assert.are.same({"rebase", "-d", "commit_123"}, result)
    end)
    
    it("should substitute {change_id} with context", function()
      local args = {"abandon", "{change_id}"}
      local context = {
        commit_id = "commit_123",
        change_id = "commit_123"
      }
      
      local result = commands.substitute_parameters(args, context)
      assert.are.same({"abandon", "commit_123"}, result)
    end)
    
    it("should handle multiple parameter types in single command", function()
      local args = {"rebase", "-d", "{commit_id}", "--source", "{change_id}"}
      local context = {
        commit_id = "commit_123",
        change_id = "commit_123"
      }
      
      local result = commands.substitute_parameters(args, context)
      assert.are.same({"rebase", "-d", "commit_123", "--source", "commit_123"}, result)
    end)
    
    it("should use fallback values when context is missing", function()
      local args = {"new", "{commit_id}"}
      local context = {} -- empty context
      
      local result = commands.substitute_parameters(args, context)
      assert.are.same({"new", "@"}, result) -- @ is fallback for missing commit_id
    end)
    
    it("should handle {user_input} parameter", function()
      -- Mock vim.fn.input
      helpers.mock_vim_fn_input("test message")
      
      local args = {"new", "-m", "{user_input}"}
      local context = {}
      
      local result = commands.substitute_parameters(args, context)
      assert.are.same({"new", "-m", "test message"}, result)
    end)
    
    it("should skip {user_input} when user provides empty input", function()
      -- Mock vim.fn.input to return empty string
      helpers.mock_vim_fn_input("")
      
      local args = {"new", "-m", "{user_input}", "additional_arg"}
      local context = {}
      
      local result = commands.substitute_parameters(args, context)
      assert.are.same({"new", "-m", "additional_arg"}, result)
    end)
  end)

  describe("context detection", function()
    it("should extract context from cursor position", function()
      -- Mock vim.api.nvim_get_current_line
      helpers.mock_current_line("  commit_123 change_456 Test commit message")
      
      local context = commands.get_command_context()
      
      assert.are.equal("commit_123", context.commit_id)
      assert.are.equal("commit_123", context.change_id) -- Same as commit_id for now
      assert.is_not_nil(context.line_content)
    end)
    
    it("should use fallback when cursor is on invalid line", function()
      -- Mock vim.api.nvim_get_current_line with invalid line
      helpers.mock_current_line("invalid line content")
      
      local context = commands.get_command_context()
      
      assert.are.equal("@", context.commit_id) -- fallback to working copy
      assert.are.equal("@", context.change_id)
    end)
  end)

  describe("command execution", function()
    it("should execute command with parameter substitution", function()
      local cmd_def = {
        quick_action = {
          cmd = "rebase",
          args = {"-d", "{commit_id}"},
          description = "Rebase onto commit"
        }
      }
      commands.register_command("rebase", cmd_def)
      
      local context = {
        commit_id = "commit_123",
        change_id = "commit_123"
      }
      
      local result = commands.execute_command("rebase", "quick_action", context)
      
      assert.is_true(result.success)
      assert.is_not_nil(result.output)
    end)
    
    it("should handle command execution errors", function()
      -- Mock executor to return failure
      mock_executor.execute_jj_command = function(cmd)
        return { 
          success = false, 
          error = "Command failed: " .. cmd 
        }
      end
      
      local cmd_def = {
        quick_action = {
          cmd = "invalid",
          args = {},
          description = "Invalid command"
        }
      }
      commands.register_command("invalid", cmd_def)
      
      local result = commands.execute_command("invalid", "quick_action", {})
      
      assert.is_false(result.success)
      assert.is_not_nil(result.error)
    end)
    
    it("should validate command exists before execution", function()
      local result = commands.execute_command("nonexistent", "quick_action", {})
      
      assert.is_false(result.success)
      assert.matches("Command 'nonexistent' not found", result.error)
    end)
    
    it("should validate action type exists", function()
      local cmd_def = {
        quick_action = {
          cmd = "new",
          args = {},
          description = "Create new commit"
        }
      }
      commands.register_command("new", cmd_def)
      
      local result = commands.execute_command("new", "invalid_action", {})
      
      assert.is_false(result.success)
      assert.matches("Action type 'invalid_action' not found", result.error)
    end)
  end)

  describe("integration with existing systems", function()
    it("should integrate with existing executor module", function()
      -- This test verifies that we properly call the existing executor
      local executed_command = nil
      mock_executor.execute_jj_command = function(cmd)
        executed_command = cmd
        return { success = true, output = "success" }
      end
      
      local cmd_def = {
        quick_action = {
          cmd = "new",
          args = {"-m", "test"},
          description = "Create new commit with message"
        }
      }
      commands.register_command("new", cmd_def)
      
      commands.execute_command("new", "quick_action", {})
      
      assert.are.equal("new -m test", executed_command)
    end)
    
    it("should preserve existing executor error handling", function()
      -- Mock executor to return queued command (from command_queue integration)
      mock_executor.execute_jj_command = function(cmd)
        return { 
          success = false, 
          error = "Command queued - refresh in progress",
          queued = true
        }
      end
      
      local cmd_def = {
        quick_action = {
          cmd = "new",
          args = {},
          description = "Create new commit"
        }
      }
      commands.register_command("new", cmd_def)
      
      local result = commands.execute_command("new", "quick_action", {})
      
      assert.is_false(result.success)
      assert.is_true(result.queued)
      assert.matches("queued", result.error)
    end)
  end)
end)