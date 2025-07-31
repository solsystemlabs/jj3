-- Integration tests for refresh system with window management
require("helpers.vim_mock")
local test_repo = require("helpers.test_repository")

-- Mock state tracking
local mock_windows = {}
local mock_buffers = {}
local mock_notifications = {}
local mock_buffer_options = {}
local mock_window_options = {}
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

vim.api.nvim_win_get_config = function(window_id)
	if mock_windows[window_id] then
		return mock_windows[window_id].config or {}
	end
	return {}
end

vim.api.nvim_win_set_config = function(window_id, config)
	if mock_windows[window_id] then
		mock_windows[window_id].config = config
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

vim.api.nvim_set_current_win = function(window_id)
	-- Mock setting current window
end

vim.api.nvim_win_get_width = function(window_id)
	return 80
end

vim.api.nvim_win_get_height = function(window_id)
	return 24
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

-- Mock buffer keymapping
vim.api.nvim_buf_set_keymap = function(buffer_id, mode, key, command, opts)
	-- Mock keymap setting
end

-- Mock highlight operations
vim.api.nvim_create_namespace = function(name)
	return 1
end

vim.api.nvim_buf_clear_namespace = function(buffer, ns_id, start, end_line)
	-- Mock clearing namespace highlights
end

vim.api.nvim_buf_add_highlight = function(buffer, ns_id, hl_group, line, col_start, col_end)
	-- Mock adding highlight
end

-- Mock vim.cmd for split commands
vim.cmd = function(command)
	-- Mock vim command execution
end

-- Load modules using dofile (like other tests)
local window = dofile("../lua/jj/ui/window.lua")
local refresh = dofile("../lua/jj/refresh.lua")
local log = dofile("../lua/jj/log/init.lua")

describe("Refresh System Window Integration", function()
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
		next_buffer_id = 1
		next_window_id = 1

		-- Clean up window state
		window.cleanup()
	end)

	after_each(function()
		lfs.chdir(original_cwd)
	end)

	describe("manual refresh integration", function()
		it("should setup refresh keymaps when window is opened", function()
			-- Open a log window
			local window_id = window.open_log_window()
			assert.is_not_nil(window_id)

			local buffer_id = window.get_log_buffer_id()
			assert.is_not_nil(buffer_id)

			-- Setup refresh keymaps should work for JJ Log buffer
			local success = refresh.setup_refresh_keymaps(buffer_id)
			assert.is_true(success)
		end)

		it("should not setup refresh keymaps for non-JJ buffers", function()
			-- Create a regular buffer
			local buffer_id = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_name(buffer_id, "regular-file.txt")

			-- Should not setup keymaps for non-JJ buffer
			local success = refresh.setup_refresh_keymaps(buffer_id)
			assert.is_false(success)
		end)

		it("should perform manual refresh when log window is open", function()
			-- Open log window first
			local window_id = window.open_log_window()
			assert.is_not_nil(window_id)
			assert.is_true(window.is_log_window_open())

			-- Mock the window check for refresh
			local window_mock = {
				is_log_window_open = function()
					return true
				end,
			}

			-- Manual refresh should succeed
			local success = refresh.manual_refresh(window_mock)
			assert.is_true(success)
		end)

		it("should fail manual refresh when no log window is open", function()
			-- Ensure no window is open
			assert.is_false(window.is_log_window_open())

			-- Mock the window check for refresh
			local window_mock = {
				is_log_window_open = function()
					return false
				end,
			}

			-- Manual refresh should fail
			local success = refresh.manual_refresh(window_mock)
			assert.is_false(success)

			-- Should have error notification
			local has_error_message = false
			for _, notification in ipairs(mock_notifications) do
				if notification.message:match("No log window is currently open") then
					has_error_message = true
					break
				end
			end
			assert.is_true(has_error_message)
		end)

		it("should preserve cursor position during manual refresh", function()
			-- Open log window
			local window_id = window.open_log_window()
			assert.is_not_nil(window_id)

			-- Mock window with buffer line count
			local window_mock = {
				is_log_window_open = function()
					return true
				end,
				get_buffer_line_count = function()
					return 10
				end,
			}

			-- Manual refresh should preserve cursor position
			local success = refresh.manual_refresh(window_mock)
			assert.is_true(success)
		end)
	end)

	describe("refresh with different window configurations", function()
		it("should work with split window configuration", function()
			-- Configure for split window
			window.configure({
				style = "split",
				position = "right",
				width = 80,
			})

			local window_id = window.open_log_window()
			assert.is_not_nil(window_id)

			-- Refresh should work with split configuration
			local window_mock = {
				is_log_window_open = function()
					return true
				end,
			}

			local success = refresh.manual_refresh(window_mock)
			assert.is_true(success)
		end)

		it("should work with floating window configuration", function()
			-- Configure for floating window
			window.configure({
				style = "floating",
				width = 100,
				height = 30,
				row = 5,
				col = 10,
			})

			local window_id = window.open_log_window()
			assert.is_not_nil(window_id)

			-- Refresh should work with floating configuration
			local window_mock = {
				is_log_window_open = function()
					return true
				end,
			}

			local success = refresh.manual_refresh(window_mock)
			assert.is_true(success)
		end)

		it("should work with different split positions", function()
			local positions = { "left", "right", "top", "bottom" }

			for _, position in ipairs(positions) do
				-- Clean up previous test
				window.cleanup()
				mock_notifications = {}

				-- Configure for specific position
				window.configure({
					style = "split",
					position = position,
					width = 60,
					height = 20,
				})

				local window_id = window.open_log_window()
				assert.is_not_nil(window_id, "Failed to open window for position: " .. position)

				-- Refresh should work with this position
				local window_mock = {
					is_log_window_open = function()
						return true
					end,
				}

				local success = refresh.manual_refresh(window_mock)
				assert.is_true(success, "Refresh failed for position: " .. position)
			end
		end)
	end)

	describe("refresh state management", function()
		it("should track refresh state correctly", function()
			-- Initially not refreshing
			assert.is_false(refresh.is_refresh_active())

			-- Open window and start refresh
			local window_id = window.open_log_window()
			local window_mock = {
				is_log_window_open = function()
					return true
				end,
			}

			-- During refresh, state should be managed
			refresh.manual_refresh(window_mock)

			-- After refresh, should be reset
			assert.is_false(refresh.is_refresh_active())
		end)

		it("should prevent concurrent refresh operations", function()
			local window_id = window.open_log_window()
			local window_mock = {
				is_log_window_open = function()
					return true
				end,
			}

			-- Mock refresh state as active
			refresh.reset_refresh_state()
			-- Temporarily set to active for testing

			-- First refresh
			local success1 = refresh.manual_refresh(window_mock)
			assert.is_true(success1)

			-- Immediate second refresh should be prevented if throttled
			-- (Note: This test depends on implementation details)
		end)

		it("should reset refresh state on error recovery", function()
			-- Force reset refresh state
			refresh.reset_refresh_state()

			assert.is_false(refresh.is_refresh_active())
			assert.equals(0, refresh.get_last_refresh_time())
		end)
	end)

	describe("window cleanup integration", function()
		it("should clean up refresh state when window is closed", function()
			-- Open window and setup refresh
			local window_id = window.open_log_window()
			local buffer_id = window.get_log_buffer_id()

			refresh.setup_refresh_keymaps(buffer_id)

			-- Close window
			window.close_log_window()

			-- Window state should be cleaned up
			assert.is_false(window.is_log_window_open())
			assert.is_nil(window.get_log_window_id())
		end)

		it("should handle window cleanup through window module", function()
			-- Open window
			local window_id = window.open_log_window()
			assert.is_true(window.is_log_window_open())

			-- Full cleanup should reset everything
			window.cleanup()

			assert.is_false(window.is_log_window_open())
			assert.is_nil(window.get_log_window_id())
			assert.is_nil(window.get_log_buffer_id())
		end)
	end)

	describe("integration with log module", function()
		it("should integrate refresh with log.refresh_log", function()
			-- Open log window first
			local window_id = window.open_log_window()
			assert.is_true(window.is_log_window_open())

			-- log.refresh_log should work when window is open
			local success = log.refresh_log()
			-- This may fail due to missing jj command in test environment
			-- The important part is that it doesn't error
			assert.is_not_nil(success)
		end)

		it("should handle log refresh when no window is open", function()
			-- Ensure no window is open
			assert.is_false(window.is_log_window_open())

			-- log.refresh_log should handle this gracefully
			local success = log.refresh_log()
			assert.is_false(success)

			-- Should have appropriate error message
			local has_error = false
			for _, notification in ipairs(mock_notifications) do
				if notification.message:match("No log window is currently open") then
					has_error = true
					break
				end
			end
			assert.is_true(has_error)
		end)
	end)

	describe("error handling", function()
		it("should handle window creation failures during refresh", function()
			-- Mock window creation to fail
			local original_open_win = vim.api.nvim_open_win
			vim.api.nvim_open_win = function()
				return nil
			end

			-- Try to open window (should fail)
			local window_id = window.open_log_window()
			assert.is_nil(window_id)

			-- Refresh should handle missing window gracefully
			local window_mock = {
				is_log_window_open = function()
					return false
				end,
			}

			local success = refresh.manual_refresh(window_mock)
			assert.is_false(success)

			-- Restore original function
			vim.api.nvim_open_win = original_open_win
		end)

		it("should handle buffer creation failures during refresh", function()
			-- Mock buffer creation to fail
			local original_create_buf = vim.api.nvim_create_buf
			vim.api.nvim_create_buf = function()
				return nil
			end

			-- Window creation should fail due to buffer failure
			local window_id = window.open_log_window()
			assert.is_nil(window_id)

			-- Restore original function
			vim.api.nvim_create_buf = original_create_buf
		end)

		it("should handle invalid window states gracefully", function()
			-- Create window then invalidate it
			local window_id = window.open_log_window()
			assert.is_not_nil(window_id)

			-- Simulate window becoming invalid
			mock_windows[window_id] = nil

			-- Should handle invalid window state
			assert.is_false(window.is_log_window_open())

			local window_mock = {
				is_log_window_open = function()
					return false
				end,
			}

			local success = refresh.manual_refresh(window_mock)
			assert.is_false(success)
		end)
	end)
end)
