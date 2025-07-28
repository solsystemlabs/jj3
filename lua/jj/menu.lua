-- Menu system for jj.nvim command execution framework
local M = {}

-- Import dependencies
local command_execution = require("jj.command_execution")

-- Generate menu options from command definition
function M.generate_menu_options(command_name)
  local command_def = command_execution.get_command(command_name)
  
  if not command_def or not command_def.menu then
    return nil
  end
  
  local menu_def = command_def.menu
  
  -- Validate menu definition structure
  if not menu_def.options or type(menu_def.options) ~= "table" then
    return nil
  end
  
  return menu_def.options
end

-- Format menu items for display with key prefixes
function M.format_menu_items(options)
  local formatted = {}
  
  for _, option in ipairs(options) do
    local formatted_item = string.format("%s) %s", option.key, option.desc)
    table.insert(formatted, formatted_item)
  end
  
  return formatted
end

-- Create context for menu option execution
function M.create_menu_option_context(option)
  return {
    cmd = option.cmd,
    args = option.args,
    key = option.key,
    desc = option.desc
  }
end

-- Show command menu using vim.ui.select
function M.show_command_menu(command_name)
  local command_def = command_execution.get_command(command_name)
  
  if not command_def then
    return {
      success = false,
      error = "Command '" .. command_name .. "' not found in registry"
    }
  end
  
  if not command_def.menu then
    return {
      success = false,
      error = "Command '" .. command_name .. "' has no menu definition"
    }
  end
  
  local menu_def = command_def.menu
  
  -- Validate menu definition
  if not menu_def.options or type(menu_def.options) ~= "table" or #menu_def.options == 0 then
    return {
      success = false,
      error = "Command '" .. command_name .. "' has invalid menu definition"
    }
  end
  
  local options = menu_def.options
  local formatted_items = M.format_menu_items(options)
  
  -- Get current context for command execution
  local context = command_execution.get_command_context()
  
  -- Show menu using vim.ui.select
  vim.ui.select(options, {
    prompt = menu_def.title or (command_name .. " Options"),
    format_item = function(item)
      return string.format("%s) %s", item.key, item.desc)
    end
  }, function(choice, index)
    if choice then
      -- Execute the selected menu option
      local option_context = M.create_menu_option_context(choice)
      
      -- Merge cursor context with option context
      local execution_context = vim.tbl_extend("force", context, option_context)
      
      -- Execute command through command execution framework
      local result = command_execution.execute_command(command_name, "menu_option", execution_context)
      
      -- Provide user feedback
      if result.success then
        vim.notify("Command executed successfully", vim.log.levels.INFO)
      else
        vim.notify("Command failed: " .. (result.error or "unknown error"), vim.log.levels.ERROR)
      end
    end
  end)
  
  return { success = true }
end

-- Validate menu definition structure
function M._validate_menu_definition(menu_def)
  if type(menu_def) ~= "table" then
    return false
  end
  
  if not menu_def.options or type(menu_def.options) ~= "table" then
    return false
  end
  
  -- Validate each option
  for _, option in ipairs(menu_def.options) do
    if type(option) ~= "table" or
       not option.key or
       not option.desc or
       not option.cmd then
      return false
    end
  end
  
  return true
end

return M