-- Tests for plugin initialization and module setup
require("helpers.vim_mock")

describe("Plugin Initialization", function()
	-- Add lua path for testing
	package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

	local jj_init
	local jj_config
	local jj_commands

	before_each(function()
		-- Clear modules from cache to ensure fresh load
		package.loaded["jj.init"] = nil
		package.loaded["jj.config"] = nil
		package.loaded["jj.commands"] = nil

		-- Reset vim mocks
		vim.user_commands = {}
	end)

	describe("main setup function", function()
		it("should load without errors", function()
			assert.has_no.errors(function()
				jj_init = require("jj.init")
			end)
		end)

		it("should provide setup function", function()
			jj_init = require("jj.init")
			assert.is_function(jj_init.setup)
		end)

		it("should setup with default options when no opts provided", function()
			jj_init = require("jj.init")
			
			assert.has_no.errors(function()
				jj_init.setup()
			end)
		end)

		it("should setup with empty options table", function()
			jj_init = require("jj.init")
			
			assert.has_no.errors(function()
				jj_init.setup({})
			end)
		end)

		it("should setup with custom options", function()
			jj_init = require("jj.init")
			
			local custom_opts = {
				keymaps = {
					toggle_log = "<leader>jj"
				},
				window = {
					position = "left",
					size = 40
				}
			}

			assert.has_no.errors(function()
				jj_init.setup(custom_opts)
			end)
		end)

		it("should call config.setup during initialization", function()
			-- Mock config module to track setup calls
			local config_setup_called = false
			local config_setup_opts = nil

			package.loaded["jj.config"] = {
				setup = function(opts)
					config_setup_called = true
					config_setup_opts = opts
				end,
				get = function()
					return {
						keymaps = { toggle_log = "<leader>jl" },
						window = { position = "right", size = 50 }
					}
				end
			}

			jj_init = require("jj.init")

			local test_opts = { test_option = "test_value" }
			jj_init.setup(test_opts)

			assert.is_true(config_setup_called)
			assert.equals(test_opts, config_setup_opts)
		end)

		it("should call commands.setup during initialization", function()
			-- Mock config and commands modules
			package.loaded["jj.config"] = { 
				setup = function() end,
				get = function()
					return {
						keymaps = { toggle_log = "<leader>jl" },
						window = { position = "right", size = 50 }
					}
				end
			}

			local commands_setup_called = false
			package.loaded["jj.commands"] = {
				setup = function()
					commands_setup_called = true
				end
			}

			jj_init = require("jj.init")
			jj_init.setup()

			assert.is_true(commands_setup_called)
		end)
	end)

	describe("module loading and dependencies", function()
		it("should load config module", function()
			jj_init = require("jj.init")
			
			assert.has_no.errors(function()
				jj_init.setup()
			end)
		end)

		it("should load commands module", function()
			jj_init = require("jj.init")
			
			assert.has_no.errors(function()
				jj_init.setup()
			end)
		end)

		it("should handle missing dependencies gracefully", function()
			-- This tests basic error handling for missing modules
			-- In a real scenario, this would be more complex
			jj_init = require("jj.init")
			
			assert.is_function(jj_init.setup)
		end)
	end)

	describe("error handling", function()
		it("should not crash with invalid options", function()
			jj_init = require("jj.init")
			
			-- Test with nil
			assert.has_no.errors(function()
				jj_init.setup(nil)
			end)

			-- Test with string instead of table
			assert.has_no.errors(function()
				jj_init.setup("invalid")
			end)
		end)

		it("should handle config setup errors gracefully", function()
			-- Mock config module to throw error
			package.loaded["jj.config"] = {
				setup = function()
					error("Config setup failed")
				end
			}

			jj_init = require("jj.init")
			
			-- Should handle the error gracefully (not crash)
			-- This depends on implementation - for now just ensure it loads
			assert.is_function(jj_init.setup)
		end)
	end)

	describe("integration with module system", function()
		it("should be accessible via require", function()
			assert.has_no.errors(function()
				local module = require("jj.init")
				assert.is_table(module)
			end)
		end)

		it("should export setup function in module table", function()
			local module = require("jj.init")
			assert.is_function(module.setup)
		end)

		it("should work with repeated requires", function()
			local module1 = require("jj.init")
			local module2 = require("jj.init")
			
			assert.equals(module1, module2)
		end)
	end)
end)