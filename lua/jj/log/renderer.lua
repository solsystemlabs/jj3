-- JJ log rendering functionality for jj.nvim
local M = {}

-- Import ANSI processing utilities
local ansi = require("jj.utils.ansi")

-- Process raw jj log output for buffer display
function M.process_log_output(raw_colored_output)
	if not raw_colored_output or raw_colored_output == "" then
		return {
			lines = {},
			highlights = {},
		}
	end

	-- Split into lines
	local raw_lines = {}
	for line in raw_colored_output:gmatch("[^\n]*") do
		if line ~= "" then
			table.insert(raw_lines, line)
		end
	end

	-- Use ANSI processor to convert colored lines to clean lines + highlights
	return ansi.process_colored_lines_for_buffer(raw_lines)
end

-- Generate a display line from a commit object (fallback for testing)
function M.generate_display_line(commit)
	if not commit then
		return ""
	end

	local parts = {}

	-- Start with graph characters (e.g. "○  " or "@  ")
	if commit.graph_line then
		table.insert(parts, commit.graph_line)
	end

	-- jj format: change_id author email timestamp [bookmark] commit_id [status]
	local info_parts = {}

	-- Add change ID (use first 8 chars like jj does)
	if commit.change_id then
		table.insert(info_parts, commit.change_id:sub(1, 8))
	elseif commit.commit_id then
		table.insert(info_parts, commit.commit_id:sub(1, 8))
	end

	-- Add author info
	if commit.author_name then
		table.insert(info_parts, commit.author_name)
	end
	if commit.author_email then
		table.insert(info_parts, commit.author_email)
	end
	if commit.timestamp then
		table.insert(info_parts, commit.timestamp)
	end

	-- Add bookmarks if present
	if commit.bookmarks and #commit.bookmarks > 0 then
		table.insert(info_parts, table.concat(commit.bookmarks, " "))
	end

	-- Add commit ID (full for testing, real jj output will already be formatted)
	if commit.commit_id then
		table.insert(info_parts, commit.commit_id)
	end

	-- Add conflict status if present
	if commit.conflict_status and commit.conflict_status == "conflict" then
		table.insert(info_parts, "conflict")
	end

	-- Combine graph with info
	table.insert(parts, table.concat(info_parts, " "))

	-- Build the first line
	local first_line = table.concat(parts, "")

	-- Handle multi-line output for description
	local lines = { first_line }

	-- Add description line(s) with proper indentation
	if commit.description and commit.description ~= "" and commit.description ~= "(no description set)" then
		-- Get the graph width for proper indentation
		local graph_width = commit.graph_line and #commit.graph_line or 0
		local indent = string.rep(" ", graph_width)

		-- Add empty status indicator if needed
		local desc_parts = {}
		if commit.empty then
			table.insert(desc_parts, "(empty)")
		end
		table.insert(desc_parts, commit.description)

		table.insert(lines, indent .. table.concat(desc_parts, " "))
	elseif commit.empty then
		-- Just show (empty) if no description
		local graph_width = commit.graph_line and #commit.graph_line or 0
		local indent = string.rep(" ", graph_width)
		table.insert(lines, indent .. "(empty) (no description set)")
	end

	return table.concat(lines, "\n")
end

-- Combine graph characters with commit info
function M.combine_graph_and_info(graph_part, commit_info)
	if not graph_part or graph_part == "" then
		return commit_info or ""
	end

	if not commit_info or commit_info == "" then
		return graph_part
	end

	return graph_part .. commit_info
end

-- Preserve ANSI color codes in display lines
function M.preserve_ansi_colors(line)
	if not line then
		return ""
	end

	-- Return the line as-is to preserve ANSI codes
	-- The ANSI processing will happen separately during buffer rendering
	return line
end

-- Generate buffer content from raw jj log output
function M.generate_buffer_content(raw_colored_output)
	local processed = M.process_log_output(raw_colored_output)
	return processed.lines
end

-- Generate buffer content from list of commits (fallback for testing)
function M.generate_buffer_content_from_commits(commits)
	if not commits or #commits == 0 then
		return {}
	end

	local buffer_lines = {}

	for _, commit in ipairs(commits) do
		local display_line = M.generate_display_line(commit)

		-- Split multi-line display content
		for line in display_line:gmatch("[^\n]*") do
			if line ~= "" then
				table.insert(buffer_lines, line)
			end
		end
	end

	return buffer_lines
end

-- Render raw jj log output to a buffer with proper state management
function M.render_to_buffer(buffer_id, raw_colored_output)
	if not buffer_id then
		return
	end

	-- Process the raw colored output
	local processed = M.process_log_output(raw_colored_output)

	-- Make buffer modifiable temporarily
	vim.api.nvim_buf_set_option(buffer_id, "modifiable", true)

	-- Clear existing content and set new content
	vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, processed.lines)

	-- Apply highlights using ANSI module
	local result = ansi.apply_highlights_to_buffer(buffer_id, processed.highlights)

	-- Make buffer non-modifiable
	vim.api.nvim_buf_set_option(buffer_id, "modifiable", false)

	return result
end

-- Render commits to a buffer (fallback for testing)
function M.render_commits_to_buffer(buffer_id, commits)
	if not buffer_id or not commits then
		return
	end

	-- Generate buffer content
	local buffer_lines = M.generate_buffer_content_from_commits(commits)

	-- Make buffer modifiable temporarily
	vim.api.nvim_buf_set_option(buffer_id, "modifiable", true)

	-- Clear existing content and set new content
	vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, buffer_lines)

	-- Apply ANSI colors as highlights (if any ANSI codes in generated content)
	M.apply_ansi_highlights(buffer_id, buffer_lines)

	-- Make buffer non-modifiable
	vim.api.nvim_buf_set_option(buffer_id, "modifiable", false)
end

-- Apply ANSI colors as Neovim highlights
function M.apply_ansi_highlights(buffer_id, content_lines)
	if not buffer_id or not content_lines then
		return
	end

	-- Get or create namespace for JJ highlights
	local ns_id = vim.api.nvim_create_namespace("jj_log_highlights")

	-- Clear existing highlights
	vim.api.nvim_buf_clear_namespace(buffer_id, ns_id, 0, -1)

	-- Process each line for ANSI color codes
	for line_idx, line in ipairs(content_lines) do
		if line and line:find("\27%[") then
			-- Use the ANSI processor to apply highlights
			ansi.apply_ansi_highlights_to_line(buffer_id, ns_id, line_idx - 1, line)
		end
	end
end

-- Clear buffer content
function M.clear_buffer_content(buffer_id)
	if not buffer_id then
		return
	end

	-- Make buffer modifiable temporarily
	vim.api.nvim_buf_set_option(buffer_id, "modifiable", true)

	-- Clear all lines
	vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, {})

	-- Clear highlights
	local ns_id = vim.api.nvim_create_namespace("jj_log_highlights")
	vim.api.nvim_buf_clear_namespace(buffer_id, ns_id, 0, -1)

	-- Make buffer non-modifiable
	vim.api.nvim_buf_set_option(buffer_id, "modifiable", false)
end

-- Set buffer as non-modifiable
function M.set_buffer_non_modifiable(buffer_id)
	if not buffer_id then
		return
	end

	vim.api.nvim_buf_set_option(buffer_id, "modifiable", false)
end

return M
