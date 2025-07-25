-- Tests for :JJ command registration and basic functionality
require("helpers.vim_mock")

describe("JJ Command Registration", function()
	-- Add lua path for testing
	package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

	local jj_commands

	before_each(function()
		-- Clear modules from cache to ensure fresh load
		package.loaded["jj.commands"] = nil
		package.loaded["jj.config"] = nil

		-- Reset vim mocks
		vim.user_commands = {}
	end)

	describe("command registration", function()
		it("should register :JJ user command", function()
			jj_commands = require("jj.commands")
			
			-- Setup should register the command
			jj_commands.setup()
			
			-- Check that command was registered
			assert.is_not_nil(vim.user_commands["JJ"])
			assert.is_function(vim.user_commands["JJ"].fn)
		end)

		it("should register :JJ command with proper options", function()
			jj_commands = require("jj.commands")
			jj_commands.setup()
			
			local command_def = vim.user_commands["JJ"]
			assert.is_not_nil(command_def)
			assert.is_not_nil(command_def.opts)
			assert.is_not_nil(command_def.opts.desc)
			assert.matches("jj%.nvim", command_def.opts.desc)
		end)

		it("should provide command completion", function()
			jj_commands = require("jj.commands")
			jj_commands.setup()
			
			local command_def = vim.user_commands["JJ"]
			assert.is_not_nil(command_def.opts.complete)
			
			if type(command_def.opts.complete) == "function" then
				local completions = command_def.opts.complete()
				assert.is_table(completions)
				assert.is_true(#completions > 0)
			end
		end)
	end)

	describe("command functionality", function()
		before_each(function()
			-- Mock the log module to avoid requiring full integration
			package.loaded["jj.log.init"] = {
				toggle_log = function() return true end,
				show_log = function() return true end,
				close_log = function() return true end,
				refresh_log = function() return true end,
				focus_log = function() return true end,
				clear_log = function() return true end,
				get_status = function() 
					return {
						is_open = false,
						has_data = false,
						window_id = nil,
						buffer_id = nil
					}
				end,
				show_log_with_options = function(options) return true end,
				configure = function(config) return true end,
				setup = function(config) return true end
			}
		end)

		it("should handle :JJ with no arguments (default behavior)", function()
			jj_commands = require("jj.commands")
			jj_commands.setup()
			
			local command_fn = vim.user_commands["JJ"].fn
			
			-- Should not error when called with no args
			assert.has_no.errors(function()
				command_fn({args = ""})
			end)
		end)

		it("should handle :JJ show", function()
			jj_commands = require("jj.commands")
			jj_commands.setup()
			
			local command_fn = vim.user_commands["JJ"].fn
			
			assert.has_no.errors(function()
				command_fn({args = "show"})
			end)
		end)

		it("should handle :JJ close", function()
			jj_commands = require("jj.commands")
			jj_commands.setup()
			
			local command_fn = vim.user_commands["JJ"].fn
			
			assert.has_no.errors(function()
				command_fn({args = "close"})
			end)
		end)

		it("should handle :JJ refresh", function()
			jj_commands = require("jj.commands")
			jj_commands.setup()
			
			local command_fn = vim.user_commands["JJ"].fn
			
			assert.has_no.errors(function()
				command_fn({args = "refresh"})
			end)
		end)

		it("should handle :JJ toggle", function()
			jj_commands = require("jj.commands")
			jj_commands.setup()
			
			local command_fn = vim.user_commands["JJ"].fn
			
			assert.has_no.errors(function()
				command_fn({args = "toggle"})
			end)
		end)

		it("should handle :JJ status", function()
			-- Mock notifications to capture status output
			local notifications = {}
			vim.notify = function(message, level)
				table.insert(notifications, {message = message, level = level})
			end

			jj_commands = require("jj.commands")
			jj_commands.setup()
			
			local command_fn = vim.user_commands["JJ"].fn
			
			assert.has_no.errors(function()
				command_fn({args = "status"})
			end)
			
			-- Should have shown status notification
			assert.is_true(#notifications > 0)
			local status_msg = notifications[#notifications]
			assert.matches("status", status_msg.message)
		end)

		it("should show help for unknown commands", function()
			-- Mock notifications to capture help output
			local notifications = {}
			vim.notify = function(message, level)
				table.insert(notifications, {message = message, level = level})
			end

			jj_commands = require("jj.commands")
			jj_commands.setup()
			
			local command_fn = vim.user_commands["JJ"].fn
			
			assert.has_no.errors(function()
				command_fn({args = "unknown_command"})
			end)
			
			-- Should have shown help
			assert.is_true(#notifications > 0)
			local help_msg = notifications[#notifications]
			assert.matches("commands", help_msg.message)
		end)

		it("should handle jj options (--limit, etc.)", function()
			jj_commands = require("jj.commands")
			jj_commands.setup()
			
			local command_fn = vim.user_commands["JJ"].fn
			
			assert.has_no.errors(function()
				command_fn({args = "--limit 10"})
			end)
		end)
	end)

	describe("keybinding registration", function()
		it("should register global keybinding for log toggle", function()
			-- Mock keymap.set to track keybinding registration
			local registered_keymaps = {}
			vim.keymap.set = function(mode, lhs, rhs, opts)
				table.insert(registered_keymaps, {
					mode = mode,
					lhs = lhs,
					rhs = rhs,
					opts = opts
				})
			end

			jj_commands = require("jj.commands")
			jj_commands.setup()
			
			-- Should have registered the toggle keybinding
			local toggle_keymap = nil
			for _, keymap in ipairs(registered_keymaps) do
				if keymap.lhs == "<leader>jl" and keymap.mode == "n" then
					toggle_keymap = keymap
					break
				end
			end
			
			assert.is_not_nil(toggle_keymap)
			assert.is_function(toggle_keymap.rhs)
			assert.is_not_nil(toggle_keymap.opts.desc)
			assert.matches("Toggle.*log", toggle_keymap.opts.desc)
		end)

		it("should respect custom keybinding configuration", function()
			-- Mock custom config
			package.loaded["jj.config"] = {
				setup = function() end,
				get = function()
					return {
						keymaps = { toggle_log = "<leader>jj" },
						window = { position = "right", size = 50 }
					}
				end
			}

			-- Mock keymap.set to track keybinding registration
			local registered_keymaps = {}
			vim.keymap.set = function(mode, lhs, rhs, opts)
				table.insert(registered_keymaps, {
					mode = mode,
					lhs = lhs,
					rhs = rhs,
					opts = opts
				})
			end

			jj_commands = require("jj.commands")
			jj_commands.setup()
			
			-- Should have registered the custom keybinding
			local custom_keymap = nil
			for _, keymap in ipairs(registered_keymaps) do
				if keymap.lhs == "<leader>jj" and keymap.mode == "n" then
					custom_keymap = keymap
					break
				end
			end
			
			assert.is_not_nil(custom_keymap)
		end)

		it("should not register keybinding when disabled in config", function()
			-- Mock config with no keybinding
			package.loaded["jj.config"] = {
				setup = function() end,
				get = function()
					return {
						keymaps = { toggle_log = nil },
						window = { position = "right", size = 50 }
					}
				end
			}

			-- Mock keymap.set to track keybinding registration
			local registered_keymaps = {}
			vim.keymap.set = function(mode, lhs, rhs, opts)
				table.insert(registered_keymaps, {
					mode = mode,
					lhs = lhs,
					rhs = rhs,
					opts = opts
				})
			end

			jj_commands = require("jj.commands")
			jj_commands.setup()
			
			-- Should not have registered any global keybinding
			local global_keymap_count = 0
			for _, keymap in ipairs(registered_keymaps) do
				if keymap.lhs and keymap.lhs:match("leader") then
					global_keymap_count = global_keymap_count + 1
				end
			end
			
			assert.equals(0, global_keymap_count)
		end)
	end)

	describe("error handling", function()
		it("should handle command setup errors gracefully", function()
			-- Mock log module to throw error, but provide required functions
			package.loaded["jj.log.init"] = {
				toggle_log = function() error("Log error") end,
				configure = function(config) return true end,
				setup = function(config) return true end
			}

			jj_commands = require("jj.commands")
			
			-- Should not crash during setup
			assert.has_no.errors(function()
				jj_commands.setup()
			end)
		end)

		it("should handle missing config gracefully", function()
			-- Provide minimal config mock
			package.loaded["jj.config"] = {
				get = function()
					return {
						keymaps = { toggle_log = "<leader>jl" },
						window = { position = "right", size = 50 }
					}
				end
			}

			-- Mock log module
			package.loaded["jj.log.init"] = {
				configure = function(config) return true end,
				setup = function(config) return true end
			}

			jj_commands = require("jj.commands")
			
			-- Should not crash during setup
			assert.has_no.errors(function()
				jj_commands.setup()
			end)
		end)
	end)

	describe("module exports", function()
		it("should provide setup function", function()
			jj_commands = require("jj.commands")
			assert.is_function(jj_commands.setup)
		end)

		it("should provide cleanup function", function()
			jj_commands = require("jj.commands")
			assert.is_function(jj_commands.cleanup)
		end)

		it("should provide log function exports", function()
			jj_commands = require("jj.commands")
			assert.is_table(jj_commands.log)
			assert.is_function(jj_commands.log.show)
			assert.is_function(jj_commands.log.toggle)
			assert.is_function(jj_commands.log.close)
		end)
	end)
end)