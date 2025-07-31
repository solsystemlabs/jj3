-- Interactive command detection system for jj.nvim
local M = {}

-- User configuration (can be set via set_user_config)
local user_config = {
  force_interactive = {},
  force_non_interactive = {},
  custom_interactive_flags = {}
}

-- Commands that are always interactive regardless of flags
local ALWAYS_INTERACTIVE = {
  "split", "resolve", "diffedit"
}

-- Commands that are never interactive
local NEVER_INTERACTIVE = {
  "log", "show", "status", "diff", "bookmark", "operation", "op",
  "git", "config", "help", "version", "workspace", "root", "util"
}

-- Conditional interactive command rules
local CONDITIONAL_RULES = {
  describe = function(args)
    -- Interactive unless explicitly non-interactive
    return not M._has_any_flag(args, {"-m", "--message", "--stdin", "--no-edit"})
  end,
  
  squash = function(args)
    -- Only interactive with explicit flags
    return M._has_any_flag(args, {"-i", "--interactive", "--tool"})
  end,
  
  new = function(args)
    -- Interactive unless message provided
    return not M._has_any_flag(args, {"-m", "--message"})
  end,
  
  commit = function(args)
    -- Interactive unless message provided
    return not M._has_any_flag(args, {"-m", "--message"})
  end,
  
  rebase = function(args)  
    -- Interactive with explicit flag or when no destination specified
    return M._has_any_flag(args, {"-i", "--interactive"}) or
           not M._has_any_flag(args, {"-d", "--destination"})
  end
}

-- Main function to determine if a command is interactive
function M.is_interactive_command(cmd, args)
  -- Handle edge cases
  if not cmd or type(cmd) ~= "string" or cmd == "" then
    return false
  end
  
  -- Ensure args is a table
  if not args or type(args) ~= "table" then
    args = {}
  end
  
  -- Check user overrides first (highest priority)
  if vim.tbl_contains(user_config.force_interactive, cmd) then
    return true
  end
  
  if vim.tbl_contains(user_config.force_non_interactive, cmd) then
    return false
  end
  
  -- Check custom interactive flags
  if user_config.custom_interactive_flags[cmd] then
    local custom_flags = user_config.custom_interactive_flags[cmd]
    if M._has_any_flag(args, custom_flags) then
      return true
    end
  end
  
  -- Check always interactive commands
  if vim.tbl_contains(ALWAYS_INTERACTIVE, cmd) then
    return true
  end
  
  -- Check never interactive commands
  if vim.tbl_contains(NEVER_INTERACTIVE, cmd) then
    return false
  end
  
  -- Check conditional rules
  if CONDITIONAL_RULES[cmd] then
    return CONDITIONAL_RULES[cmd](args)
  end
  
  -- Default: unknown commands are non-interactive
  return false
end

-- Set user configuration for interactive detection
function M.set_user_config(config)
  if not config or type(config) ~= "table" then
    return false
  end
  
  -- Merge user config with defaults
  user_config.force_interactive = config.force_interactive or {}
  user_config.force_non_interactive = config.force_non_interactive or {}
  user_config.custom_interactive_flags = config.custom_interactive_flags or {}
  
  return true
end

-- Get current user configuration
function M.get_user_config()
  return vim.deepcopy(user_config)
end

-- Reset configuration to defaults
function M.reset_config()
  user_config = {
    force_interactive = {},
    force_non_interactive = {},
    custom_interactive_flags = {}
  }
end

-- Utility function to check if args contains a specific flag
function M._has_flag(args, flag)
  if not args or type(args) ~= "table" then
    return false
  end
  
  for _, arg in ipairs(args) do
    if type(arg) == "string" then
      -- Exact match
      if arg == flag then
        return true
      end
      
      -- Handle combined short flags (e.g., -im contains -i)
      if flag:match("^%-[^%-]$") and arg:match("^%-[^%-]+$") then
        local flag_char = flag:sub(2, 2)
        if arg:find(flag_char) then
          return true
        end
      end
    end
  end
  
  return false
end

-- Utility function to check if args contains any of the specified flags
function M._has_any_flag(args, flags)
  if not args or type(args) ~= "table" or not flags or type(flags) ~= "table" then
    return false
  end
  
  for _, flag in ipairs(flags) do
    if M._has_flag(args, flag) then
      return true
    end
  end
  
  return false
end

-- Get list of always interactive commands (for testing/debugging)
function M.get_always_interactive_commands()
  return vim.deepcopy(ALWAYS_INTERACTIVE)
end

-- Get list of never interactive commands (for testing/debugging)
function M.get_never_interactive_commands()
  return vim.deepcopy(NEVER_INTERACTIVE)
end

-- Get conditional rules (for testing/debugging)
function M.get_conditional_commands()
  return vim.tbl_keys(CONDITIONAL_RULES)
end

return M