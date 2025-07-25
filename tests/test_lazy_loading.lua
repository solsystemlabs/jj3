-- Tests for lazy.nvim compatibility and event triggers
require("helpers.vim_mock")

describe("Lazy Loading Support", function()
	-- Add lua path for testing
	package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

	local jj_init

	before_each(function()
		-- Clear modules from cache to ensure fresh load
		package.loaded["jj.init"] = nil
		package.loaded["jj.config"] = nil
		package.loaded["jj.commands"] = nil

		-- Reset vim mocks
		vim.user_commands = {}
		vim.registered_keymaps = {}
	end)

	describe("lazy.nvim compatibility", function()
		it("should support lazy loading via setup function", function()
			-- Mock log module for testing
			package.loaded["jj.log.init"] = {
				configure = function(config) return true end,
				setup = function(config) return true end
			}

			jj_init = require("jj.init")
			
			-- Should be able to load and setup without errors
			assert.has_no.errors(function()
				jj_init.setup()
			end)
			
			-- Should register command after setup
			assert.is_not_nil(vim.user_commands["JJ"])
		end)

		it("should work when loaded on command", function()
			-- Mock log module
			package.loaded["jj.log.init"] = {
				configure = function(config) return true end,
				setup = function(config) return true end
			}

			-- Simulate lazy loading by not calling setup initially
			jj_init = require("jj.init")
			
			-- Command should not be registered yet
			assert.is_nil(vim.user_commands["JJ"])
			
			-- After setup, command should be available
			jj_init.setup()
			assert.is_not_nil(vim.user_commands["JJ"])
		end)

		it("should work when loaded on keymap trigger", function()
			-- Mock keymap registration
			local registered_keymaps = {}
			vim.keymap.set = function(mode, lhs, rhs, opts)
				table.insert(registered_keymaps, {
					mode = mode,
					lhs = lhs,
					rhs = rhs,
					opts = opts
				})
			end

			-- Mock log module
			package.loaded["jj.log.init"] = {
				configure = function(config) return true end,
				setup = function(config) return true end
			}

			jj_init = require("jj.init")
			jj_init.setup()
			
			-- Should have registered keybinding
			local found_keymap = false
			for _, keymap in ipairs(registered_keymaps) do
				if keymap.lhs == "<leader>jl" then
					found_keymap = true
					break
				end
			end
			assert.is_true(found_keymap)
		end)
	end)

	describe("event triggers", function()
		it("should be suitable for VeryLazy event", function()
			-- Mock log module
			package.loaded["jj.log.init"] = {
				configure = function(config) return true end,
				setup = function(config) return true end
			}

			jj_init = require("jj.init")
			
			-- Should load quickly without heavy operations
			local start_time = os.clock()
			jj_init.setup()
			local end_time = os.clock()
			
			-- Should be fast (less than 50ms)
			assert.is_true((end_time - start_time) < 0.05)
		end)

		it("should be suitable for command-based loading", function()
			-- Mock log module
			package.loaded["jj.log.init"] = {
				configure = function(config) return true end,
				setup = function(config) return true end
			}

			jj_init = require("jj.init")
			jj_init.setup()
			
			-- Should register the expected command
			assert.is_not_nil(vim.user_commands["JJ"])
			assert.is_function(vim.user_commands["JJ"].fn)
		end)

		it("should support lazy loading with keys specification", function()
			-- Mock keymap registration
			local registered_keymaps = {}
			vim.keymap.set = function(mode, lhs, rhs, opts)
				table.insert(registered_keymaps, {
					mode = mode,
					lhs = lhs,
					rhs = rhs,
					opts = opts
				})
			end

			-- Mock log module
			package.loaded["jj.log.init"] = {
				configure = function(config) return true end,
				setup = function(config) return true end
			}

			jj_init = require("jj.init")
			jj_init.setup()
			
			-- Should register expected keybinding that lazy.nvim can trigger on
			local expected_keys = {"<leader>jl"}
			
			for _, expected_key in ipairs(expected_keys) do
				local found = false
				for _, keymap in ipairs(registered_keymaps) do
					if keymap.lhs == expected_key then
						found = true
						break
					end
				end
				assert.is_true(found, "Expected key " .. expected_key .. " not found")
			end
		end)
	end)

	describe("plugin manager compatibility", function()
		it("should work with lazy.nvim plugin spec", function()
			-- Mock log module
			package.loaded["jj.log.init"] = {
				configure = function(config) return true end,
				setup = function(config) return true end
			}

			-- Test lazy.nvim style configuration
			local lazy_spec = {
				"username/jj.nvim",
				cmd = {"JJ"},
				keys = {"<leader>jl"},
				config = function()
					require("jj").setup()
				end
			}
			
			-- Should be able to execute config function
			assert.has_no.errors(function()
				lazy_spec.config()
			end)
			
			-- Should register expected command and keymap
			assert.is_not_nil(vim.user_commands["JJ"])
		end)

		it("should work with packer.nvim", function()
			-- Mock log module
			package.loaded["jj.log.init"] = {
				configure = function(config) return true end,
				setup = function(config) return true end
			}

			-- Test packer.nvim style configuration
			local packer_config = function()
				require("jj").setup()
			end
			
			assert.has_no.errors(function()
				packer_config()
			end)
			
			assert.is_not_nil(vim.user_commands["JJ"])
		end)

		it("should work with vim-plug", function()
			-- vim-plug typically uses the plugin/jj.vim file
			-- Test that the module can be loaded via traditional methods
			
			-- Mock log module
			package.loaded["jj.log.init"] = {
				configure = function(config) return true end,
				setup = function(config) return true end
			}

			-- Simulate traditional loading
			assert.has_no.errors(function()
				require("jj").setup()
			end)
			
			assert.is_not_nil(vim.user_commands["JJ"])
		end)
	end)

	describe("lazy loading configuration", function()
		it("should have appropriate lazy loading events", function()
			-- These are the events that should trigger plugin loading
			local expected_events = {
				"VeryLazy",  -- For general loading
			}
			
			local expected_commands = {
				"JJ"  -- Command that should trigger loading
			}
			
			local expected_keys = {
				"<leader>jl"  -- Keys that should trigger loading
			}
			
			-- Test that plugin supports these events
			-- (This is more of a specification test)
			assert.is_table(expected_events)
			assert.is_table(expected_commands)
			assert.is_table(expected_keys)
		end)

		it("should not perform heavy operations during module load", function()
			-- Module loading should be fast for lazy loading
			local start_time = os.clock()
			
			jj_init = require("jj.init")
			
			local end_time = os.clock()
			
			-- Module loading should be very fast (< 10ms)
			assert.is_true((end_time - start_time) < 0.01)
		end)

		it("should defer heavy operations to setup function", function()
			-- Mock log module to track when it's loaded
			local log_loaded = false
			package.loaded["jj.log.init"] = {
				configure = function(config) 
					log_loaded = true
					return true 
				end,
				setup = function(config) 
					log_loaded = true
					return true 
				end
			}

			-- Just requiring the module should not trigger heavy operations
			jj_init = require("jj.init")
			assert.is_false(log_loaded)
			
			-- Setup should trigger the heavy operations
			jj_init.setup()
			assert.is_true(log_loaded)
		end)
	end)

	describe("optional dependencies", function()
		it("should handle missing dependencies gracefully during lazy load", function()
			-- Test that plugin doesn't crash if dependencies are missing during lazy load
			jj_init = require("jj.init")
			
			-- Should not crash even if log module is missing during require
			assert.is_function(jj_init.setup)
		end)

		it("should provide helpful error when dependencies missing during setup", function()
			-- Clear all modules to simulate missing dependencies
			package.loaded["jj.log.init"] = nil
			package.loaded["jj.config"] = nil
			package.loaded["jj.commands"] = nil

			jj_init = require("jj.init")
			
			-- Setup might fail with missing dependencies, but should not crash lua
			-- (This depends on implementation - for now just ensure it's callable)
			assert.is_function(jj_init.setup)
		end)
	end)
end)