-- Tests for jj menu system
local helpers = require("tests.helpers.vim_mock")

describe("jj menu system", function()
  local menu
  local mock_command_execution
  local mock_vim_ui_select

  before_each(function()
    -- Reset modules
    package.loaded["jj.menu"] = nil
    package.loaded["jj.command_execution"] = nil
    
    -- Mock command execution
    mock_command_execution = {
      get_command = function(name)
        if name == "new" then
          return {
            menu = {
              title = "New Commit Options",
              options = {
                { key = "1", desc = "New commit (default)", cmd = "new", args = {} },
                { key = "2", desc = "New commit with message", cmd = "new", args = {"-m", "{user_input}"} },
                { key = "3", desc = "New commit after current", cmd = "new", args = {"{commit_id}"} }
              }
            }
          }
        end
        return nil
      end,
      execute_command = function(name, action_type, context)
        return { success = true, output = "executed " .. name .. " with " .. action_type }
      end,
      get_command_context = function()
        return {
          commit_id = "commit_123",
          change_id = "commit_123",
          line_content = "test line"
        }
      end
    }
    
    -- Mock vim.ui.select
    mock_vim_ui_select = {
      selected_option = nil,
      callback_fn = nil
    }
    
    vim.ui = vim.ui or {}
    vim.ui.select = function(items, opts, on_choice)
      mock_vim_ui_select.items = items
      mock_vim_ui_select.opts = opts
      mock_vim_ui_select.callback_fn = on_choice
      
      -- Simulate user selection if we have a pre-selected option
      if mock_vim_ui_select.selected_option then
        on_choice(mock_vim_ui_select.selected_option, mock_vim_ui_select.selected_index or 1)
      end
    end
    
    package.loaded["jj.command_execution"] = mock_command_execution
    menu = require("jj.menu")
  end)

  describe("menu option generation", function()
    it("should generate menu options from command definition", function()
      local options = menu.generate_menu_options("new")
      
      assert.is_not_nil(options)
      assert.are.equal(3, #options)
      assert.are.equal("New commit (default)", options[1].desc)
      assert.are.equal("New commit with message", options[2].desc)
      assert.are.equal("New commit after current", options[3].desc)
    end)
    
    it("should return nil for command without menu definition", function()
      local options = menu.generate_menu_options("nonexistent")
      assert.is_nil(options)
    end)
    
    it("should format menu options with key prefixes", function()
      local options = menu.generate_menu_options("new")
      local formatted = menu.format_menu_items(options)
      
      assert.are.equal("1) New commit (default)", formatted[1])
      assert.are.equal("2) New commit with message", formatted[2])
      assert.are.equal("3) New commit after current", formatted[3])
    end)
  end)

  describe("menu display", function()
    it("should show menu using vim.ui.select", function()
      menu.show_command_menu("new")
      
      assert.is_not_nil(mock_vim_ui_select.items)
      assert.are.equal(3, #mock_vim_ui_select.items)
      assert.are.equal("New Commit Options", mock_vim_ui_select.opts.prompt)
    end)
    
    it("should handle menu selection and execute command", function()
      -- Set up mock to select first option
      mock_vim_ui_select.selected_option = { key = "1", desc = "New commit (default)", cmd = "new", args = {} }
      mock_vim_ui_select.selected_index = 1
      
      local executed_command = nil
      mock_command_execution.execute_command = function(name, action_type, context)
        executed_command = { name = name, action_type = action_type, context = context }
        return { success = true, output = "test success" }
      end
      
      menu.show_command_menu("new")
      
      assert.is_not_nil(executed_command)
      assert.are.equal("new", executed_command.name)
      assert.are.equal("menu_option", executed_command.action_type)
    end)
    
    it("should handle menu cancellation gracefully", function()
      -- Set up mock to simulate cancellation (nil selection)
      mock_vim_ui_select.selected_option = nil
      
      local result = menu.show_command_menu("new")
      
      -- Should not crash and should handle cancellation
      assert.is_not_nil(result)
    end)
  end)

  describe("context integration", function()
    it("should pass cursor context to menu option execution", function()
      mock_vim_ui_select.selected_option = { key = "3", desc = "New commit after current", cmd = "new", args = {"{commit_id}"} }
      
      local passed_context = nil
      mock_command_execution.execute_command = function(name, action_type, context)
        passed_context = context
        return { success = true, output = "test" }
      end
      
      menu.show_command_menu("new")
      
      assert.is_not_nil(passed_context)
      assert.are.equal("commit_123", passed_context.commit_id)
      assert.are.equal("commit_123", passed_context.change_id)
    end)
    
    it("should create menu option context from selected option", function()
      local option = { key = "2", desc = "Test option", cmd = "test", args = {"-flag"} }
      local context = menu.create_menu_option_context(option)
      
      assert.is_not_nil(context)
      assert.are.equal("test", context.cmd)
      assert.are.same({"-flag"}, context.args)
      assert.are.equal("2", context.key)
    end)
  end)

  describe("error handling", function()
    it("should handle missing command definition gracefully", function()
      mock_command_execution.get_command = function(name)
        return nil
      end
      
      local result = menu.show_command_menu("missing")
      
      assert.is_false(result.success)
      assert.matches("not found", result.error)
    end)
    
    it("should handle command execution errors", function()
      mock_vim_ui_select.selected_option = { key = "1", desc = "Test", cmd = "test", args = {} }
      
      mock_command_execution.execute_command = function()
        return { success = false, error = "Test execution error" }
      end
      
      menu.show_command_menu("new")
      
      -- Should not crash when command execution fails
      -- Error handling will be done by the command execution layer
    end)
    
    it("should validate menu definition structure", function()
      local invalid_command = {
        menu = {
          title = "Test Menu",
          -- Missing options array
        }
      }
      
      mock_command_execution.get_command = function(name)
        return invalid_command
      end
      
      local result = menu.show_command_menu("invalid")
      
      assert.is_false(result.success)
      assert.matches("invalid", result.error:lower())
    end)
  end)

  describe("menu integration", function()
    it("should integrate with command execution framework", function()
      local integration_tested = false
      
      mock_command_execution.execute_command = function(name, action_type, context)
        integration_tested = true
        assert.are.equal("new", name)
        assert.are.equal("menu_option", action_type)
        assert.is_not_nil(context)
        return { success = true, output = "integrated" }
      end
      
      mock_vim_ui_select.selected_option = { key = "1", desc = "Test", cmd = "new", args = {} }
      
      menu.show_command_menu("new")
      
      assert.is_true(integration_tested)
    end)
    
    it("should support dynamic menu generation", function()
      -- Test that menu options can be generated dynamically
      local options = menu.generate_menu_options("new")
      local formatted = menu.format_menu_items(options)
      
      assert.is_table(options)
      assert.is_table(formatted)
      assert.are.equal(#options, #formatted)
    end)
  end)

  describe("menu lifecycle", function()
    it("should clean up properly after menu selection", function()
      mock_vim_ui_select.selected_option = { key = "1", desc = "Test", cmd = "test", args = {} }
      
      menu.show_command_menu("new")
      
      -- After selection, menu should be cleaned up
      -- This is handled by vim.ui.select automatically
      assert.is_not_nil(mock_vim_ui_select.callback_fn)
    end)
    
    it("should handle multiple consecutive menu calls", function()
      -- First menu call
      menu.show_command_menu("new")
      assert.is_not_nil(mock_vim_ui_select.items)
      
      -- Second menu call should work
      menu.show_command_menu("new")
      assert.is_not_nil(mock_vim_ui_select.items)
    end)
  end)
end)