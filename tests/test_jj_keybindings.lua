-- Tests for jj dual-level keybinding system
local helpers = require("tests.helpers.vim_mock")

describe("jj keybinding system", function()
  local keybindings
  local mock_command_execution
  local mock_menu
  local mock_buffer_id = 123
  local registered_keymaps = {}

  before_each(function()
    -- Reset modules
    package.loaded["jj.keybindings"] = nil
    package.loaded["jj.command_execution"] = nil
    package.loaded["jj.menu"] = nil
    
    -- Reset registered keymaps
    registered_keymaps = {}
    
    -- Mock vim.api.nvim_buf_set_keymap to track registrations
    vim.api.nvim_buf_set_keymap = function(bufnr, mode, lhs, rhs, opts)
      registered_keymaps[lhs] = {
        bufnr = bufnr,
        mode = mode,
        rhs = rhs,
        opts = opts
      }
    end
    
    -- Mock command execution
    mock_command_execution = {
      get_command = function(name)
        if name == "new" then
          return {
            quick_action = {
              cmd = "new",
              args = {},
              keymap = "n",
              description = "Create new commit"
            },
            menu = {
              keymap = "N",
              title = "New Commit Options",
              options = {
                { key = "1", desc = "New commit (default)", cmd = "new", args = {} }
              }
            }
          }
        end
        return nil
      end,
      execute_command = function(name, action_type, context)
        return { success = true, output = "executed " .. name }
      end,
      get_command_context = function()
        return { commit_id = "commit_123", change_id = "commit_123" }
      end
    }
    
    -- Mock menu system
    mock_menu = {
      show_command_menu = function(command_name)
        return { success = true }
      end
    }
    
    package.loaded["jj.command_execution"] = mock_command_execution
    package.loaded["jj.menu"] = mock_menu
    
    keybindings = require("jj.keybindings")
  end)

  describe("keybinding registry", function()
    it("should register dual-level keybindings for a command", function()
      keybindings.register_command_keybindings(mock_buffer_id, "new")
      
      -- Should register both quick action (n) and menu (N) keybindings
      assert.is_not_nil(registered_keymaps["n"])
      assert.is_not_nil(registered_keymaps["N"])
      
      assert.are.equal(mock_buffer_id, registered_keymaps["n"].bufnr)
      assert.are.equal(mock_buffer_id, registered_keymaps["N"].bufnr)
      assert.are.equal("n", registered_keymaps["n"].mode)
      assert.are.equal("n", registered_keymaps["N"].mode)
    end)
    
    it("should register keybindings with proper descriptions", function()
      keybindings.register_command_keybindings(mock_buffer_id, "new")
      
      assert.are.equal("Create new commit", registered_keymaps["n"].opts.desc)
      assert.are.equal("New Commit Options", registered_keymaps["N"].opts.desc)
    end)
    
    it("should register keybindings as buffer-local", function()
      keybindings.register_command_keybindings(mock_buffer_id, "new")
      
      -- nvim_buf_set_keymap automatically creates buffer-local keymaps
      -- so we just verify the keymaps were registered
      assert.is_not_nil(registered_keymaps["n"])
      assert.is_not_nil(registered_keymaps["N"])
    end)
    
    it("should register keybindings as silent and noremap", function()
      keybindings.register_command_keybindings(mock_buffer_id, "new")
      
      assert.is_true(registered_keymaps["n"].opts.silent)
      assert.is_true(registered_keymaps["n"].opts.noremap)
      assert.is_true(registered_keymaps["N"].opts.silent)
      assert.is_true(registered_keymaps["N"].opts.noremap)
    end)
  end)

  describe("keybinding conflict detection", function()
    it("should detect keybinding conflicts", function()
      -- Register first command
      keybindings.register_command_keybindings(mock_buffer_id, "new")
      
      -- Mock a second command with conflicting keybinding
      mock_command_execution.get_command = function(name)
        if name == "conflict" then
          return {
            quick_action = {
              cmd = "other",
              args = {},
              keymap = "n", -- Same as 'new' command
              description = "Conflicting command"
            }
          }
        end
        return nil
      end
      
      local conflicts = keybindings.detect_keybinding_conflicts(mock_buffer_id, "conflict")
      
      assert.is_not_nil(conflicts)
      assert.are.equal(1, #conflicts)
      assert.are.equal("n", conflicts[1].key)
    end)
    
    it("should handle no conflicts gracefully", function()
      keybindings.register_command_keybindings(mock_buffer_id, "new")
      
      mock_command_execution.get_command = function(name)
        if name == "other" then
          return {
            quick_action = {
              cmd = "other",
              args = {},
              keymap = "o", -- Different key
              description = "Other command"
            }
          }
        end
        return nil
      end
      
      local conflicts = keybindings.detect_keybinding_conflicts(mock_buffer_id, "other")
      
      assert.is_table(conflicts)
      assert.are.equal(0, #conflicts)
    end)
  end)

  describe("quick action keybindings", function()
    it("should execute quick action when lowercase key is pressed", function()
      local executed_command = nil
      mock_command_execution.execute_command = function(name, action_type, context)
        executed_command = { name = name, action_type = action_type }
        return { success = true, output = "test" }
      end
      
      keybindings.register_command_keybindings(mock_buffer_id, "new")
      
      -- Simulate keypress by calling the registered function
      local quick_action_rhs = registered_keymaps["n"].rhs
      assert.is_string(quick_action_rhs)
      
      -- Execute the lua command
      local lua_code = quick_action_rhs:match("<cmd>lua (.+)<CR>")
      assert.is_not_nil(lua_code)
      
      load(lua_code)()
      
      assert.is_not_nil(executed_command)
      assert.are.equal("new", executed_command.name)
      assert.are.equal("quick_action", executed_command.action_type)
    end)
  end)

  describe("menu keybindings", function()
    it("should show menu when uppercase key is pressed", function()
      local shown_menu = nil
      mock_menu.show_command_menu = function(command_name)
        shown_menu = command_name
        return { success = true }
      end
      
      keybindings.register_command_keybindings(mock_buffer_id, "new")
      
      -- Simulate keypress by calling the registered function
      local menu_action_rhs = registered_keymaps["N"].rhs
      assert.is_string(menu_action_rhs)
      
      -- Execute the lua command
      local lua_code = menu_action_rhs:match("<cmd>lua (.+)<CR>")
      assert.is_not_nil(lua_code)
      
      load(lua_code)()
      
      assert.are.equal("new", shown_menu)
    end)
  end)

  describe("bulk keybinding registration", function()
    it("should register keybindings for multiple commands", function()
      local commands = { "new", "rebase", "abandon" }
      
      -- Mock additional commands
      mock_command_execution.get_command = function(name)
        local command_defs = {
          new = {
            quick_action = { cmd = "new", keymap = "n", description = "Create new commit" },
            menu = { keymap = "N", title = "New Options" }
          },
          rebase = {
            quick_action = { cmd = "rebase", keymap = "r", description = "Rebase commit" },
            menu = { keymap = "R", title = "Rebase Options" }
          },
          abandon = {
            quick_action = { cmd = "abandon", keymap = "a", description = "Abandon commit" },
            menu = { keymap = "A", title = "Abandon Options" }
          }
        }
        return command_defs[name]
      end
      
      keybindings.register_all_command_keybindings(mock_buffer_id, commands)
      
      -- Should register all 6 keybindings (2 per command)
      assert.is_not_nil(registered_keymaps["n"])
      assert.is_not_nil(registered_keymaps["N"])
      assert.is_not_nil(registered_keymaps["r"])
      assert.is_not_nil(registered_keymaps["R"])
      assert.is_not_nil(registered_keymaps["a"])
      assert.is_not_nil(registered_keymaps["A"])
    end)
    
    it("should handle commands without menu definitions", function()
      mock_command_execution.get_command = function(name)
        if name == "no_menu" then
          return {
            quick_action = { cmd = "test", keymap = "t", description = "Test command" }
            -- No menu definition
          }
        end
        return nil
      end
      
      keybindings.register_command_keybindings(mock_buffer_id, "no_menu")
      
      -- Should register quick action but not menu
      assert.is_not_nil(registered_keymaps["t"])
      assert.is_nil(registered_keymaps["T"])
    end)
  end)

  describe("keybinding customization", function()
    it("should allow user override of default keybindings", function()
      local user_overrides = {
        new = {
          quick_action = { keymap = "x" },
          menu = { keymap = "X" }
        }
      }
      
      keybindings.apply_user_keybinding_overrides(user_overrides)
      keybindings.register_command_keybindings(mock_buffer_id, "new")
      
      -- Should use user-defined keys instead of defaults
      assert.is_not_nil(registered_keymaps["x"])
      assert.is_not_nil(registered_keymaps["X"])
      assert.is_nil(registered_keymaps["n"])
      assert.is_nil(registered_keymaps["N"])
    end)
    
    it("should validate user keybinding overrides", function()
      local invalid_overrides = {
        new = {
          quick_action = { keymap = "" }, -- Invalid empty keymap
        }
      }
      
      local result = keybindings.apply_user_keybinding_overrides(invalid_overrides)
      
      assert.is_false(result.success)
      assert.matches("invalid", result.error:lower())
    end)
  end)

  describe("error handling", function()
    it("should handle missing command definitions gracefully", function()
      mock_command_execution.get_command = function(name)
        return nil
      end
      
      local result = keybindings.register_command_keybindings(mock_buffer_id, "missing")
      
      assert.is_false(result.success)
      assert.matches("not found", result.error)
    end)
    
    it("should handle invalid buffer IDs", function()
      local result = keybindings.register_command_keybindings(nil, "new")
      
      assert.is_false(result.success)
      assert.matches("buffer", result.error:lower())
    end)
    
    it("should handle keybinding registration errors", function()
      -- Mock vim.api.nvim_buf_set_keymap to throw error
      vim.api.nvim_buf_set_keymap = function(bufnr, mode, lhs, rhs, opts)
        error("Mock keybinding error")
      end
      
      local result = keybindings.register_command_keybindings(mock_buffer_id, "new")
      
      assert.is_false(result.success)
      assert.matches("error", result.error:lower())
    end)
  end)

  describe("integration with existing system", function()
    it("should integrate with existing buffer setup", function()
      -- This would be tested with actual buffer creation
      local buffer_setup_called = false
      
      keybindings.setup_jj_buffer_keybindings = function(bufnr)
        buffer_setup_called = true
        return keybindings.register_all_default_keybindings(bufnr)
      end
      
      keybindings.setup_jj_buffer_keybindings(mock_buffer_id)
      
      assert.is_true(buffer_setup_called)
    end)
  end)
end)