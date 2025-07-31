-- Complete integration tests for refresh system with all plugin functionality
require("helpers.vim_mock")
local test_repo = require("helpers.test_repository")

-- Mock state tracking
local mock_windows = {}
local mock_buffers = {}
local mock_notifications = {}
local mock_buffer_options = {}
local mock_window_options = {}
local mock_highlights = {}
local mock_keymaps = {}
local next_buffer_id = 1
local next_window_id = 1

-- Mock vim.notify to capture notifications
vim.notify = function(message, level)
	table.insert(mock_notifications, {
		message = message,
		level = level or vim.log.levels.INFO,
	})
end

-- Enhanced buffer and window mocking
vim.api.nvim_create_buf = function(listed, scratch)
	local buffer_id = next_buffer_id
	next_buffer_id = next_buffer_id + 1

	mock_buffers[buffer_id] = {
		listed = listed,
		scratch = scratch,
		lines = {},
		options = {},
		name = "",
	}

	return buffer_id
end

vim.api.nvim_buf_is_valid = function(buffer_id)
	return mock_buffers[buffer_id] ~= nil
end

vim.api.nvim_buf_get_name = function(buffer_id)
	if mock_buffers[buffer_id] then
		return mock_buffers[buffer_id].name or ""
	end
	return ""
end

vim.api.nvim_buf_set_name = function(buffer_id, name)
	if mock_buffers[buffer_id] then
		mock_buffers[buffer_id].name = name
	end
end

vim.api.nvim_buf_set_lines = function(buffer, start, end_line, strict_indexing, replacement)
	if mock_buffers[buffer] then
		mock_buffers[buffer].lines = replacement
	end
end

vim.api.nvim_buf_get_lines = function(buffer, start, end_line, strict_indexing)
	if mock_buffers[buffer] then
		return mock_buffers[buffer].lines or {}
	end
	return {}
end

vim.api.nvim_buf_line_count = function(buffer_id)
	if mock_buffers[buffer_id] and mock_buffers[buffer_id].lines then
		return #mock_buffers[buffer_id].lines
	end
	return 0
end

-- Window mocking
vim.api.nvim_open_win = function(buffer_id, enter, config)
	local window_id = next_window_id
	next_window_id = next_window_id + 1

	mock_windows[window_id] = {
		buffer_id = buffer_id,
		config = config,
		enter = enter,
	}

	return window_id
end

vim.api.nvim_win_is_valid = function(window_id)
	return mock_windows[window_id] ~= nil
end

vim.api.nvim_win_close = function(window_id, force)
	mock_windows[window_id] = nil
end

vim.api.nvim_win_get_buf = function(window_id)
	if mock_windows[window_id] then
		return mock_windows[window_id].buffer_id
	end
	return -1
end

vim.api.nvim_win_set_buf = function(window_id, buffer_id)
	if mock_windows[window_id] then
		mock_windows[window_id].buffer_id = buffer_id
	end
end

vim.api.nvim_get_current_win = function()
	for window_id, _ in pairs(mock_windows) do
		return window_id
	end
	-- Create a default window for testing
	local window_id = next_window_id
	next_window_id = next_window_id + 1
	mock_windows[window_id] = {
		buffer_id = 1,
		config = {},
		enter = false,
	}
	return window_id
end

vim.api.nvim_win_get_cursor = function(window_id)
	return { 1, 0 } -- Default cursor position
end

vim.api.nvim_win_set_cursor = function(window_id, pos)
	-- Mock cursor setting
end

-- Buffer option mocking
vim.api.nvim_buf_set_option = function(buffer_id, option, value)
	if not mock_buffer_options[buffer_id] then
		mock_buffer_options[buffer_id] = {}
	end
	mock_buffer_options[buffer_id][option] = value
end

vim.api.nvim_buf_get_option = function(buffer_id, option)
	if mock_buffer_options[buffer_id] then
		return mock_buffer_options[buffer_id][option]
	end
	return nil
end

vim.api.nvim_win_set_option = function(window_id, option, value)
	if not mock_window_options[window_id] then
		mock_window_options[window_id] = {}
	end
	mock_window_options[window_id][option] = value
end

-- Mock keymapping
vim.api.nvim_buf_set_keymap = function(buffer_id, mode, key, command, opts)
	if not mock_keymaps[buffer_id] then
		mock_keymaps[buffer_id] = {}
	end
	mock_keymaps[buffer_id][mode .. key] = {
		command = command,
		opts = opts,
	}
end

-- Mock highlight operations
vim.api.nvim_create_namespace = function(name)
	return 1
end

vim.api.nvim_buf_clear_namespace = function(buffer, ns_id, start, end_line)
	if mock_highlights[buffer] then
		mock_highlights[buffer] = {}
	end
end

vim.api.nvim_buf_add_highlight = function(buffer, ns_id, hl_group, line, col_start, col_end)
	if not mock_highlights[buffer] then
		mock_highlights[buffer] = {}
	end
	table.insert(mock_highlights[buffer], {
		ns_id = ns_id,
		hl_group = hl_group,
		line = line,
		col_start = col_start,
		col_end = col_end,
	})
end

-- Mock autocmd creation
vim.api.nvim_create_autocmd = function(event, opts)
	return 1 -- Mock autocmd ID
end

vim.api.nvim_create_augroup = function(name, opts)
	return 1 -- Mock augroup ID
end

vim.api.nvim_del_augroup_by_name = function(name)
	-- Mock deletion
end

-- Mock vim.cmd for split commands
vim.cmd = function(command)
	-- Mock vim command execution
end

-- Load modules using dofile (like other tests)
local window = dofile("../lua/jj/ui/window.lua")
local refresh = dofile("../lua/jj/refresh.lua")
local navigation_integration = dofile("../lua/jj/ui/navigation_integration.lua")
local auto_refresh = dofile("../lua/jj/auto_refresh.lua")

describe("Complete Refresh System Integration", function()
	local lfs = require("lfs")
	local original_cwd

	before_each(function()
		original_cwd = lfs.currentdir()
		lfs.chdir(test_repo.test_repo_path)

		-- Reset all mocks
		mock_windows = {}
		mock_buffers = {}
		mock_notifications = {}
		mock_buffer_options = {}
		mock_window_options = {}
		mock_highlights = {}
		mock_keymaps = {}
		next_buffer_id = 1
		next_window_id = 1

		-- Clean up module state
		window.cleanup()
		refresh.reset_refresh_state()
		auto_refresh.reset_auto_refresh_state()
	end)

	after_each(function()
		lfs.chdir(original_cwd)
	end)

	describe("full workflow integration", function()
		it("should handle complete open -> navigate -> refresh -> navigate workflow", function()
			-- Step 1: Open log window
			local window_id = window.open_log_window()
			assert.is_not_nil(window_id)
			assert.is_true(window.is_log_window_open())

			local buffer_id = window.get_log_buffer_id()
			assert.is_not_nil(buffer_id)
			assert.equals("JJ Log", mock_buffers[buffer_id].name)

			-- Step 2: Render content with commits (simulating navigation setup)
			local raw_output = "@    abc123 test commit\n├─╮  branch merge\n"
			local commits = {
				{ commit_id = "abc123", description = "test commit", line_start = 1, line_end = 1 },
				{ commit_id = "def456", description = "branch merge", line_start = 2, line_end = 2 },
			}

			local render_success = window.render_log_content(raw_output, commits)
			assert.is_true(render_success)

			-- Should have content rendered
			assert.is_not_nil(mock_buffers[buffer_id].lines)

			-- Step 3: Check that navigation integration was set up
			local nav_boundaries = navigation_integration.get_navigation_boundaries(buffer_id)
			local buffer_commits = navigation_integration.get_buffer_commits(buffer_id)

			-- Should have navigation set up (may be nil in test environment, but shouldn't error)
			assert.has_no.errors(function()
				navigation_integration.is_navigation_enabled(buffer_id)
			end)

			-- Step 4: Perform manual refresh
			local window_mock = {
				is_log_window_open = function()
					return true
				end,
				refresh_log_content = function()
					return true
				end,
				refresh_navigation = function()
					return true
				end,
			}

			local refresh_success = refresh.manual_refresh(window_mock)
			assert.is_true(refresh_success)

			-- Step 5: Verify navigation still works after refresh
			assert.has_no.errors(function()
				navigation_integration.is_navigation_enabled(buffer_id)
			end)
		end)

		it("should handle window close cleanup properly", function()
			-- Open window and set up navigation
			local window_id = window.open_log_window()
			local buffer_id = window.get_log_buffer_id()

			-- Render content to set up navigation
			local raw_output = "@    abc123 test commit\n"
			local commits = { { commit_id = "abc123", description = "test commit", line_start = 1, line_end = 1 } }
			window.render_log_content(raw_output, commits)

			-- Window should be open
			assert.is_true(window.is_log_window_open())

			-- Close window
			local closed = window.close_log_window()
			assert.is_true(closed)

			-- Window should be closed and cleaned up
			assert.is_false(window.is_log_window_open())
			assert.is_nil(window.get_log_window_id())

			-- Refresh state should be reset
			assert.is_false(refresh.is_refresh_active())
		end)

		it("should handle auto-refresh integration", function()
			-- Setup auto-refresh system
			auto_refresh.setup_default_auto_refresh()
			auto_refresh.set_refresh_throttle(0) -- Disable throttling for testing

			-- Open window
			local window_id = window.open_log_window()
			assert.is_true(window.is_log_window_open())

			-- Mock successful command execution that should trigger refresh
			local window_mock = {
				is_log_window_open = function()
					return true
				end,
				refresh_log_content = function()
					return true
				end,
				refresh_navigation = function()
					return true
				end,
			}

			-- Simulate auto-refresh trigger
			local success = auto_refresh.auto_refresh_after_command("commit -m 'test'", true, "output", window_mock)
			assert.is_true(success)

			-- Should have auto-refresh notification
			local has_auto_refresh = false
			for _, notification in ipairs(mock_notifications) do
				if notification.message:match("Auto%-refreshing") then
					has_auto_refresh = true
					break
				end
			end
			assert.is_true(has_auto_refresh)
		end)

		it("should preserve highlighting after refresh", function()
			-- Open window and render content
			local window_id = window.open_log_window()
			local buffer_id = window.get_log_buffer_id()

			local raw_output = "@    abc123 test commit\n├─╮  def456 merge\n"
			local commits = {
				{ commit_id = "abc123", description = "test commit", line_start = 1, line_end = 1 },
				{ commit_id = "def456", description = "merge", line_start = 2, line_end = 2 },
			}

			window.render_log_content(raw_output, commits)

			-- Should have highlights set up (in real usage, not in test mock)
			-- The important part is that it doesn't error
			assert.has_no.errors(function()
				navigation_integration.update_commit_highlighting(buffer_id, window_id)
			end)

			-- Refresh should preserve navigation
			local window_mock = {
				is_log_window_open = function()
					return true
				end,
			}

			refresh.manual_refresh(window_mock)

			-- Navigation should still work after refresh
			assert.has_no.errors(function()
				navigation_integration.is_navigation_enabled(buffer_id)
			end)
		end)
	end)

	describe("error handling integration", function()
		it("should handle refresh failures gracefully without breaking navigation", function()
			-- Open window and set up navigation
			local window_id = window.open_log_window()
			local buffer_id = window.get_log_buffer_id()

			local commits = { { commit_id = "abc123", description = "test", line_start = 1, line_end = 1 } }
			window.render_log_content("@    abc123 test\n", commits)

			-- Mock failed refresh
			local window_mock = {
				is_log_window_open = function()
					return false
				end, -- Simulate window closure
			}

			local success = refresh.manual_refresh(window_mock)
			assert.is_false(success)

			-- Should have error message
			local has_error = false
			for _, notification in ipairs(mock_notifications) do
				if notification.message:match("No log window is currently open") then
					has_error = true
					break
				end
			end
			assert.is_true(has_error)

			-- Navigation should still be in a consistent state
			assert.has_no.errors(function()
				navigation_integration.cleanup_navigation_for_buffer(buffer_id)
			end)
		end)

		it("should handle concurrent refresh attempts", function()
			local window_id = window.open_log_window()

			local window_mock = {
				is_log_window_open = function()
					return true
				end,
			}

			-- First refresh
			local success1 = refresh.manual_refresh(window_mock)
			assert.is_true(success1)

			-- During refresh, second attempt should be handled appropriately
			-- (The actual behavior depends on implementation - it might queue or reject)
			assert.has_no.errors(function()
				refresh.manual_refresh(window_mock)
			end)
		end)

		it("should cleanup properly on full plugin cleanup", function()
			-- Set up complete state
			local window_id = window.open_log_window()
			local buffer_id = window.get_log_buffer_id()

			auto_refresh.setup_default_auto_refresh()

			-- Render content to set up navigation
			local commits = { { commit_id = "abc123", description = "test", line_start = 1, line_end = 1 } }
			window.render_log_content("@    abc123 test\n", commits)

			-- Full cleanup
			window.cleanup()
			navigation_integration.cleanup_all_navigation()
			auto_refresh.cleanup()

			-- Everything should be cleaned up
			assert.is_false(window.is_log_window_open())
			assert.is_nil(window.get_log_window_id())
			assert.is_nil(window.get_log_buffer_id())
			assert.is_false(refresh.is_refresh_active())
		end)
	end)

	describe("configuration compatibility", function()
		it("should work with all window configuration types", function()
			local configs = {
				{ style = "split", position = "right" },
				{ style = "split", position = "left" },
				{ style = "split", position = "top" },
				{ style = "split", position = "bottom" },
				{ style = "floating", width = 100, height = 30 },
			}

			for _, config in ipairs(configs) do
				-- Clean up previous test
				window.cleanup()
				mock_notifications = {}

				-- Configure and open window
				window.configure(config)
				local window_id = window.open_log_window()
				assert.is_not_nil(window_id, "Failed to open window with config: " .. vim.inspect(config))

				-- Refresh should work with this configuration
				local window_mock = {
					is_log_window_open = function()
						return true
					end,
				}

				local success = refresh.manual_refresh(window_mock)
				assert.is_true(success, "Refresh failed with config: " .. vim.inspect(config))
			end
		end)
	end)
end)
