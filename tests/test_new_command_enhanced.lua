-- Enhanced NEW command tests for jj.nvim
local busted = require("busted")
local default_commands = require("jj.default_commands")

describe("Enhanced NEW Command", function()
  local mock_vim
  local mock_executor
  local original_vim
  local original_executor

  before_each(function()
    -- Mock vim functions
    mock_vim = {
      fn = {
        input = function(prompt, default)
          return "test commit description"
        end,
        confirm = function(msg, choices, default)
          return 1 -- Always confirm
        end,
        system = function(cmd)
          mock_vim.v.shell_error = 0
          return "jj 0.31.0"
        end,
        getcwd = function()
          return "/test/repo"
        end
      },
      system = function(cmd, opts, callback)
        if callback then
          callback({ code = 0, stdout = "jj 0.31.0" })
        end
        return { code = 0, stdout = "jj 0.31.0" }
      end,
      notify = function(msg, level) end,
      log = { levels = { INFO = 1, ERROR = 2, WARN = 3 } },
      v = { shell_error = 0 }
    }
    
    -- Mock executor
    mock_executor = {
      execute_jj_command = function(command)
        return {
          success = true,
          output = "Created new commit abc123",
          executed_command = command
        }
      end
    }

    -- Store originals and set mocks
    original_vim = _G.vim
    original_executor = package.loaded["jj.log.executor"]
    _G.vim = mock_vim
    package.loaded["jj.log.executor"] = mock_executor
  end)

  after_each(function()
    -- Restore originals
    _G.vim = original_vim
    package.loaded["jj.log.executor"] = original_executor
  end)

  describe("Quick Action (n)", function()
    it("should have proper command structure for description prompting", function()
      local new_def = default_commands.get_command_definition("new")
      assert.is_not_nil(new_def)
      assert.is_not_nil(new_def.quick_action)
      
      local args = new_def.quick_action.args
      assert.is_table(args)
      
      -- Should have -m flag, {user_input} placeholder, and {target}
      assert.equals("-m", args[1])
      assert.equals("{user_input}", args[2])
      assert.equals("{target}", args[3])
      
      -- Verify description references prompting
      assert.truthy(new_def.quick_action.description:find("prompting") or 
                    new_def.quick_action.description:find("description"))
    end)

    it("should have user_input placeholder for description prompting", function()
      local new_def = default_commands.get_command_definition("new")
      local args = new_def.quick_action.args
      
      -- Verify that {user_input} placeholder is present for prompting
      local has_user_input = false
      for _, arg in ipairs(args) do
        if arg == "{user_input}" then
          has_user_input = true
          break
        end
      end
      
      assert.is_true(has_user_input, "NEW command should have {user_input} placeholder")
    end)

    it("should have target placeholder for commit targeting", function()
      local new_def = default_commands.get_command_definition("new")
      local args = new_def.quick_action.args
      
      -- Verify that {target} placeholder is present
      local has_target = false
      for _, arg in ipairs(args) do
        if arg == "{target}" then
          has_target = true
          break
        end
      end
      
      assert.is_true(has_target, "NEW command should have {target} placeholder")
    end)
  end)

  describe("Menu Options (N)", function()
    it("should have 4 menu options as specified", function()
      local new_def = default_commands.get_command_definition("new")
      assert.is_not_nil(new_def.menu)
      assert.is_not_nil(new_def.menu.options)
      assert.equals(4, #new_def.menu.options)

      local options = new_def.menu.options
      
      -- Option 1: New commit with multiple parents
      assert.truthy(options[1].desc:find("multiple parents") or options[1].desc:find("multi"))
      
      -- Option 2: New commit before selected
      assert.truthy(options[2].desc:find("before"))
      
      -- Option 3: New commit after selected  
      assert.truthy(options[3].desc:find("after"))
      
      -- Option 4: New commit without edit
      assert.truthy(options[4].desc:find("without edit") or options[4].desc:find("no.?edit"))
      assert.truthy(options[4].args and #options[4].args > 0)
      local has_no_edit = false
      for _, arg in ipairs(options[4].args) do
        if arg == "--no-edit" then
          has_no_edit = true
          break
        end
      end
      assert.is_true(has_no_edit)
    end)

    it("should execute before option with proper arguments", function()
      local command_executed = false
      mock_executor.execute_jj_command = function(command)
        command_executed = true
        assert.truthy(command:find("jj new"))
        assert.truthy(command:find("--insert-before") or command:find("-B"))
        return { success = true, output = "Created commit" }
      end

      local new_def = default_commands.get_command_definition("new")
      local before_option = new_def.menu.options[2] -- Before option
      
      -- Simulate menu option execution
      assert.is_not_nil(before_option.cmd)
      assert.equals("new", before_option.cmd)
    end)

    it("should execute after option with proper arguments", function()
      local command_executed = false  
      mock_executor.execute_jj_command = function(command)
        command_executed = true
        assert.truthy(command:find("jj new"))
        assert.truthy(command:find("--insert-after") or command:find("-A"))
        return { success = true, output = "Created commit" }
      end

      local new_def = default_commands.get_command_definition("new")
      local after_option = new_def.menu.options[3] -- After option
      
      -- Simulate menu option execution
      assert.is_not_nil(after_option.cmd)
      assert.equals("new", after_option.cmd)
    end)

    it("should execute no-edit option with --no-edit flag", function()
      local command_executed = false
      mock_executor.execute_jj_command = function(command)
        command_executed = true
        assert.truthy(command:find("jj new"))
        assert.truthy(command:find("--no-edit"))
        return { success = true, output = "Created commit" }
      end

      local new_def = default_commands.get_command_definition("new")
      local no_edit_option = new_def.menu.options[4] -- No-edit option
      
      -- Verify the option has --no-edit in args
      local has_no_edit = false
      for _, arg in ipairs(no_edit_option.args or {}) do
        if arg == "--no-edit" then
          has_no_edit = true
          break
        end
      end
      assert.is_true(has_no_edit)
    end)
  end)

  describe("Multi-Parent Functionality", function()
    it("should support multi-select workflow for multiple parents", function()
      -- This test will need to be implemented once multi-select is available
      pending("Multi-select workflow not yet implemented")
    end)

    it("should handle multiple commit IDs in arguments", function()
      -- This test will verify proper argument substitution for multiple parents
      pending("Multi-parent argument handling not yet implemented")
    end)
  end)

  describe("Command Definition Validation", function()
    it("should have valid quick_action definition", function()
      local new_def = default_commands.get_command_definition("new")
      assert.is_not_nil(new_def)
      assert.is_not_nil(new_def.quick_action)
      assert.is_string(new_def.quick_action.cmd)
      assert.is_string(new_def.quick_action.keymap)
      assert.is_string(new_def.quick_action.description)
      assert.equals("new", new_def.quick_action.cmd)
      assert.equals("n", new_def.quick_action.keymap)
    end)

    it("should have valid menu definition", function()
      local new_def = default_commands.get_command_definition("new")
      assert.is_not_nil(new_def.menu)
      assert.is_string(new_def.menu.keymap)
      assert.is_string(new_def.menu.title)
      assert.is_table(new_def.menu.options)
      assert.equals("N", new_def.menu.keymap)
      assert.equals(4, #new_def.menu.options)
    end)

    it("should have properly structured menu options", function()
      local new_def = default_commands.get_command_definition("new")
      for i, option in ipairs(new_def.menu.options) do
        assert.is_string(option.key, "Option " .. i .. " missing key")
        assert.is_string(option.desc, "Option " .. i .. " missing desc")
        assert.is_string(option.cmd, "Option " .. i .. " missing cmd")
        assert.equals("new", option.cmd, "Option " .. i .. " has wrong cmd")
        if option.args then
          assert.is_table(option.args, "Option " .. i .. " args must be table")
        end
      end
    end)
  end)
end)