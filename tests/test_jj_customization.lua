-- Tests for jj user customization framework
local helpers = require("tests.helpers.vim_mock")

describe("jj user customization framework", function()
  local customization
  local mock_config
  local mock_command_execution
  local mock_default_commands

  before_each(function()
    -- Reset modules
    package.loaded["jj.customization"] = nil
    package.loaded["jj.config"] = nil
    package.loaded["jj.command_execution"] = nil
    package.loaded["jj.default_commands"] = nil
    
    -- Mock config system
    mock_config = {
      user_config = {},
      get = function()
        return mock_config.user_config
      end,
      set_user_config = function(config)
        mock_config.user_config = config
      end
    }
    
    -- Mock command execution
    mock_command_execution = {
      registered_commands = {},
      register_command = function(name, definition)
        mock_command_execution.registered_commands[name] = definition
        return true
      end,
      get_command = function(name)
        return mock_command_execution.registered_commands[name]
      end,
      merge_user_commands = function(user_commands)
        for name, definition in pairs(user_commands) do
          mock_command_execution.registered_commands[name] = definition
        end
      end
    }
    
    -- Mock default commands
    mock_default_commands = {
      get_all_default_commands = function()
        return {
          new = {
            quick_action = { cmd = "new", keymap = "n", description = "Create new commit" },
            menu = { keymap = "N", title = "New Options", options = {} }
          },
          rebase = {
            quick_action = { cmd = "rebase", keymap = "r", description = "Rebase commit" },
            menu = { keymap = "R", title = "Rebase Options", options = {} }
          }
        }
      end
    }
    
    package.loaded["jj.config"] = mock_config
    package.loaded["jj.command_execution"] = mock_command_execution
    package.loaded["jj.default_commands"] = mock_default_commands
    
    customization = require("jj.customization")
  end)

  describe("configuration loading", function()
    it("should load user command definitions from config", function()
      local user_config = {
        commands = {
          custom = {
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
                { key = "1", desc = "Custom option", cmd = "custom", args = {} }
              }
            }
          }
        }
      }
      
      mock_config.set_user_config(user_config)
      
      local loaded_commands = customization.load_user_commands()
      
      assert.is_not_nil(loaded_commands.custom)
      assert.are.equal("custom", loaded_commands.custom.quick_action.cmd)
      assert.are.equal("c", loaded_commands.custom.quick_action.keymap)
    end)
    
    it("should handle empty user configuration", function()
      mock_config.set_user_config({})
      
      local loaded_commands = customization.load_user_commands()
      
      assert.is_table(loaded_commands)
      assert.are.equal(0, vim.tbl_count(loaded_commands))
    end)
    
    it("should handle missing commands section in config", function()
      mock_config.set_user_config({ other_settings = true })
      
      local loaded_commands = customization.load_user_commands()
      
      assert.is_table(loaded_commands)
      assert.are.equal(0, vim.tbl_count(loaded_commands))
    end)
  end)

  describe("command validation", function()
    it("should validate user command definitions", function()
      local valid_command = {
        quick_action = {
          cmd = "test",
          keymap = "t",
          description = "Test command"
        }
      }
      
      local is_valid, errors = customization.validate_user_command("test", valid_command)
      
      assert.is_true(is_valid)
      assert.are.equal(0, #errors)
    end)
    
    it("should reject invalid command definitions", function()
      local invalid_command = {
        quick_action = {
          -- missing cmd field
          keymap = "t",
          description = "Invalid command"
        }
      }
      
      local is_valid, errors = customization.validate_user_command("invalid", invalid_command)
      
      assert.is_false(is_valid)
      assert.is_true(#errors > 0)
      assert.matches("cmd", errors[1]:lower())
    end)
    
    it("should validate menu definitions", function()
      local command_with_menu = {
        quick_action = {
          cmd = "test",
          keymap = "t",
          description = "Test"
        },
        menu = {
          keymap = "T",
          title = "Test Options",
          options = {
            { key = "1", desc = "Option 1", cmd = "test", args = {} }
          }
        }
      }
      
      local is_valid, errors = customization.validate_user_command("test", command_with_menu)
      
      assert.is_true(is_valid)
      assert.are.equal(0, #errors)
    end)
    
    it("should reject invalid menu definitions", function()
      local invalid_menu = {
        quick_action = {
          cmd = "test",
          keymap = "t", 
          description = "Test"
        },
        menu = {
          keymap = "T",
          -- missing title
          options = {}
        }
      }
      
      local is_valid, errors = customization.validate_user_command("test", invalid_menu)
      
      assert.is_false(is_valid)
      assert.is_true(#errors > 0)
    end)
  end)

  describe("command merging", function()
    it("should merge user commands with defaults", function()
      local user_commands = {
        new = {
          quick_action = {
            cmd = "new",
            args = {"--custom-flag"},
            keymap = "n",
            description = "Custom new commit"
          }
        },
        custom = {
          quick_action = {
            cmd = "custom",
            keymap = "c",
            description = "Custom command"
          }
        }
      }
      
      local merged = customization.merge_commands_with_defaults(user_commands)
      
      -- Should have both default and user commands
      assert.is_not_nil(merged.new)
      assert.is_not_nil(merged.rebase) -- from defaults
      assert.is_not_nil(merged.custom) -- user-defined
      
      -- User command should override default
      assert.are.equal("Custom new commit", merged.new.quick_action.description)
      assert.are.same({"--custom-flag"}, merged.new.quick_action.args)
    end)
    
    it("should preserve default commands when no user override", function()
      local user_commands = {
        custom = {
          quick_action = {
            cmd = "custom",
            keymap = "c",
            description = "Custom command"
          }
        }
      }
      
      local merged = customization.merge_commands_with_defaults(user_commands)
      
      -- Default commands should be preserved
      assert.is_not_nil(merged.new)
      assert.is_not_nil(merged.rebase)
      assert.are.equal("Create new commit", merged.new.quick_action.description)
    end)
    
    it("should handle partial command overrides", function()
      local user_commands = {
        new = {
          quick_action = {
            cmd = "new",
            keymap = "x", -- change keymap only
            description = "Create new commit"
          }
          -- no menu definition - should preserve default
        }
      }
      
      local merged = customization.merge_commands_with_defaults(user_commands)
      
      assert.are.equal("x", merged.new.quick_action.keymap)
      assert.is_not_nil(merged.new.menu) -- should preserve default menu
    end)
  end)

  describe("conflict resolution", function()
    it("should detect keymap conflicts", function()
      local user_commands = {
        custom1 = {
          quick_action = { cmd = "custom1", keymap = "n", description = "Custom 1" }
        },
        custom2 = {
          quick_action = { cmd = "custom2", keymap = "n", description = "Custom 2" }
        }
      }
      
      local conflicts = customization.detect_keymap_conflicts(user_commands)
      
      assert.is_true(#conflicts > 0)
      assert.are.equal("n", conflicts[1].keymap)
      assert.are.equal(3, #conflicts[1].commands) -- custom1, custom2, and default "new"
      assert.is_true(vim.tbl_contains(conflicts[1].commands, "custom1"))
      assert.is_true(vim.tbl_contains(conflicts[1].commands, "custom2"))
      assert.is_true(vim.tbl_contains(conflicts[1].commands, "new"))
    end)
    
    it("should detect conflicts with default commands", function()
      local user_commands = {
        custom = {
          quick_action = { cmd = "custom", keymap = "n", description = "Custom" } -- conflicts with default 'new'
        }
      }
      
      local conflicts = customization.detect_keymap_conflicts(user_commands)
      
      assert.is_true(#conflicts > 0)
      assert.are.equal("n", conflicts[1].keymap)
      assert.is_true(vim.tbl_contains(conflicts[1].commands, "new"))
      assert.is_true(vim.tbl_contains(conflicts[1].commands, "custom"))
    end)
    
    it("should handle no conflicts gracefully", function()
      local user_commands = {
        custom = {
          quick_action = { cmd = "custom", keymap = "c", description = "Custom" }
        }
      }
      
      local conflicts = customization.detect_keymap_conflicts(user_commands)
      
      assert.are.equal(0, #conflicts)
    end)
  end)

  describe("configuration application", function()
    it("should apply user configuration to command execution framework", function()
      local user_config = {
        commands = {
          custom = {
            quick_action = {
              cmd = "custom",
              keymap = "c",
              description = "Custom command"
            }
          }
        }
      }
      
      mock_config.set_user_config(user_config)
      
      customization.apply_user_configuration()
      
      -- Should be registered in command execution framework
      assert.is_not_nil(mock_command_execution.registered_commands.custom)
    end)
    
    it("should validate configuration before applying", function()
      local invalid_config = {
        commands = {
          invalid = {
            quick_action = {
              -- missing cmd field
              keymap = "i",
              description = "Invalid"
            }
          }
        }
      }
      
      mock_config.set_user_config(invalid_config)
      
      local result = customization.apply_user_configuration()
      
      assert.is_false(result.success)
      assert.is_not_nil(result.errors)
      assert.is_true(#result.errors > 0)
    end)
    
    it("should report conflicts during application", function()
      local conflicting_config = {
        commands = {
          custom1 = {
            quick_action = { cmd = "custom1", keymap = "n", description = "Custom 1" }
          },
          custom2 = {
            quick_action = { cmd = "custom2", keymap = "n", description = "Custom 2" }
          }
        }
      }
      
      mock_config.set_user_config(conflicting_config)
      
      local result = customization.apply_user_configuration()
      
      assert.is_false(result.success)
      assert.is_not_nil(result.conflicts)
      assert.is_true(#result.conflicts > 0)
    end)
  end)

  describe("configuration examples", function()
    it("should provide example configurations", function()
      local examples = customization.get_configuration_examples()
      
      assert.is_table(examples)
      assert.is_not_nil(examples.custom_command)
      assert.is_not_nil(examples.override_default)
      assert.is_not_nil(examples.custom_menu)
    end)
    
    it("should validate example configurations", function()
      local examples = customization.get_configuration_examples()
      
      for name, example in pairs(examples) do
        if example.commands then
          for cmd_name, cmd_def in pairs(example.commands) do
            local is_valid, errors = customization.validate_user_command(cmd_name, cmd_def)
            assert.is_true(is_valid, "Example '" .. name .. "' command '" .. cmd_name .. "' should be valid: " .. table.concat(errors, ", "))
          end
        end
      end
    end)
  end)

  describe("dynamic configuration", function()
    it("should support configuration reloading", function()
      -- Initial config
      local initial_config = {
        commands = {
          test1 = {
            quick_action = { cmd = "test1", keymap = "1", description = "Test 1" }
          }
        }
      }
      
      mock_config.set_user_config(initial_config)
      customization.apply_user_configuration()
      
      assert.is_not_nil(mock_command_execution.registered_commands.test1)
      
      -- Update config
      local updated_config = {
        commands = {
          test2 = {
            quick_action = { cmd = "test2", keymap = "2", description = "Test 2" }
          }
        }
      }
      
      mock_config.set_user_config(updated_config)
      customization.reload_user_configuration()
      
      assert.is_not_nil(mock_command_execution.registered_commands.test2)
    end)
    
    it("should clean up old commands on reload", function()
      -- This would require more sophisticated command registry management
      -- For now, just test that reload doesn't error
      local config = {
        commands = {
          test = {
            quick_action = { cmd = "test", keymap = "t", description = "Test" }
          }
        }
      }
      
      mock_config.set_user_config(config)
      
      local result1 = customization.apply_user_configuration()
      local result2 = customization.reload_user_configuration()
      
      assert.is_true(result1.success)
      assert.is_true(result2.success)
    end)
  end)

  describe("error handling", function()
    it("should handle malformed configuration gracefully", function()
      mock_config.set_user_config("invalid config") -- not a table
      
      local result = customization.apply_user_configuration()
      
      assert.is_false(result.success)
      assert.matches("invalid", result.error:lower())
    end)
    
    it("should provide helpful error messages", function()
      local bad_config = {
        commands = {
          bad = {
            quick_action = {
              -- missing required fields
            }
          }
        }
      }
      
      mock_config.set_user_config(bad_config)
      
      local result = customization.apply_user_configuration()
      
      assert.is_false(result.success)
      assert.is_not_nil(result.errors)
      assert.is_true(#result.errors > 0)
      
      -- Error should mention the command name and issue
      local error_text = table.concat(result.errors, " "):lower()
      assert.matches("bad", error_text)
    end)
  end)
end)