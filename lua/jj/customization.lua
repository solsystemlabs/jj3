-- User customization framework for jj.nvim
local M = {}

-- Import dependencies
local config = require("jj.config")
local command_execution = require("jj.command_execution")
local default_commands = require("jj.default_commands")

-- Load user command definitions from configuration
function M.load_user_commands()
  local user_config = config.get()
  
  if not user_config or type(user_config) ~= "table" then
    return {}
  end
  
  if not user_config.commands or type(user_config.commands) ~= "table" then
    return {}
  end
  
  return user_config.commands
end

-- Validate a single user command definition
function M.validate_user_command(name, command_def)
  local errors = {}
  
  if type(command_def) ~= "table" then
    table.insert(errors, "Command '" .. name .. "' must be a table")
    return false, errors
  end
  
  -- Validate quick_action
  if not command_def.quick_action then
    table.insert(errors, "Command '" .. name .. "' missing quick_action")
  else
    local qa = command_def.quick_action
    if type(qa) ~= "table" then
      table.insert(errors, "Command '" .. name .. "' quick_action must be a table")
    else
      if not qa.cmd or type(qa.cmd) ~= "string" then
        table.insert(errors, "Command '" .. name .. "' quick_action missing cmd field")
      end
      if not qa.keymap or type(qa.keymap) ~= "string" then
        table.insert(errors, "Command '" .. name .. "' quick_action missing keymap field")
      end
      if not qa.description or type(qa.description) ~= "string" then
        table.insert(errors, "Command '" .. name .. "' quick_action missing description field")
      end
      if qa.args and type(qa.args) ~= "table" then
        table.insert(errors, "Command '" .. name .. "' quick_action args must be a table")
      end
    end
  end
  
  -- Validate menu if present
  if command_def.menu then
    local menu = command_def.menu
    if type(menu) ~= "table" then
      table.insert(errors, "Command '" .. name .. "' menu must be a table")
    else
      if not menu.keymap or type(menu.keymap) ~= "string" then
        table.insert(errors, "Command '" .. name .. "' menu missing keymap field")
      end
      if not menu.title or type(menu.title) ~= "string" then
        table.insert(errors, "Command '" .. name .. "' menu missing title field")
      end
      if not menu.options or type(menu.options) ~= "table" then
        table.insert(errors, "Command '" .. name .. "' menu missing options field")
      else
        -- Validate menu options
        for i, option in ipairs(menu.options) do
          if type(option) ~= "table" then
            table.insert(errors, "Command '" .. name .. "' menu option " .. i .. " must be a table")
          else
            if not option.key or type(option.key) ~= "string" then
              table.insert(errors, "Command '" .. name .. "' menu option " .. i .. " missing key field")
            end
            if not option.desc or type(option.desc) ~= "string" then
              table.insert(errors, "Command '" .. name .. "' menu option " .. i .. " missing desc field")
            end
            if not option.cmd or type(option.cmd) ~= "string" then
              table.insert(errors, "Command '" .. name .. "' menu option " .. i .. " missing cmd field")
            end
            if option.args and type(option.args) ~= "table" then
              table.insert(errors, "Command '" .. name .. "' menu option " .. i .. " args must be a table")
            end
          end
        end
      end
    end
  end
  
  return #errors == 0, errors
end

-- Merge user commands with default commands
function M.merge_commands_with_defaults(user_commands)
  local defaults = default_commands.get_all_default_commands()
  local merged = vim.deepcopy(defaults)
  
  -- Merge each user command individually to handle partial overrides
  for name, user_command in pairs(user_commands) do
    if merged[name] then
      -- Merge with existing default
      merged[name] = vim.tbl_deep_extend("force", merged[name], user_command)
    else
      -- Add new user command
      merged[name] = user_command
    end
  end
  
  return merged
end

-- Detect keymap conflicts between commands
function M.detect_keymap_conflicts(user_commands)
  local conflicts = {}
  local quick_keymap_usage = {}
  local menu_keymap_usage = {}
  
  -- Get all commands (defaults + user)  
  local all_commands = M.merge_commands_with_defaults(user_commands)
  
  -- Track keymap usage separately for quick actions and menus
  for name, command_def in pairs(all_commands) do
    -- Track quick action keymap
    if command_def.quick_action and command_def.quick_action.keymap then
      local keymap = command_def.quick_action.keymap
      quick_keymap_usage[keymap] = quick_keymap_usage[keymap] or {}
      table.insert(quick_keymap_usage[keymap], name)
    end
    
    -- Track menu keymap
    if command_def.menu and command_def.menu.keymap then
      local keymap = command_def.menu.keymap
      menu_keymap_usage[keymap] = menu_keymap_usage[keymap] or {}
      table.insert(menu_keymap_usage[keymap], name)
    end
  end
  
  -- Find conflicts in quick action keymaps
  for keymap, commands in pairs(quick_keymap_usage) do
    if #commands > 1 then
      table.insert(conflicts, {
        keymap = keymap,
        commands = commands,
        type = "quick_action"
      })
    end
  end
  
  -- Find conflicts in menu keymaps
  for keymap, commands in pairs(menu_keymap_usage) do
    if #commands > 1 then
      table.insert(conflicts, {
        keymap = keymap,
        commands = commands,
        type = "menu"
      })
    end
  end
  
  return conflicts
end

-- Apply user configuration to the command execution framework
function M.apply_user_configuration()
  local user_config = config.get()
  
  if not user_config or type(user_config) ~= "table" then
    return {
      success = false,
      error = "Invalid user configuration: must be a table"
    }
  end
  
  local user_commands = M.load_user_commands()
  local all_errors = {}
  local all_conflicts = {}
  
  -- Validate all user commands
  for name, command_def in pairs(user_commands) do
    local is_valid, errors = M.validate_user_command(name, command_def)
    if not is_valid then
      vim.list_extend(all_errors, errors)
    end
  end
  
  -- Check for conflicts
  local conflicts = M.detect_keymap_conflicts(user_commands)
  if #conflicts > 0 then
    all_conflicts = conflicts
  end
  
  -- Return errors if validation failed
  if #all_errors > 0 or #all_conflicts > 0 then
    local result = { success = false }
    if #all_errors > 0 then
      result.errors = all_errors
    end
    if #all_conflicts > 0 then
      result.conflicts = all_conflicts
    end
    return result
  end
  
  -- Merge and register commands
  local merged_commands = M.merge_commands_with_defaults(user_commands)
  command_execution.merge_user_commands(merged_commands)
  
  return { success = true }
end

-- Reload user configuration
function M.reload_user_configuration()
  -- For now, just reapply configuration
  -- In a more sophisticated implementation, we'd clean up old commands first
  return M.apply_user_configuration()
end

-- Get configuration examples for documentation
function M.get_configuration_examples()
  return {
    custom_command = {
      description = "Example of defining a custom command",
      commands = {
        status = {
          quick_action = {
            cmd = "status",
            args = {},
            keymap = "S",
            description = "Show repository status"
          },
          menu = {
            keymap = "\\s",
            title = "Status Options",
            options = {
              {
                key = "1",
                desc = "Show status",
                cmd = "status",
                args = {}
              },
              {
                key = "2", 
                desc = "Show status with conflicts",
                cmd = "status",
                args = {"--conflicts"}
              }
            }
          }
        }
      }
    },
    
    override_default = {
      description = "Example of overriding a default command",
      commands = {
        new = {
          quick_action = {
            cmd = "new",
            args = {"--no-edit"}, -- Add default flag
            keymap = "n",
            description = "Create new commit without editing"
          }
          -- Menu will be inherited from defaults
        }
      }
    },
    
    custom_menu = {
      description = "Example of adding custom menu options",
      commands = {
        rebase = {
          quick_action = {
            cmd = "rebase",
            args = {"-d", "{commit_id}"},
            keymap = "r", 
            description = "Rebase current change"
          },
          menu = {
            keymap = "R",
            title = "Custom Rebase Options",
            options = {
              {
                key = "1",
                desc = "Interactive rebase",
                cmd = "rebase",
                args = {"-d", "{commit_id}", "--interactive"}
              },
              {
                key = "2",
                desc = "Rebase with custom message",
                cmd = "rebase", 
                args = {"-d", "{commit_id}", "-m", "{user_input}"}
              }
            }
          }
        }
      }
    }
  }
end

return M