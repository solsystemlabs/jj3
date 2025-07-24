-- Repository detection and validation utilities for jj.nvim
local M = {}

-- Check if current directory (or parent directories) contains a .jj directory
function M.is_jj_repository()
	local current_dir = vim.fn.getcwd()

	-- Walk up directory tree looking for .jj directory
	while current_dir ~= "/" do
		local jj_dir = current_dir .. "/.jj"
		if vim.fn.isdirectory(jj_dir) == 1 then
			return true
		end

		-- Move up one directory
		local parent = vim.fn.fnamemodify(current_dir, ":h")
		if parent == current_dir then
			break -- We've reached the root
		end
		current_dir = parent
	end

	return false
end

-- Get the root directory of the jj repository
function M.get_repository_root()
	local current_dir = vim.fn.getcwd()

	-- Walk up directory tree looking for .jj directory
	while current_dir ~= "/" do
		local jj_dir = current_dir .. "/.jj"
		if vim.fn.isdirectory(jj_dir) == 1 then
			return current_dir
		end

		-- Move up one directory
		local parent = vim.fn.fnamemodify(current_dir, ":h")
		if parent == current_dir then
			break -- We've reached the root
		end
		current_dir = parent
	end

	return nil
end

-- Check if jj command is available in PATH
function M.is_jj_available()
	local result = vim.fn.system("command -v jj")
	return vim.v.shell_error == 0 and result ~= ""
end

-- Get jj version information
function M.get_jj_version()
	if not M.is_jj_available() then
		return nil
	end

	local version_output = vim.fn.system("jj --version")
	if vim.v.shell_error == 0 then
		-- Extract version from output like "jj 0.15.1"
		local version = version_output:match("jj ([%d%.]+)")
		return version or version_output:gsub("\n", "")
	end

	return nil
end

-- Validate complete repository setup
function M.validate_repository()
	local validation = {
		valid = false,
		error = nil,
		repository_root = nil,
		jj_version = nil,
	}

	-- Check if jj command is available
	if not M.is_jj_available() then
		validation.error = "jj command not found in PATH"
		return validation
	end

	-- Get jj version
	validation.jj_version = M.get_jj_version()

	-- Check if we're in a jj repository
	if not M.is_jj_repository() then
		validation.error = "Not in a jj repository (no .jj directory found)"
		return validation
	end

	-- Get repository root
	validation.repository_root = M.get_repository_root()
	if not validation.repository_root then
		validation.error = "Could not determine jj repository root"
		return validation
	end

	-- All checks passed
	validation.valid = true
	return validation
end

return M
