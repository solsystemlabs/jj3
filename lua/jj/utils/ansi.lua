-- ANSI color processing utilities for jj.nvim
local M = {}

-- Default ANSI color mappings to Neovim colors (more terminal-like colors)
local DEFAULT_COLOR_MAPPINGS = {
	["30"] = { fg = "#282828" }, -- Black
	["31"] = { fg = "#cc241d" }, -- Red
	["32"] = { fg = "#98971a" }, -- Green
	["33"] = { fg = "#d79921" }, -- Yellow
	["34"] = { fg = "#458588" }, -- Blue
	["35"] = { fg = "#b16286" }, -- Magenta
	["36"] = { fg = "#689d6a" }, -- Cyan
	["37"] = { fg = "#a89984" }, -- White
	["90"] = { fg = "#928374" }, -- Bright Black (Gray)
	["91"] = { fg = "#fb4934" }, -- Bright Red
	["92"] = { fg = "#b8bb26" }, -- Bright Green
	["93"] = { fg = "#fabd2f" }, -- Bright Yellow
	["94"] = { fg = "#83a598" }, -- Bright Blue
	["95"] = { fg = "#d3869b" }, -- Bright Magenta
	["96"] = { fg = "#8ec07c" }, -- Bright Cyan
	["97"] = { fg = "#ebdbb2" }, -- Bright White
	["1"] = { style = "bold" },
	["4"] = { style = "underline" },
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
						ansi_code = current_ansi,
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
					ansi_code = current_ansi,
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

	local i = 1
	while i <= #color_codes do
		local code = color_codes[i]

		if code == "1" then
			group_name = group_name .. "Bold"
			has_style = true
		elseif code == "4" then
			group_name = group_name .. "Underline"
			has_style = true
		elseif tonumber(code) >= 30 and tonumber(code) <= 37 then
			-- Standard colors
			local color_names = {
				["30"] = "Black",
				["31"] = "Red",
				["32"] = "Green",
				["33"] = "Yellow",
				["34"] = "Blue",
				["35"] = "Magenta",
				["36"] = "Cyan",
				["37"] = "White",
			}
			group_name = group_name .. (color_names[code] or "Color" .. code)
		elseif tonumber(code) >= 90 and tonumber(code) <= 97 then
			-- Bright colors
			local bright_color_names = {
				["90"] = "BrightBlack",
				["91"] = "BrightRed",
				["92"] = "BrightGreen",
				["93"] = "BrightYellow",
				["94"] = "BrightBlue",
				["95"] = "BrightMagenta",
				["96"] = "BrightCyan",
				["97"] = "BrightWhite",
			}
			group_name = group_name .. (bright_color_names[code] or "BrightColor" .. code)
		elseif code == "38" and i < #color_codes then
			-- 256-color mode: 38;5;N
			if color_codes[i + 1] == "5" and i + 2 <= #color_codes then
				local color_num = color_codes[i + 2]
				group_name = group_name .. "ExtendedColor5Color" .. color_num
				i = i + 2 -- Skip the next two codes (5 and color number)
			else
				group_name = group_name .. "Extended"
			end
		else
			group_name = group_name .. "Color" .. code
		end

		i = i + 1
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
			definition = hl_def,
		})

		-- Force create the highlight group in Neovim with default namespace 0
		-- Always create the group even if empty (will use default foreground)
		if next(hl_def) then
			vim.api.nvim_set_hl(0, group_name, hl_def)
		else
			-- For reset codes or empty definitions, ensure group exists
			vim.api.nvim_set_hl(0, group_name, {})
		end
	end

	-- Also create some common combination groups that jj might use
	local combination_groups = {
		{ name = "JJRedBold", def = { fg = "#fb4934", bold = true } },
		{ name = "JJGreenBold", def = { fg = "#b8bb26", bold = true } },
		{ name = "JJYellowBold", def = { fg = "#fabd2f", bold = true } },
		{ name = "JJBlueBold", def = { fg = "#83a598", bold = true } },
		{ name = "JJMagentaBold", def = { fg = "#d3869b", bold = true } },
		{ name = "JJCyanBold", def = { fg = "#8ec07c", bold = true } },
		{ name = "JJDefault", def = {} },
		-- Extended color mappings for 256-color palette (basic colors 0-15)
		{ name = "JJExtendedColor5Color0", def = { fg = "#000000" } }, -- Black
		{ name = "JJExtendedColor5Color1", def = { fg = "#cc241d" } }, -- Red
		{ name = "JJExtendedColor5Color2", def = { fg = "#98971a" } }, -- Green
		{ name = "JJExtendedColor5Color3", def = { fg = "#d79921" } }, -- Yellow
		{ name = "JJExtendedColor5Color4", def = { fg = "#458588" } }, -- Blue
		{ name = "JJExtendedColor5Color5", def = { fg = "#b16286" } }, -- Magenta
		{ name = "JJExtendedColor5Color6", def = { fg = "#689d6a" } }, -- Cyan
		{ name = "JJExtendedColor5Color7", def = { fg = "#a89984" } }, -- White
		{ name = "JJExtendedColor5Color8", def = { fg = "#928374" } }, -- Bright Black
		{ name = "JJExtendedColor5Color9", def = { fg = "#fb4934" } }, -- Bright Red
		{ name = "JJExtendedColor5Color10", def = { fg = "#b8bb26" } }, -- Bright Green
		{ name = "JJExtendedColor5Color11", def = { fg = "#fabd2f" } }, -- Bright Yellow
		{ name = "JJExtendedColor5Color12", def = { fg = "#83a598" } }, -- Bright Blue
		{ name = "JJExtendedColor5Color13", def = { fg = "#d3869b" } }, -- Bright Magenta
		{ name = "JJExtendedColor5Color14", def = { fg = "#8ec07c" } }, -- Bright Cyan
		{ name = "JJExtendedColor5Color15", def = { fg = "#ebdbb2" } }, -- Bright White
		-- Some common 256-color palette colors that jj might use
		{ name = "JJExtendedColor5Color240", def = { fg = "#585858" } }, -- Dark gray
		{ name = "JJExtendedColor5Color244", def = { fg = "#808080" } }, -- Medium gray
		{ name = "JJExtendedColor5Color250", def = { fg = "#bcbcbc" } }, -- Light gray
	}

	for _, group in ipairs(combination_groups) do
		vim.api.nvim_set_hl(0, group.name, group.def)
		table.insert(groups, { name = group.name, definition = group.def })
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
			vim.api.nvim_buf_add_highlight(buffer_id, ns_id, hl.group, hl.line, hl.col_start, hl.col_end)
		end)

		if not ok then
			success = false
			table.insert(errors, err)
		end
	end

	return {
		success = success,
		errors = errors,
		namespace_id = ns_id,
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
					ansi_code = segment.ansi_code,
				})
			end

			col_offset = end_col
		end

		table.insert(processed_lines, clean_line)
	end

	return {
		lines = processed_lines,
		highlights = highlights,
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
	local basic_groups = { "Normal", "Comment", "String", "Number", "Function" }

	for _, group in ipairs(basic_groups) do
		local hl = vim.api.nvim_get_hl_by_name(group, true)
		if hl then
			colors[group] = {
				fg = hl.foreground and string.format("#%06x", hl.foreground) or nil,
				bg = hl.background and string.format("#%06x", hl.background) or nil,
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

-- Apply ANSI highlights to a single line in a buffer
function M.apply_ansi_highlights_to_line(buffer_id, ns_id, line_idx, line_text)
	if not buffer_id or not line_text or line_text == "" then
		return
	end

	local segments = M.parse_ansi_text(line_text)
	local col_offset = 0

	for _, segment in ipairs(segments) do
		local text = segment.text
		local start_col = col_offset
		local end_col = col_offset + #text

		-- Add highlight if segment has ANSI code
		if segment.ansi_code then
			local highlight_group = M.ansi_to_highlight_group(segment.ansi_code)

			-- Apply highlight to buffer
			local ok, err = pcall(function()
				vim.api.nvim_buf_add_highlight(buffer_id, ns_id, highlight_group, line_idx, start_col, end_col)
			end)

			if not ok then
				-- Silently handle highlight errors to avoid breaking rendering
				-- Could log this in debug mode if needed
			end
		end

		col_offset = end_col
	end
end

-- Initialize ANSI color processing
function M.setup()
	-- Create default highlight groups
	M.create_highlight_groups()

	return true
end

return M
