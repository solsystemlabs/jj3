-- NEW command selection integration tests for jj.nvim
local busted = require("busted")
local default_commands = require("jj.default_commands")
local menu = require("jj.menu")

describe("NEW Command Selection Integration", function()
  local mock_vim
  local original_vim

  before_each(function()
    -- Mock vim functions
    mock_vim = {
      fn = {
        input = function(prompt, default)
          return "test commit description"
        end,
        confirm = function(msg, choices, default)
          return 1
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
      v = { shell_error = 0 },
      api = {
        nvim_get_current_buf = function() return 1 end
      },
      ui = {
        select = function(options, opts, callback)
          -- Simulate selecting the first option (multi-parent)
          callback(options[1], 1)
        end
      }
    }

    -- Store original and set mock
    original_vim = _G.vim
    _G.vim = mock_vim
  end)

  after_each(function()
    -- Restore original
    _G.vim = original_vim
  end)

  describe("Menu Options with Phases", function()
    it("should have phases defined for multi-parent option", function()
      local new_def = default_commands.get_command_definition("new")
      assert.is_not_nil(new_def.menu)
      assert.is_not_nil(new_def.menu.options)
      
      local multi_parent_option = new_def.menu.options[1]
      assert.equals("1", multi_parent_option.key)
      assert.truthy(multi_parent_option.desc:find("multiple parents"))
      
      -- Should have phases for multi-select
      assert.is_not_nil(multi_parent_option.phases)
      assert.equals(1, #multi_parent_option.phases)
      assert.equals("multi_target", multi_parent_option.phases[1].key)
      assert.is_true(multi_parent_option.phases[1].multi_select)
      assert.truthy(multi_parent_option.phases[1].prompt:find("multiple"))
    end)

    it("should have phases defined for single-target options", function()
      local new_def = default_commands.get_command_definition("new")
      local options = new_def.menu.options
      
      -- Options 2, 3, 4 should have single target phases
      for i = 2, 4 do
        local option = options[i]
        assert.is_not_nil(option.phases, "Option " .. i .. " should have phases")
        assert.equals(1, #option.phases, "Option " .. i .. " should have 1 phase")
        assert.equals("target", option.phases[1].key, "Option " .. i .. " should target 'target'")
        assert.is_nil(option.phases[1].multi_select, "Option " .. i .. " should not be multi-select")
      end
    end)
  end)

  describe("Menu Option Context Creation", function()
    it("should include phases in menu option context", function()
      local test_option = {
        key = "1",
        desc = "Test option",
        cmd = "test",
        args = { "arg1", "arg2" },
        phases = {
          { key = "test_target", prompt = "Select test target", multi_select = true }
        }
      }
      
      local context = menu.create_menu_option_context(test_option)
      
      assert.equals("1", context.key)
      assert.equals("Test option", context.desc)
      assert.equals("test", context.cmd)
      assert.same({ "arg1", "arg2" }, context.args)
      assert.is_not_nil(context.phases)
      assert.equals(1, #context.phases)
      assert.equals("test_target", context.phases[1].key)
      assert.is_true(context.phases[1].multi_select)
    end)

    it("should work without phases for simple options", function()
      local test_option = {
        key = "2",
        desc = "Simple option",
        cmd = "simple",
        args = { "simple_arg" }
        -- No phases
      }
      
      local context = menu.create_menu_option_context(test_option)
      
      assert.equals("2", context.key)
      assert.equals("Simple option", context.desc)
      assert.equals("simple", context.cmd)
      assert.same({ "simple_arg" }, context.args)
      assert.is_nil(context.phases)
    end)
  end)

  describe("Selection Workflow Detection", function()
    it("should detect when a menu option requires selection workflow", function()
      -- Test the menu system's ability to detect phases
      local new_def = default_commands.get_command_definition("new")
      local multi_parent_option = new_def.menu.options[1]
      
      local context = menu.create_menu_option_context(multi_parent_option)
      
      -- Should have phases, indicating selection workflow needed
      assert.is_not_nil(context.phases)
      assert.is_true(#context.phases > 0)
    end)

    it("should detect immediate execution for options without phases", function()
      -- Create a test option without phases
      local immediate_option = {
        key = "test",
        desc = "Immediate option",
        cmd = "immediate",
        args = { "no_selection_needed" }
      }
      
      local context = menu.create_menu_option_context(immediate_option)
      
      -- Should not have phases, indicating immediate execution
      assert.is_nil(context.phases)
    end)
  end)
end)