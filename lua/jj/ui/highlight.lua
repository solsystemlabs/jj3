-- Highlight group definitions for jj.nvim navigation
local M = {}

-- Define default highlight groups for navigation
function M.setup_navigation_highlights()
  -- Define the JJCommitBlock highlight group with a subtle background
  vim.api.nvim_set_hl(0, "JJCommitBlock", {
    bg = "#3c3836", -- Subtle dark background 
    fg = nil,       -- Keep original text color
    bold = false,
    underline = false,
    italic = false
  })
  
  -- Alternative highlight groups for different themes
  -- Users can override these in their config
  vim.api.nvim_set_hl(0, "JJCommitBlockLight", {
    bg = "#f2f2f2", -- Light background for light themes
    fg = nil,
  })
  
  vim.api.nvim_set_hl(0, "JJCommitBlockContrast", {
    bg = "#2e2e2e", -- Higher contrast background
    fg = "#ffffff",
    bold = true
  })
end

-- Set custom highlight group for navigation
function M.set_navigation_highlight(highlight_group)
  if not highlight_group or type(highlight_group) ~= "string" then
    return false
  end
  
  -- Update any existing navigation modules to use the new highlight group
  -- This would require modifying the navigation module's HIGHLIGHT_GROUP constant
  
  return true
end

-- Get available highlight groups
function M.get_available_highlights()
  return {
    "JJCommitBlock",        -- Default subtle highlight
    "JJCommitBlockLight",   -- For light color schemes  
    "JJCommitBlockContrast" -- High contrast option
  }
end

-- Check if a highlight group exists
function M.highlight_group_exists(group_name)
  if not group_name then
    return false
  end
  
  local ok, hl = pcall(vim.api.nvim_get_hl_by_name, group_name, true)
  return ok and next(hl) ~= nil
end

-- Auto-setup highlights based on current colorscheme
function M.auto_setup_highlights()
  -- Get current background setting
  local bg = vim.o.background
  
  if bg == "light" then
    -- Use light theme highlights
    vim.api.nvim_set_hl(0, "JJCommitBlock", {
      bg = "#e8e8e8",
      fg = nil
    })
  else
    -- Use dark theme highlights (default)
    vim.api.nvim_set_hl(0, "JJCommitBlock", {
      bg = "#3c3836",
      fg = nil
    })
  end
end

-- Create autocmd to adjust highlights when colorscheme changes
function M.setup_colorscheme_autocmd()
  vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = function()
      M.auto_setup_highlights()
    end,
    group = vim.api.nvim_create_augroup("JJNavigationHighlights", { clear = true })
  })
end

return M