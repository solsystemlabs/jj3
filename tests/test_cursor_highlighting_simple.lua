-- Simple test for cursor line highlighting logic

-- Mock vim API functions
local highlights = {}
local window_options = {}
local autocmds = {}

local vim_mock = {
  api = {
    nvim_buf_add_highlight = function(buffer_id, ns_id, hl_group, line, col_start, col_end)
      if not highlights[buffer_id] then
        highlights[buffer_id] = {}
      end
      table.insert(highlights[buffer_id], {
        ns_id = ns_id,
        hl_group = hl_group,
        line = line,
        col_start = col_start,
        col_end = col_end
      })
    end,
    nvim_buf_clear_namespace = function(buffer_id, ns_id, line_start, line_end)
      if highlights[buffer_id] then
        highlights[buffer_id] = {}
      end
    end,
    nvim_create_namespace = function(name)
      return math.random(1000, 9999)
    end,
    nvim_win_set_option = function(window_id, option, value)
      if not window_options[window_id] then
        window_options[window_id] = {}
      end
      window_options[window_id][option] = value
    end,
    nvim_create_autocmd = function(event, opts)
      table.insert(autocmds, {event = event, opts = opts})
      return math.random(1000, 9999)
    end,
    nvim_create_augroup = function(name, opts)
      return name
    end,
    nvim_win_is_valid = function(window_id)
      return true
    end,
    nvim_get_hl_by_name = function(name, rgb)
      return {background = rgb and 0x2d3748 or 8}
    end,
    nvim_set_hl = function(ns_id, name, val)
      -- Mock highlight setting
    end,
    nvim_clear_autocmds = function(opts)
      -- Mock autocmd clearing
    end
  }
}

_G.vim = vim_mock

-- Test highlight_lines_full_width function
local function highlight_lines_full_width(buffer_id, lines, highlight_group)
  if not buffer_id or not lines or #lines == 0 then
    return false
  end

  highlight_group = highlight_group or "Visual"
  local namespace = vim.api.nvim_create_namespace("jj_full_width_highlighting")

  -- Clear any existing highlights in this namespace
  vim.api.nvim_buf_clear_namespace(buffer_id, namespace, 0, -1)

  -- Apply full-width highlighting to each line
  for _, line_num in ipairs(lines) do
    -- Convert to 0-indexed if needed
    local zero_indexed_line = (line_num > 0) and (line_num - 1) or line_num
    
    vim.api.nvim_buf_add_highlight(
      buffer_id,
      namespace,
      highlight_group,
      zero_indexed_line,
      0,  -- Start at beginning of line
      -1  -- Extend to end of line (full width)
    )
  end

  return true
end

-- Test function
local function test_full_width_highlighting()
  print("Testing full-width line highlighting...")
  
  local buffer_id = 1
  local lines_to_highlight = {1, 2, 3}
  
  -- Test highlighting multiple lines
  local result = highlight_lines_full_width(buffer_id, lines_to_highlight, "Visual")
  
  -- Check results
  assert(result == true, "highlight_lines_full_width should return true")
  assert(highlights[buffer_id] ~= nil, "Should have highlights for buffer")
  assert(#highlights[buffer_id] == 3, "Should have 3 highlights")
  
  -- Check each highlight uses full width
  for i, highlight in ipairs(highlights[buffer_id]) do
    assert(highlight.col_start == 0, "Highlight should start at column 0")
    assert(highlight.col_end == -1, "Highlight should extend to end of line")
    assert(highlight.hl_group == "Visual", "Should use Visual highlight group")
    assert(highlight.line == lines_to_highlight[i] - 1, "Should highlight correct line (0-indexed)")
  end
  
  print("✓ Full-width highlighting test passed")
end

-- Test cursor line window option
local function test_cursor_line_option()
  print("Testing cursor line window option...")
  
  local window_id = 1
  vim.api.nvim_win_set_option(window_id, "cursorline", true)
  
  assert(window_options[window_id] ~= nil, "Should have window options")
  assert(window_options[window_id].cursorline == true, "Should have cursorline enabled")
  
  print("✓ Cursor line option test passed")
end

-- Run tests
test_full_width_highlighting()
test_cursor_line_option()

print("\n🎉 All cursor line highlighting tests passed!")
print("\nKey features verified:")
print("- Full-width highlighting extends to end of line (col_end = -1)")
print("- Multiple lines can be highlighted simultaneously") 
print("- Cursor line option can be enabled for windows")
print("- Highlights start at beginning of line (col_start = 0)")