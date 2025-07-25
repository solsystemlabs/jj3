-- lazy.nvim configuration for jj.nvim
-- This file demonstrates how to configure jj.nvim with lazy.nvim plugin manager

return {
  "username/jj.nvim", -- Replace with actual repository path
  
  -- Lazy loading triggers
  cmd = { "JJ" },                    -- Load when :JJ command is used
  keys = { "<leader>jl" },           -- Load when <leader>jl is pressed
  event = "VeryLazy",                -- Load after all plugins are loaded
  
  -- Optional: only load in jj repositories
  cond = function()
    -- Check if we're in a jj repository
    local handle = io.popen("jj status 2>/dev/null")
    if handle then
      local result = handle:read("*a")
      handle:close()
      return result ~= ""
    end
    return false
  end,
  
  -- Plugin configuration
  config = function()
    require("jj").setup({
      -- Add your configuration options here
      -- See lua/jj/config.lua for available options
    })
  end,
  
  -- Optional: dependencies (if any are added in future)
  dependencies = {
    -- "other/plugin" -- Add dependencies here if needed
  },
}