-- Tests for ANSI color processing functionality
require("helpers.vim_mock")
local test_repo = require("helpers.test_repository")

-- Load the ANSI processor module
local ansi = dofile("lua/jj/utils/ansi.lua")

describe("ANSI Color Processor", function()
  describe("ANSI escape sequence parsing", function()
    it("should parse basic ANSI color codes", function()
      local text = "\027[31mred text\027[0m normal text"
      local parsed = ansi.parse_ansi_text(text)
      
      assert.is_not_nil(parsed)
      assert.is_table(parsed)
      assert.is_true(#parsed >= 2) -- Should have at least 2 segments
      
      -- First segment should be colored
      assert.equals("red text", parsed[1].text)
      assert.is_not_nil(parsed[1].ansi_code)
      assert.equals("\027[31m", parsed[1].ansi_code)
      
      -- Second segment should be normal
      assert.equals(" normal text", parsed[2].text)
      assert.is_nil(parsed[2].ansi_code)
    end)

    it("should handle multiple ANSI codes in sequence", function()
      local text = "\027[1m\027[31mbold red\027[0m\027[32mgreen\027[0m"
      local parsed = ansi.parse_ansi_text(text)
      
      assert.is_not_nil(parsed)
      assert.is_table(parsed)
      assert.is_true(#parsed >= 2)
      
      -- Should preserve all ANSI codes
      local found_bold_red = false
      local found_green = false
      
      for _, segment in ipairs(parsed) do
        if segment.text == "bold red" then
          found_bold_red = true
          assert.is_not_nil(segment.ansi_code)
        elseif segment.text == "green" then
          found_green = true
          assert.is_not_nil(segment.ansi_code)
        end
      end
      
      assert.is_true(found_bold_red)
      assert.is_true(found_green)
    end)

    it("should handle complex jj log colored output", function()
      local colored_output = test_repo.load_snapshot("colored_log")
      local first_line = colored_output:match("[^\n]+")
      
      local parsed = ansi.parse_ansi_text(first_line)
      
      assert.is_not_nil(parsed)
      assert.is_table(parsed)
      assert.is_true(#parsed > 1) -- Should have multiple colored segments
      
      -- Should contain various ANSI codes found in jj output
      local has_ansi_codes = false
      for _, segment in ipairs(parsed) do
        if segment.ansi_code then
          has_ansi_codes = true
          break
        end
      end
      
      assert.is_true(has_ansi_codes)
    end)

    it("should handle text without ANSI codes", function()
      local text = "plain text without colors"
      local parsed = ansi.parse_ansi_text(text)
      
      assert.is_not_nil(parsed)
      assert.is_table(parsed)
      assert.equals(1, #parsed)
      assert.equals("plain text without colors", parsed[1].text)
      assert.is_nil(parsed[1].ansi_code)
    end)

    it("should handle empty or nil input", function()
      local parsed_empty = ansi.parse_ansi_text("")
      assert.is_not_nil(parsed_empty)
      assert.is_table(parsed_empty)
      assert.equals(0, #parsed_empty)
      
      local parsed_nil = ansi.parse_ansi_text(nil)
      assert.is_not_nil(parsed_nil)
      assert.is_table(parsed_nil)
      assert.equals(0, #parsed_nil)
    end)
  end)

  describe("ANSI to Neovim highlight mapping", function()
    it("should map basic ANSI colors to Neovim highlight groups", function()
      local red_code = "\027[31m"
      local highlight_group = ansi.ansi_to_highlight_group(red_code)
      
      assert.is_not_nil(highlight_group)
      assert.is_string(highlight_group)
      assert.is_true(highlight_group:find("JJRed") ~= nil or highlight_group:find("red") ~= nil)
    end)

    it("should map ANSI bold to Neovim bold highlight", function()
      local bold_code = "\027[1m"
      local highlight_group = ansi.ansi_to_highlight_group(bold_code)
      
      assert.is_not_nil(highlight_group)
      assert.is_string(highlight_group)
      assert.is_true(highlight_group:find("Bold") ~= nil or highlight_group:find("bold") ~= nil)
    end)

    it("should handle complex ANSI codes", function()
      local complex_code = "\027[1m\027[38;5;9m" -- bold + 256 color
      local highlight_group = ansi.ansi_to_highlight_group(complex_code)
      
      assert.is_not_nil(highlight_group)
      assert.is_string(highlight_group)
    end)

    it("should return default for unknown ANSI codes", function()
      local unknown_code = "\027[999m"
      local highlight_group = ansi.ansi_to_highlight_group(unknown_code)
      
      assert.is_not_nil(highlight_group)
      assert.is_string(highlight_group)
    end)

    it("should create consistent highlight group names", function()
      local red_code = "\027[31m"
      local group1 = ansi.ansi_to_highlight_group(red_code)
      local group2 = ansi.ansi_to_highlight_group(red_code)
      
      assert.equals(group1, group2) -- Should be consistent
    end)
  end)

  describe("Neovim highlight group management", function()
    it("should create highlight groups for ANSI colors", function()
      local created_groups = ansi.create_highlight_groups()
      
      assert.is_not_nil(created_groups)
      assert.is_table(created_groups)
      assert.is_true(#created_groups > 0)
      
      -- Should have basic color groups
      local has_basic_colors = false
      for _, group in ipairs(created_groups) do
        if group.name:find("Red") or group.name:find("Green") or group.name:find("Blue") then
          has_basic_colors = true
          break
        end
      end
      
      assert.is_true(has_basic_colors)
    end)

    it("should define highlight group properties", function()
      local groups = ansi.create_highlight_groups()
      
      for _, group in ipairs(groups) do
        assert.is_not_nil(group.name)
        assert.is_string(group.name)
        assert.is_not_nil(group.definition)
        assert.is_table(group.definition)
      end
    end)

    it("should apply highlight groups to buffer", function()
      local buffer_id = 1 -- Mock buffer ID
      local highlights = {
        {line = 0, col_start = 0, col_end = 5, group = "JJRed"},
        {line = 0, col_start = 6, col_end = 10, group = "JJGreen"}
      }
      
      local result = ansi.apply_highlights_to_buffer(buffer_id, highlights)
      
      assert.is_not_nil(result)
      assert.is_true(result.success)
    end)
  end)

  describe("colored text processing", function()
    it("should process colored jj log output for buffer display", function()
      local colored_output = test_repo.load_snapshot("colored_log")
      local lines = {}
      for line in colored_output:gmatch("[^\n]+") do
        table.insert(lines, line)
      end
      
      local processed = ansi.process_colored_lines_for_buffer(lines)
      
      assert.is_not_nil(processed)
      assert.is_table(processed)
      assert.is_not_nil(processed.lines)
      assert.is_not_nil(processed.highlights)
      
      -- Should have same number of lines
      assert.equals(#lines, #processed.lines)
      
      -- Should have highlight information
      assert.is_true(#processed.highlights > 0)
    end)

    it("should preserve text content while extracting colors", function()
      local text = "\027[31mHello\027[0m \027[32mWorld\027[0m"
      local processed = ansi.process_colored_lines_for_buffer({text})
      
      assert.is_not_nil(processed)
      assert.equals(1, #processed.lines)
      assert.equals("Hello World", processed.lines[1])
      
      -- Should have highlight information for colored parts
      assert.is_true(#processed.highlights >= 2)
    end)

    it("should handle lines without colors", function()
      local plain_lines = {"Line 1", "Line 2", "Line 3"}
      local processed = ansi.process_colored_lines_for_buffer(plain_lines)
      
      assert.is_not_nil(processed)
      assert.equals(3, #processed.lines)
      assert.equals("Line 1", processed.lines[1])
      assert.equals("Line 2", processed.lines[2])
      assert.equals("Line 3", processed.lines[3])
      
      -- Should have no highlights for plain text
      assert.equals(0, #processed.highlights)
    end)
  end)

  describe("color scheme integration", function()
    it("should provide default color mappings", function()
      local color_map = ansi.get_default_color_mappings()
      
      assert.is_not_nil(color_map)
      assert.is_table(color_map)
      
      -- Should have mappings for basic ANSI colors
      assert.is_not_nil(color_map["31"]) -- Red
      assert.is_not_nil(color_map["32"]) -- Green
      assert.is_not_nil(color_map["34"]) -- Blue
    end)

    it("should allow custom color mappings", function()
      local custom_mappings = {
        ["31"] = {fg = "#FF0000", style = "bold"},
        ["32"] = {fg = "#00FF00"}
      }
      
      ansi.set_custom_color_mappings(custom_mappings)
      local current_mappings = ansi.get_current_color_mappings()
      
      assert.is_not_nil(current_mappings["31"])
      assert.equals("#FF0000", current_mappings["31"].fg)
      assert.equals("bold", current_mappings["31"].style)
    end)

    it("should integrate with Neovim colorscheme", function()
      local colorscheme_colors = ansi.detect_colorscheme_colors()
      
      assert.is_not_nil(colorscheme_colors)
      assert.is_table(colorscheme_colors)
      
      -- Should detect at least some basic colors
      assert.is_true(next(colorscheme_colors) ~= nil)
    end)
  end)

  describe("performance and edge cases", function()
    it("should handle large colored output efficiently", function()
      -- Create large colored text
      local large_text = ""
      for i = 1, 1000 do
        large_text = large_text .. "\027[3" .. (i % 7 + 1) .. "mLine " .. i .. "\027[0m\n"
      end
      
      local lines = {}
      for line in large_text:gmatch("[^\n]+") do
        table.insert(lines, line)
      end
      
      local start_time = os.clock()
      local processed = ansi.process_colored_lines_for_buffer(lines)
      local end_time = os.clock()
      
      assert.is_not_nil(processed)
      assert.equals(1000, #processed.lines)
      
      -- Should complete in reasonable time (< 1 second)
      assert.is_true(end_time - start_time < 1.0)
    end)

    it("should handle malformed ANSI sequences", function()
      local malformed_text = "\027[incomplete \027[31;mpartial\027[0m \027[999invalid\027[0m"
      local parsed = ansi.parse_ansi_text(malformed_text)
      
      assert.is_not_nil(parsed)
      assert.is_table(parsed)
      -- Should not crash and should handle gracefully
    end)

    it("should handle nested ANSI sequences", function()
      local nested_text = "\027[1m\027[31mbold red\027[32mstill bold green\027[0m"
      local parsed = ansi.parse_ansi_text(nested_text)
      
      assert.is_not_nil(parsed)
      assert.is_table(parsed)
      assert.is_true(#parsed > 0)
    end)
  end)
end)