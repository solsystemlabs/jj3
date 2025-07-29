-- Tests for jj default command set
local helpers = require("tests.helpers.vim_mock")

describe("jj default command set", function()
  local default_commands
  local mock_executor
  local confirmation_responses = {}

  before_each(function()
    -- Reset modules
    package.loaded["jj.default_commands"] = nil
    package.loaded["jj.log.executor"] = nil
    
    -- Reset confirmation responses
    confirmation_responses = {}
    
    -- Mock executor
    mock_executor = {
      execute_jj_command = function(cmd)
        return { success = true, output = "mocked execution: " .. cmd }
      end
    }
    
    -- Mock vim.fn.confirm for destructive operations
    vim.fn.confirm = function(msg, choices, default)
      return confirmation_responses[msg] or default or 1
    end
    
    package.loaded["jj.log.executor"] = mock_executor
    default_commands = require("jj.default_commands")
  end)

  describe("new commit commands", function()
    it("should define new command with quick action and menu", function()
      local new_def = default_commands.get_command_definition("new")
      
      assert.is_not_nil(new_def)
      assert.is_not_nil(new_def.quick_action)
      assert.is_not_nil(new_def.menu)
      
      assert.are.equal("new", new_def.quick_action.cmd)
      assert.are.equal("n", new_def.quick_action.keymap)
      assert.are.equal("N", new_def.menu.keymap)
    end)
    
    it("should provide menu options for new commit variations", function()
      local new_def = default_commands.get_command_definition("new")
      local menu_options = new_def.menu.options
      
      assert.is_table(menu_options)
      assert.is_true(#menu_options >= 3)
      
      -- Should have basic new, new with message, and new after commit options
      local option_descs = {}
      for _, option in ipairs(menu_options) do
        table.insert(option_descs, option.desc:lower())
      end
      
      assert.is_true(vim.tbl_contains(option_descs, "new commit (default)"))
      assert.is_true(vim.tbl_contains(option_descs, "new commit with message"))
      assert.is_true(vim.tbl_contains(option_descs, "new commit after current"))
    end)
    
    it("should support parameter substitution in new command", function()
      local new_def = default_commands.get_command_definition("new")
      local after_current_option = nil
      
      for _, option in ipairs(new_def.menu.options) do
        if option.desc:lower():match("after current") then
          after_current_option = option
          break
        end
      end
      
      assert.is_not_nil(after_current_option)
      assert.is_true(vim.tbl_contains(after_current_option.args, "{change_id}"))
    end)
  end)

  describe("rebase commands", function()
    it("should define rebase command with quick action and menu", function()
      local rebase_def = default_commands.get_command_definition("rebase")
      
      assert.is_not_nil(rebase_def)
      assert.is_not_nil(rebase_def.quick_action)
      assert.is_not_nil(rebase_def.menu)
      
      assert.are.equal("rebase", rebase_def.quick_action.cmd)
      assert.are.equal("r", rebase_def.quick_action.keymap)
      assert.are.equal("R", rebase_def.menu.keymap)
    end)
    
    it("should provide menu options for different rebase strategies", function()
      local rebase_def = default_commands.get_command_definition("rebase")
      local menu_options = rebase_def.menu.options
      
      assert.is_table(menu_options)
      assert.is_true(#menu_options >= 3)
      
      -- Should have standard rebase, rebase branch, and rebase with descendants
      local has_standard = false
      local has_branch = false
      local has_descendants = false
      
      for _, option in ipairs(menu_options) do
        local desc = option.desc:lower()
        if desc:match("rebase current") then has_standard = true end
        if desc:match("branch") then has_branch = true end
        if desc:match("descendant") then has_descendants = true end
      end
      
      assert.is_true(has_standard)
      assert.is_true(has_branch)
      assert.is_true(has_descendants)
    end)
    
    it("should use change_id parameter in rebase commands", function()
      local rebase_def = default_commands.get_command_definition("rebase")
      
      -- Quick action should use change_id
      assert.is_true(vim.tbl_contains(rebase_def.quick_action.args, "{change_id}"))
      
      -- Menu options should also use change_id
      for _, option in ipairs(rebase_def.menu.options) do
        if option.args then
          local has_change_id = vim.tbl_contains(option.args, "{change_id}")
          assert.is_true(has_change_id, "Option '" .. option.desc .. "' should have {change_id} parameter")
        end
      end
    end)
  end)

  describe("abandon commands", function()
    it("should define abandon command with confirmation", function()
      local abandon_def = default_commands.get_command_definition("abandon")
      
      assert.is_not_nil(abandon_def)
      assert.is_not_nil(abandon_def.quick_action)
      assert.is_not_nil(abandon_def.menu)
      
      assert.are.equal("abandon", abandon_def.quick_action.cmd)
      assert.are.equal("a", abandon_def.quick_action.keymap)
      assert.is_true(abandon_def.quick_action.confirm)
    end)
    
    it("should require confirmation for abandon operations", function()
      local abandon_def = default_commands.get_command_definition("abandon")
      
      -- Quick action should require confirmation
      assert.is_true(abandon_def.quick_action.confirm)
      
      -- Menu options for destructive operations should require confirmation
      for _, option in ipairs(abandon_def.menu.options) do
        if option.desc:lower():match("abandon") then
          assert.is_true(option.confirm, "Abandon option should require confirmation: " .. option.desc)
        end
      end
    end)
    
    it("should provide menu options for different abandon scenarios", function()
      local abandon_def = default_commands.get_command_definition("abandon")
      local menu_options = abandon_def.menu.options
      
      assert.is_table(menu_options)
      assert.is_true(#menu_options >= 2)
      
      -- Should have basic abandon, retain bookmarks, and restore descendants options
      local has_basic = false
      local has_bookmarks = false
      local has_descendants = false
      
      for _, option in ipairs(menu_options) do
        local desc = option.desc:lower()
        if desc:match("abandon change") and not desc:match("retain") and not desc:match("keep") then has_basic = true end
        if desc:match("bookmark") then has_bookmarks = true end
        if desc:match("descendant") then has_descendants = true end
      end
      
      assert.is_true(has_basic)
      assert.is_true(has_bookmarks)
      assert.is_true(has_descendants)
    end)
  end)

  describe("edit commands", function()
    it("should define edit command with quick action and menu", function()
      local edit_def = default_commands.get_command_definition("edit")
      
      assert.is_not_nil(edit_def)
      assert.is_not_nil(edit_def.quick_action)
      assert.is_not_nil(edit_def.menu)
      
      assert.are.equal("edit", edit_def.quick_action.cmd)
      assert.are.equal("e", edit_def.quick_action.keymap)
      assert.are.equal("E", edit_def.menu.keymap)
    end)
    
    it("should provide menu options for different edit modes", function()
      local edit_def = default_commands.get_command_definition("edit")
      local menu_options = edit_def.menu.options
      
      assert.is_table(menu_options)
      assert.is_true(#menu_options >= 2)
      
      -- Should have basic edit and edit with description
      local has_basic = false
      local has_description = false
      
      for _, option in ipairs(menu_options) do
        local desc = option.desc:lower()
        if desc:match("edit commit") and not desc:match("description") then has_basic = true end
        if desc:match("description") then has_description = true end
      end
      
      assert.is_true(has_basic)
      assert.is_true(has_description)
    end)
  end)

  describe("squash commands", function()
    it("should define squash command with confirmation", function()
      local squash_def = default_commands.get_command_definition("squash")
      
      assert.is_not_nil(squash_def)
      assert.is_not_nil(squash_def.quick_action)
      assert.is_not_nil(squash_def.menu)
      
      assert.are.equal("squash", squash_def.quick_action.cmd)
      assert.are.equal("s", squash_def.quick_action.keymap)
      assert.is_true(squash_def.quick_action.confirm)
    end)
    
    it("should provide menu options for different squash operations", function()
      local squash_def = default_commands.get_command_definition("squash")
      local menu_options = squash_def.menu.options
      
      assert.is_table(menu_options)
      assert.is_true(#menu_options >= 2)
      
      -- Should have squash into parent, squash current into selected, and squash from selected options
      local has_into_parent = false
      local has_current_into = false
      local has_from = false
      
      for _, option in ipairs(menu_options) do
        local desc = option.desc:lower()
        if desc:match("squash selected into its parent") then has_into_parent = true end
        if desc:match("squash current working copy into selected") then has_current_into = true end
        if desc:match("squash selected into current") then has_from = true end
      end
      
      assert.is_true(has_into_parent)
      assert.is_true(has_current_into)
      assert.is_true(has_from)
    end)
  end)

  describe("command registration", function()
    it("should register all default commands", function()
      local commands = default_commands.get_all_default_commands()
      
      assert.is_table(commands)
      assert.is_not_nil(commands.new)
      assert.is_not_nil(commands.rebase)
      assert.is_not_nil(commands.abandon)
      assert.is_not_nil(commands.edit)
      assert.is_not_nil(commands.squash)
    end)
    
    it("should initialize default commands in command execution framework", function()
      local command_execution = require("jj.command_execution")
      
      default_commands.register_all_defaults()
      
      -- Should be able to get registered commands
      assert.is_not_nil(command_execution.get_command("new"))
      assert.is_not_nil(command_execution.get_command("rebase"))
      assert.is_not_nil(command_execution.get_command("abandon"))
      assert.is_not_nil(command_execution.get_command("edit"))
      assert.is_not_nil(command_execution.get_command("squash"))
    end)
  end)

  describe("confirmation prompts", function()
    it("should prompt for confirmation on destructive operations", function()
      local confirmation_called = false
      local confirmation_message = nil
      
      vim.fn.confirm = function(msg, choices, default)
        confirmation_called = true
        confirmation_message = msg
        return 1 -- Yes
      end
      
      local result = default_commands.execute_with_confirmation("abandon", {change_id = "test123"})
      
      assert.is_true(confirmation_called)
      assert.matches("abandon", confirmation_message:lower())
      assert.matches("test123", confirmation_message)
    end)
    
    it("should cancel operation when user declines confirmation", function()
      vim.fn.confirm = function(msg, choices, default)
        return 2 -- No/Cancel
      end
      
      local result = default_commands.execute_with_confirmation("abandon", {change_id = "test123"})
      
      assert.is_false(result.success)
      assert.matches("cancelled", result.error:lower())
    end)
    
    it("should proceed when user confirms destructive operation", function()
      vim.fn.confirm = function(msg, choices, default)
        return 1 -- Yes
      end
      
      local executed_command = nil
      mock_executor.execute_jj_command = function(cmd)
        executed_command = cmd
        return { success = true, output = "command executed" }
      end
      
      local result = default_commands.execute_with_confirmation("abandon", {change_id = "test123"})
      
      assert.is_true(result.success)
      assert.matches("abandon test123", executed_command)
    end)
  end)

  describe("parameter substitution integration", function()
    it("should support all parameter types in default commands", function()
      local commands = default_commands.get_all_default_commands()
      
      -- Check that commands use appropriate parameter types
      local param_usage = {
        change_id = false,
        user_input = false
      }
      
      for _, command_def in pairs(commands) do
        -- Check quick action
        if command_def.quick_action and command_def.quick_action.args then
          for _, arg in ipairs(command_def.quick_action.args) do
            if arg == "{change_id}" then param_usage.change_id = true end
            if arg == "{user_input}" then param_usage.user_input = true end
          end
        end
        
        -- Check menu options
        if command_def.menu and command_def.menu.options then
          for _, option in ipairs(command_def.menu.options) do
            if option.args then
              for _, arg in ipairs(option.args) do
                if arg == "{change_id}" then param_usage.change_id = true end
                if arg == "{user_input}" then param_usage.user_input = true end
              end
            end
          end
        end
      end
      
      -- Should use all parameter types across the default command set
      assert.is_true(param_usage.change_id, "Default commands should use {change_id}")
      assert.is_true(param_usage.user_input, "Default commands should use {user_input}")
    end)
  end)
end)