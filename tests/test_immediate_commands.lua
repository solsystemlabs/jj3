-- Test immediate command execution for jj.nvim
local helpers = require("helpers.vim_mock")

describe("Immediate Command Execution", function()
  local default_commands
  local keybindings
  local mock_executor

  before_each(function()
    -- Reset modules
    package.loaded["jj.default_commands"] = nil
    package.loaded["jj.keybindings"] = nil
    package.loaded["jj.log.executor"] = nil
    package.loaded["jj.selection_navigation"] = nil
    package.loaded["jj.command_execution"] = nil
    package.loaded["jj.command_context"] = nil
    
    -- Add missing API functions to vim mock
    vim.api.nvim_get_current_buf = function() return 1 end
    vim.api.nvim_win_get_cursor = function(win) 
      return {1, 0} -- line 1, column 0
    end
    
    -- Mock executor
    mock_executor = {
      execute_jj_command = function(cmd)
        return { success = true, output = "mocked execution: " .. cmd }
      end
    }
    
    -- Mock selection navigation
    package.loaded["jj.selection_navigation"] = {
      get_commit_id_at_cursor = function(bufnr, line_number)
        return "abc123def456"
      end
    }
    
    -- Mock command execution module
    package.loaded["jj.command_execution"] = {
      register_command = function(name, definition) end,
      get_command = function(name)
        return default_commands.get_command_definition(name)
      end
    }
    
    -- Mock command context module  
    package.loaded["jj.command_context"] = {
      register_command = function(name, definition) end
    }
    
    package.loaded["jj.log.executor"] = mock_executor
    default_commands = require("jj.default_commands")
    keybindings = require("jj.keybindings")
  end)

  describe("Command Phase Detection", function()
    it("should detect commands without phases as immediate", function()
      local abandon_def = default_commands.get_command_definition("abandon")
      assert.is_not_nil(abandon_def)
      assert.is_not_nil(abandon_def.quick_action)
      
      -- Should not have phases
      assert.is_nil(abandon_def.quick_action.phases)
    end)

    it("should detect NEW quick action as immediate (no phases)", function()
      local new_def = default_commands.get_command_definition("new")
      assert.is_not_nil(new_def)
      assert.is_not_nil(new_def.quick_action)
      
      -- Quick action should not have phases  
      assert.is_nil(new_def.quick_action.phases)
    end)

    it("should detect NEW menu options as having phases", function()
      local new_def = default_commands.get_command_definition("new")
      local multi_parent_option = new_def.menu.options[1]
      
      -- Menu option should have phases
      assert.is_not_nil(multi_parent_option.phases)
      assert.equals(1, #multi_parent_option.phases)
    end)
  end)

  describe("Cursor Context", function()
    it("should get commit ID from cursor position", function()
      -- Mock the selection navigation function
      package.loaded["jj.selection_navigation"] = {
        get_commit_id_at_cursor = function(bufnr, line_number)
          return "abc123def456"
        end
      }
      
      local context = keybindings._get_current_cursor_context()
      
      assert.equals("abc123def456", context.commit_id)
      assert.equals("abc123def456", context.change_id)
      assert.equals("abc123def456", context.target)
    end)

    it("should handle no commit ID on cursor line", function()
      -- Mock the selection navigation function to return nil
      package.loaded["jj.selection_navigation"] = {
        get_commit_id_at_cursor = function(bufnr, line_number)
          return nil
        end
      }
      
      local context = keybindings._get_current_cursor_context()
      
      -- Should return empty table
      assert.same({}, context)
    end)
  end)

  describe("Command Arguments", function()
    it("should use change_id for immediate commands", function()
      local abandon_def = default_commands.get_command_definition("abandon")
      local args = abandon_def.quick_action.args
      
      assert.equals(1, #args)
      assert.equals("{change_id}", args[1])
    end)

    it("should use change_id for NEW quick action", function()
      local new_def = default_commands.get_command_definition("new")
      local args = new_def.quick_action.args
      
      assert.equals(3, #args)
      assert.equals("-m", args[1])
      assert.equals("{user_input}", args[2])
      assert.equals("{change_id}", args[3])
    end)
  end)
end)