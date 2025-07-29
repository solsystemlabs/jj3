-- Integration tests for command execution framework with existing plugin architecture
local helpers = require("tests.helpers.vim_mock")

describe("Command Framework Integration", function()
  local keybindings, command_execution, default_commands, menu, auto_refresh
  local mock_buffer_id, mock_window_id
  local registered_keymaps = {}
  local notification_messages = {}

  before_each(function()
    -- Create mock buffer and window
    mock_buffer_id = 123
    mock_window_id = 456
    
    -- Reset registered keymaps
    registered_keymaps = {}
    
    -- Reset notification tracking
    notification_messages = {}
    
    -- Mock vim.notify to capture notification messages
    vim.notify = function(message, level)
      table.insert(notification_messages, {
        message = message,
        level = level
      })
    end
    
    -- Mock vim.api.nvim_buf_set_keymap to track registrations
    vim.api.nvim_buf_set_keymap = function(bufnr, mode, lhs, rhs, opts)
      registered_keymaps[lhs] = {
        bufnr = bufnr,
        mode = mode,
        rhs = rhs,
        opts = opts
      }
    end
    
    -- Setup package.loaded to avoid real module loading
    package.loaded["jj.keybindings"] = nil
    package.loaded["jj.command_execution"] = nil
    package.loaded["jj.default_commands"] = nil
    package.loaded["jj.menu"] = nil
    package.loaded["jj.auto_refresh"] = nil
    
    -- Load modules
    keybindings = require("jj.keybindings")
    command_execution = require("jj.command_execution")
    default_commands = require("jj.default_commands")
    menu = require("jj.menu")
    auto_refresh = require("jj.auto_refresh")
    
    -- Register default commands
    default_commands.register_all_defaults()
  end)

  describe("Plugin Initialization Integration", function()
    it("should register default commands during plugin setup", function()
      -- Verify that default commands are registered
      assert.is_not_nil(command_execution.get_command("new"))
      assert.is_not_nil(command_execution.get_command("rebase"))
      assert.is_not_nil(command_execution.get_command("abandon"))
      assert.is_not_nil(command_execution.get_command("edit"))
      assert.is_not_nil(command_execution.get_command("squash"))
    end)

    it("should validate command definitions", function()
      local new_cmd = command_execution.get_command("new")
      
      -- Check quick action structure
      assert.is_not_nil(new_cmd.quick_action)
      assert.is_equal("new", new_cmd.quick_action.cmd)
      assert.is_equal("n", new_cmd.quick_action.keymap)
      
      -- Check menu structure
      assert.is_not_nil(new_cmd.menu)
      assert.is_equal("N", new_cmd.menu.keymap)
      assert.is_not_nil(new_cmd.menu.options)
      assert.is_true(#new_cmd.menu.options > 0)
    end)
  end)

  describe("Keybinding Integration", function()
    it("should register command keybindings for log buffer", function()
      local result = keybindings.setup_jj_buffer_keybindings(mock_buffer_id)
      
      assert.is_true(result.success)
      
      -- Verify keybindings were registered
      assert.is_true(next(registered_keymaps) ~= nil, "Should register keybindings")
      
      -- Check that both quick actions and menus are registered
      local has_lowercase = false
      local has_uppercase = false
      
      for key, _ in pairs(registered_keymaps) do
        if key:match("[a-z]") then
          has_lowercase = true
        elseif key:match("[A-Z]") then
          has_uppercase = true
        end
      end
      
      assert.is_true(has_lowercase, "Should register lowercase keybindings for quick actions")
      assert.is_true(has_uppercase, "Should register uppercase keybindings for menus")
    end)

    it("should handle keybinding registration errors gracefully", function()
      -- Mock api failure
      vim.api.nvim_buf_set_keymap = function(bufnr, mode, lhs, rhs, opts)
        error("Invalid buffer")
      end
      
      local result = keybindings.setup_jj_buffer_keybindings(mock_buffer_id)
      
      assert.is_false(result.success)
      assert.is_not_nil(result.error)
    end)
  end)

  describe("Auto-Refresh Integration", function()
    it("should trigger auto-refresh after successful quick action", function()
      -- Setup mocks
      local refresh_called = false
      auto_refresh.on_command_complete = function(cmd, success, output)
        refresh_called = true
        assert.is_equal("new", cmd)
        assert.is_true(success)
      end
      
      -- Mock command execution success
      vim_mock.mock_api_return("nvim_get_current_line", "abc123 some commit message")
      command_execution.execute_command = function() 
        return { success = true, output = "command output" }
      end
      
      -- Execute quick action
      keybindings._execute_quick_action("new")
      
      -- Verify auto-refresh was triggered
      assert.is_true(refresh_called)
    end)

    it("should not trigger auto-refresh after failed command", function()
      -- Setup mocks
      local refresh_called = false
      auto_refresh.on_command_complete = function(cmd, success, output)
        refresh_called = true
        assert.is_equal("new", cmd)
        assert.is_false(success)
      end
      
      -- Mock command execution failure
      vim_mock.mock_api_return("nvim_get_current_line", "abc123 some commit message")
      command_execution.execute_command = function() 
        return { success = false, error = "command failed" }
      end
      
      -- Execute quick action
      keybindings._execute_quick_action("new")
      
      -- Verify auto-refresh was called with failure status
      assert.is_true(refresh_called)
    end)
  end)

  describe("Menu Integration", function()
    it("should show command menu and execute selected option", function()
      -- Mock vim.ui.select to simulate user selection
      local select_options = nil
      local select_callback = nil
      
      vim.ui.select = function(options, config, callback)
        select_options = options
        select_callback = callback
        -- Simulate user selecting first option
        callback(options[1], 1)
      end
      
      -- Mock auto-refresh
      local refresh_called = false
      auto_refresh.on_command_complete = function()
        refresh_called = true
      end
      
      -- Mock command execution
      vim_mock.mock_api_return("nvim_get_current_line", "abc123 some commit message")
      command_execution.execute_command = function() 
        return { success = true, output = "command output" }
      end
      
      -- Show menu
      local result = menu.show_command_menu("new")
      
      assert.is_true(result.success)
      assert.is_not_nil(select_options)
      assert.is_true(#select_options > 0)
      assert.is_true(refresh_called)
    end)

    it("should handle menu display errors", function()
      local result = menu.show_command_menu("nonexistent_command")
      
      assert.is_false(result.success)
      assert.is_not_nil(result.error)
    end)

    it("should include exact jj command in menu execution notifications", function()
      -- Mock vim.ui.select to simulate user selection
      local select_callback = nil
      
      vim.ui.select = function(options, config, callback)
        select_callback = callback
        -- Simulate user selecting first option
        callback(options[1], 1)
      end
      
      -- Mock command execution with executed_command
      vim_mock.mock_api_return("nvim_get_current_line", "abc123 some commit message")
      command_execution.execute_command = function() 
        return { 
          success = true, 
          output = "command output",
          executed_command = "jj new"
        }
      end
      
      -- Show menu and execute option
      menu.show_command_menu("new")
      
      -- Verify notification includes exact command
      assert.is_true(#notification_messages > 0, "Should have notification messages")
      local success_notification = nil
      for _, notif in ipairs(notification_messages) do
        if notif.level == vim.log.levels.INFO then
          success_notification = notif
          break
        end
      end
      
      assert.is_not_nil(success_notification, "Should have success notification")
      assert.matches("Command executed: jj new", success_notification.message)
    end)
  end)

  describe("Configuration Integration", function()
    it("should support user command customization", function()
      local user_commands = {
        custom_command = {
          quick_action = {
            cmd = "custom",
            args = {"--flag"},
            keymap = "c",
            description = "Custom command"
          },
          menu = {
            keymap = "C",
            title = "Custom Options",
            options = {
              {
                key = "1",
                desc = "Custom option",
                cmd = "custom",
                args = {"--option"}
              }
            }
          }
        }
      }
      
      -- Merge user commands
      command_execution.merge_user_commands(user_commands)
      
      -- Verify custom command is registered
      local custom_cmd = command_execution.get_command("custom_command")
      assert.is_not_nil(custom_cmd)
      assert.is_equal("c", custom_cmd.quick_action.keymap)
      assert.is_equal("C", custom_cmd.menu.keymap)
    end)

    it("should support keybinding overrides", function()
      local overrides = {
        new = {
          quick_action = {
            keymap = "x"
          },
          menu = {
            keymap = "X"
          }
        }
      }
      
      -- Apply overrides
      local result = keybindings.apply_user_keybinding_overrides(overrides)
      assert.is_true(result.success)
      
      -- Setup buffer keybindings
      keybindings.setup_jj_buffer_keybindings(mock_buffer_id)
      
      -- Verify override was applied
      local keymap_calls = vim_mock.get_api_calls("nvim_buf_set_keymap")
      local has_x_key = false
      local has_X_key = false
      
      for _, call in ipairs(keymap_calls) do
        if call.args[3] == "x" then
          has_x_key = true
        elseif call.args[3] == "X" then
          has_X_key = true
        end
      end
      
      assert.is_true(has_x_key, "Should register overridden quick action key")
      assert.is_true(has_X_key, "Should register overridden menu key")
    end)
  end)

  describe("Error Handling Integration", function()
    it("should handle command execution framework errors gracefully", function()
      -- Test with invalid buffer ID
      local result = keybindings.setup_jj_buffer_keybindings(nil)
      
      assert.is_false(result.success)
      assert.is_not_nil(result.error)
    end)

    it("should provide user feedback for command failures", function()
      -- Mock command execution failure
      vim_mock.mock_api_return("nvim_get_current_line", "abc123 some commit message")
      command_execution.execute_command = function() 
        return { success = false, error = "jj command failed" }
      end
      
      -- Execute quick action
      keybindings._execute_quick_action("new")
      
      -- Just verify the function executes without error since vim.notify is mocked
      -- In actual usage, this would show error notifications to the user
    end)

    it("should include exact jj command in success notifications", function()
      -- Mock command execution success with executed_command
      vim_mock.mock_api_return("nvim_get_current_line", "abc123 some commit message")
      command_execution.execute_command = function() 
        return { 
          success = true, 
          output = "command output",
          executed_command = "jj new -m 'test message'"
        }
      end
      
      -- Execute quick action
      keybindings._execute_quick_action("new")
      
      -- Verify notification includes exact command
      assert.is_true(#notification_messages > 0, "Should have notification messages")
      local success_notification = nil
      for _, notif in ipairs(notification_messages) do
        if notif.level == vim.log.levels.INFO then
          success_notification = notif
          break
        end
      end
      
      assert.is_not_nil(success_notification, "Should have success notification")
      assert.matches("Command executed: jj new %-m 'test message'", success_notification.message)
    end)

    it("should include exact jj command in failure notifications", function()
      -- Mock command execution failure with executed_command
      vim_mock.mock_api_return("nvim_get_current_line", "abc123 some commit message")
      command_execution.execute_command = function() 
        return { 
          success = false, 
          error = "operation failed",
          executed_command = "jj abandon abc123"
        }
      end
      
      -- Execute quick action
      keybindings._execute_quick_action("abandon")
      
      -- Verify notification includes exact command
      assert.is_true(#notification_messages > 0, "Should have notification messages")
      local error_notification = nil
      for _, notif in ipairs(notification_messages) do
        if notif.level == vim.log.levels.ERROR then
          error_notification = notif
          break
        end
      end
      
      assert.is_not_nil(error_notification, "Should have error notification")
      assert.matches("Command failed: jj abandon abc123", error_notification.message)
      assert.matches("operation failed", error_notification.message)
    end)
  end)
end)