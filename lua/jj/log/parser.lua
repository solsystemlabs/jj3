-- JJ log parsing functionality for jj.nvim
local M = {}

-- Import executor module
local executor = require("jj.log.executor")

-- Parse commit IDs from minimal template output
function M.parse_commit_ids(output)
	local commit_ids = {}

	if not output or output == "" then
		return commit_ids
	end

	-- Split by newlines and extract commit IDs from each line
	for line in output:gmatch("[^\n]+") do
		-- Skip empty lines and graph-only lines (lines with only graph characters and spaces)  
		if line ~= "" and not line:match("^[│├─╮╯~%s]*$") then
			-- Look for hex commit IDs in the line (40 char hex strings)
			for commit_id in line:gmatch("(%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x+)") do
				if #commit_id >= 8 then -- Valid commit ID length
					table.insert(commit_ids, commit_id)
					break -- Only take first commit ID per line
				end
			end
		end
	end

	return commit_ids
end

-- Create commit object from parsed comprehensive template data
function M.create_commit_object(commit_data)
	if not commit_data or #commit_data < 13 then
		return nil
	end

	-- Parse bookmarks (comma-separated)
	local bookmarks = {}
	if commit_data[6] and commit_data[6] ~= "" then
		for bookmark in commit_data[6]:gmatch("[^,]+") do
			table.insert(bookmarks, vim.trim(bookmark))
		end
	end

	-- Parse tags (comma-separated)
	local tags = {}
	if commit_data[7] and commit_data[7] ~= "" then
		for tag in commit_data[7]:gmatch("[^,]+") do
			table.insert(tags, vim.trim(tag))
		end
	end

	return {
		commit_id = commit_data[1] or "",
		change_id = commit_data[2] or "",
		author_name = commit_data[3] or "",
		author_email = commit_data[4] or "",
		timestamp = commit_data[5] or "",
		bookmarks = bookmarks,
		tags = tags,
		working_copies = commit_data[8] or "",
		conflict_status = commit_data[9] or "normal",
		empty_status = commit_data[10] or "normal",
		hidden_status = commit_data[11] or "normal",
		description = commit_data[12] or "",
		git_head = commit_data[13] or "",
	}
end

-- Parse comprehensive template output into commit objects
function M.parse_comprehensive_log(output)
	local commits = {}

	if not output or output == "" then
		return commits
	end

	-- Split by newlines, each line represents one commit
	for line in output:gmatch("[^\n]+") do
		if line ~= "" then
			-- Split by null bytes to get fields
			local fields = vim.split(line, "\0", { plain = true })

			-- Create commit object if we have enough fields
			local commit = M.create_commit_object(fields)
			if commit then
				table.insert(commits, commit)
			end
		end
	end

	return commits
end

-- Parse graph structure from default jj log output
function M.parse_graph_lines(output)
	local graph_lines = {}

	if not output or output == "" then
		return graph_lines
	end

	for line in output:gmatch("[^\n]+") do
		if line ~= "" then
			-- Split line into graph part and commit info part
			-- Graph characters typically include: │├─╮╯○×@◆~
			local graph_part = ""
			local commit_info_part = ""

			-- Find where graph ends and commit info begins
			-- Look for the first alphanumeric character that's not a graph symbol
			local graph_end = 1
			for i = 1, #line do
				local char = line:sub(i, i)
				if char:match("[%w]") and not (char == "○" or char == "×" or char == "@" or char == "◆" or char == "~") then
					graph_end = i
					break
				end
			end

			if graph_end > 1 then
				graph_part = line:sub(1, graph_end - 1)
				commit_info_part = line:sub(graph_end)
			else
				-- If no clear split found, put everything in commit_info
				graph_part = ""
				commit_info_part = line
			end

			table.insert(graph_lines, {
				graph = graph_part,
				commit_info = vim.trim(commit_info_part),
				raw_line = line,
			})
		end
	end

	return graph_lines
end

-- Extract commit ID from a graph line (heuristic approach)
function M.extract_commit_id_from_graph_line(graph_line)
	if not graph_line or not graph_line.commit_info then
		return nil
	end

	local commit_info = graph_line.commit_info

	-- Look for hex patterns that could be commit IDs
	-- Commit IDs are typically 8+ character hex strings
	for hex_string in commit_info:gmatch("%x%x%x%x%x%x%x%x+") do
		-- Basic validation - should be reasonable length
		if #hex_string >= 8 and #hex_string <= 64 then
			return hex_string
		end
	end

	return nil
end

-- Perform complete dual-pass parsing
function M.parse_jj_log_dual_pass()
	local result = {
		success = false,
		error = nil,
		commits = {},
		graph_lines = {},
		commit_map = {},
	}

	-- First pass: Get commit IDs using minimal template
	local minimal_result = executor.execute_minimal_log()
	if not minimal_result.success then
		result.error = "Failed to execute minimal log: " .. (minimal_result.error or "unknown error")
		return result
	end

	local commit_ids = M.parse_commit_ids(minimal_result.output)
	
	if #commit_ids == 0 then
		result.error = "No commit IDs found in minimal template output"
		return result
	end

	-- Second pass: Create simple commit objects from commit IDs
	local commits = {}
	for _, commit_id in ipairs(commit_ids) do
		table.insert(commits, {
			commit_id = commit_id,
			change_id = "",
			author_name = "unknown",
			author_email = "unknown",
			timestamp = "unknown",
			bookmarks = {},
			tags = {},
			description = "Commit " .. commit_id:sub(1, 8),
			conflict_status = "normal"
		})
	end

	if #commits == 0 then
		result.error = "No commit IDs found in minimal template output"
		return result
	end

	-- Third pass: Get graph structure
	local graph_result = executor.execute_jj_command("log --color=always")
	if not graph_result.success then
		result.error = "Failed to execute graph log: " .. (graph_result.error or "unknown error")
		return result
	end

	local graph_lines = M.parse_graph_lines(graph_result.output)

	-- Create commit map for quick lookup
	local commit_map = {}
	for _, commit in ipairs(commits) do
		commit_map[commit.commit_id] = commit
	end

	-- Populate result
	result.success = true
	result.commits = commits
	result.graph_lines = graph_lines
	result.commit_map = commit_map

	return result
end

-- Correlate graph positions with commit data
function M.correlate_graph_with_commits(graph_lines, commit_map)
	local correlated = {}

	for i, graph_line in ipairs(graph_lines) do
		local commit_id = M.extract_commit_id_from_graph_line(graph_line)
		local commit_data = nil

		if commit_id and commit_map[commit_id] then
			commit_data = commit_map[commit_id]
		end

		table.insert(correlated, {
			line_number = i,
			graph = graph_line.graph,
			commit_info = graph_line.commit_info,
			raw_line = graph_line.raw_line,
			commit_id = commit_id,
			commit_data = commit_data,
		})
	end

	return correlated
end

-- Parse and validate template syntax (for comprehensive template)
function M.validate_comprehensive_template()
	local template = executor.get_comprehensive_template()

	-- Basic validation - check for required fields
	local required_fields = {
		"commit_id",
		"change_id",
		"author%.name",
		"author%.email",
		"timestamp",
		"bookmarks",
		"description",
	}

	for _, field in ipairs(required_fields) do
		if not template:find(field) then
			return false, "Missing required field: " .. field
		end
	end

	-- Check for proper null-byte separators
	local separator_count = 0
	for _ in template:gmatch("\\x00") do
		separator_count = separator_count + 1
	end

	if separator_count < 5 then
		return false, "Insufficient field separators"
	end

	return true, nil
end

-- Utility function to clean ANSI escape sequences for processing
function M.strip_ansi_codes(text)
	if not text then
		return ""
	end

	-- Remove ANSI escape sequences
	return text:gsub("\027%[[%d;]*m", "")
end

-- Utility function to extract basic commit info from any line
function M.extract_basic_commit_info(line)
	if not line then
		return nil
	end

	local clean_line = M.strip_ansi_codes(line)

	-- Try to extract basic patterns
	local info = {}

	-- Extract commit ID (8+ hex chars)
	info.commit_id = clean_line:match("(%x%x%x%x%x%x%x%x+)")

	-- Extract email
	info.email = clean_line:match("([%w%._%+-]+@[%w%._%+-]+)")

	-- Extract timestamp pattern
	info.timestamp = clean_line:match("(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d)")

	return info
end

return M
