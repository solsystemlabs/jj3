-- ANSI color processing utilities for jj.nvim
local M = {}

-- Default ANSI color mappings to Neovim colors
local DEFAULT_COLOR_MAPPINGS = {
  ["30"] = {fg = "#000000"}, -- Black
  ["31"] = {fg = "#FF0000"}, -- Red  
  ["32"] = {fg = "#00FF00"}, -- Green
  ["33"] = {fg = "#FFFF00"}, -- Yellow
  ["34"] = {fg = "#0000FF"}, -- Blue
  ["35"] = {fg = "#FF00FF"}, -- Magenta
  ["36"] = {fg = "#00FFFF"}, -- Cyan
  ["37"] = {fg = "#FFFFFF"}, -- White
  ["90"] = {fg = "#808080"}, -- Bright Black (Gray)
  ["91"] = {fg = "#FF8080"}, -- Bright Red
  ["92"] = {fg = "#80FF80"}, -- Bright Green
  ["93"] = {fg = "#FFFF80"}, -- Bright Yellow
  ["94"] = {fg = "#8080FF"}, -- Bright Blue
  ["95"] = {fg = "#FF80FF"}, -- Bright Magenta
  ["96"] = {fg = "#80FFFF"}, -- Bright Cyan
  ["97"] = {fg = "#FFFFFF"}, -- Bright White
  ["1"] = {style = "bold"},
  ["4"] = {style = "underline"},
  ["0"] = {}, -- Reset
}

-- Current color mappings (can be customized)
local current_color_mappings = vim.deepcopy(DEFAULT_COLOR_MAPPINGS)

-- Cache for highlight group names
local highlight_group_cache = {}

-- Parse ANSI escape sequences from text
function M.parse_ansi_text(text)
  local segments = {}
  
  if not text or text == "" then
    return segments
  end
  
  local pos = 1
  local current_ansi = nil
  
  while pos <= #text do
    -- Look for ANSI escape sequence
    local esc_start, esc_end = text:find("\027%[[%d;]*m", pos)
    
    if esc_start then
      -- Add text before escape sequence
      if esc_start > pos then
        local text_segment = text:sub(pos, esc_start - 1)
        if text_segment ~= "" then
          table.insert(segments, {
            text = text_segment,
            ansi_code = current_ansi
          })
        end
      end
      
      -- Extract the ANSI code
      local ansi_code = text:sub(esc_start, esc_end)
      
      -- Update current ANSI state
      if ansi_code == "\027[0m" then
        current_ansi = nil -- Reset
      else
        current_ansi = ansi_code
      end
      
      pos = esc_end + 1
    else
      -- No more escape sequences, add remaining text
      local remaining_text = text:sub(pos)
      if remaining_text ~= "" then
        table.insert(segments, {
          text = remaining_text,
          ansi_code = current_ansi
        })
      end
      break
    end
  end
  
  return segments
end

-- Convert ANSI code to Neovim highlight group name
function M.ansi_to_highlight_group(ansi_code)
  if not ansi_code then
    return "Normal"
  end
  
  -- Check cache first
  if highlight_group_cache[ansi_code] then
    return highlight_group_cache[ansi_code]
  end
  
  -- Extract color codes from ANSI sequence
  local color_codes = {}
  for code in ansi_code:gmatch("(%d+)") do
    table.insert(color_codes, code)
  end
  
  -- Generate highlight group name
  local group_name = "JJ"
  local has_style = false
  
  for _, code in ipairs(color_codes) do
    if code == "1" then
      group_name = group_name .. "Bold"
      has_style = true
    elseif code == "4" then
      group_name = group_name .. "Underline"
      has_style = true
    elseif tonumber(code) >= 30 and tonumber(code) <= 37 then
      -- Standard colors
      local color_names = {
        ["30"] = "Black", ["31"] = "Red", ["32"] = "Green", ["33"] = "Yellow",
        ["34"] = "Blue", ["35"] = "Magenta", ["36"] = "Cyan", ["37"] = "White"
      }
      group_name = group_name .. (color_names[code] or "Color" .. code)
    elseif tonumber(code) >= 90 and tonumber(code) <= 97 then
      -- Bright colors
      local bright_color_names = {
        ["90"] = "BrightBlack", ["91"] = "BrightRed", ["92"] = "BrightGreen", ["93"] = "BrightYellow",
        ["94"] = "BrightBlue", ["95"] = "BrightMagenta", ["96"] = "BrightCyan", ["97"] = "BrightWhite"
      }
      group_name = group_name .. (bright_color_names[code] or "BrightColor" .. code)
    elseif code == "38" then
      -- 256-color or RGB color (simplified)
      group_name = group_name .. "Extended"
    else
      group_name = group_name .. "Color" .. code
    end
  end
  
  -- Default if no specific style/color found
  if group_name == "JJ" then
    group_name = "JJDefault"
  end
  
  -- Cache the result
  highlight_group_cache[ansi_code] = group_name
  
  return group_name
end

-- Create highlight groups for ANSI colors
function M.create_highlight_groups()
  local groups = {}
  
  -- Create highlight groups for all known ANSI codes
  for ansi_code, color_def in pairs(current_color_mappings) do
    local group_name = M.ansi_to_highlight_group("\027[" .. ansi_code .. "m")
    
    -- Build highlight definition
    local hl_def = {}
    if color_def.fg then
      hl_def.fg = color_def.fg
    end
    if color_def.bg then
      hl_def.bg = color_def.bg
    end
    if color_def.style then
      if color_def.style == "bold" then
        hl_def.bold = true
      elseif color_def.style == "underline" then
        hl_def.underline = true
      end
    end
    
    table.insert(groups, {
      name = group_name,
      definition = hl_def
    })
    
    -- Actually create the highlight group in Neovim
    if next(hl_def) then
      vim.api.nvim_set_hl(0, group_name, hl_def)
    end
  end
  
  return groups
end

-- Apply highlights to a Neovim buffer
function M.apply_highlights_to_buffer(buffer_id, highlights)
  local success = true
  local errors = {}
  
  -- Create namespace for jj highlights
  local ns_id = vim.api.nvim_create_namespace("jj_ansi_colors")
  
  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(buffer_id, ns_id, 0, -1)
  
  -- Apply each highlight
  for _, hl in ipairs(highlights) do
    local ok, err = pcall(function()
      vim.api.nvim_buf_add_highlight(
        buffer_id,
        ns_id,
        hl.group,
        hl.line,
        hl.col_start,
        hl.col_end
      )
    end)
    
    if not ok then
      success = false
      table.insert(errors, err)
    end
  end
  
  return {
    success = success,
    errors = errors,
    namespace_id = ns_id
  }
end

-- Process colored lines for buffer display
function M.process_colored_lines_for_buffer(lines)
  local processed_lines = {}
  local highlights = {}
  
  for line_idx, line in ipairs(lines) do
    local segments = M.parse_ansi_text(line)
    local clean_line = ""
    local col_offset = 0
    
    for _, segment in ipairs(segments) do
      local text = segment.text
      local start_col = col_offset
      local end_col = col_offset + #text
      
      -- Add text to clean line
      clean_line = clean_line .. text
      
      -- Add highlight if segment has ANSI code
      if segment.ansi_code then
        local highlight_group = M.ansi_to_highlight_group(segment.ansi_code)
        table.insert(highlights, {
          line = line_idx - 1, -- 0-based for nvim API
          col_start = start_col,
          col_end = end_col,
          group = highlight_group,
          ansi_code = segment.ansi_code
        })
      end
      
      col_offset = end_col
    end
    
    table.insert(processed_lines, clean_line)
  end
  
  return {
    lines = processed_lines,
    highlights = highlights
  }
end

-- Get default color mappings
function M.get_default_color_mappings()
  return vim.deepcopy(DEFAULT_COLOR_MAPPINGS)
end

-- Set custom color mappings
function M.set_custom_color_mappings(mappings)
  current_color_mappings = vim.tbl_deep_extend("force", DEFAULT_COLOR_MAPPINGS, mappings)
  
  -- Clear highlight group cache since mappings changed
  highlight_group_cache = {}
end

-- Get current color mappings
function M.get_current_color_mappings()
  return vim.deepcopy(current_color_mappings)
end

-- Detect colorscheme colors (basic implementation)
function M.detect_colorscheme_colors()
  local colors = {}
  
  -- Try to get some basic highlight groups
  local basic_groups = {"Normal", "Comment", "String", "Number", "Function"}
  
  for _, group in ipairs(basic_groups) do
    local hl = vim.api.nvim_get_hl_by_name(group, true)
    if hl then
      colors[group] = {
        fg = hl.foreground and string.format("#%06x", hl.foreground) or nil,
        bg = hl.background and string.format("#%06x", hl.background) or nil
      }
    end
  end
  
  return colors
end

-- Strip ANSI codes (utility function, also available in parser)
function M.strip_ansi_codes(text)
  if not text then
    return ""
  end
  
  return text:gsub("\027%[[%d;]*m", "")
end

-- Initialize ANSI color processing
function M.setup()
  -- Create default highlight groups
  M.create_highlight_groups()
  
  return true
end

return M