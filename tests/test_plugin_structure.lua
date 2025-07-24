-- Tests for plugin structure validation
-- Load vim mock before tests
require("helpers.vim_mock")

describe("Plugin Structure", function()
	it("should have all required directories", function()
		local lfs = require("lfs")

		-- Check plugin directory exists
		local plugin_attr = lfs.attributes("plugin")
		assert.is_not_nil(plugin_attr)
		assert.equals("directory", plugin_attr.mode)

		-- Check lua/jj directory exists
		local lua_jj_attr = lfs.attributes("lua/jj")
		assert.is_not_nil(lua_jj_attr)
		assert.equals("directory", lua_jj_attr.mode)
	end)

	it("should have required plugin files", function()
		local lfs = require("lfs")

		-- Check plugin/jj.vim exists
		local jj_vim_attr = lfs.attributes("plugin/jj.vim")
		assert.is_not_nil(jj_vim_attr)
		assert.equals("file", jj_vim_attr.mode)
	end)

	it("should have required lua modules", function()
		local lfs = require("lfs")

		-- Check init.lua exists
		local init_attr = lfs.attributes("lua/jj/init.lua")
		assert.is_not_nil(init_attr)
		assert.equals("file", init_attr.mode)

		-- Check config.lua exists
		local config_attr = lfs.attributes("lua/jj/config.lua")
		assert.is_not_nil(config_attr)
		assert.equals("file", config_attr.mode)

		-- Check commands.lua exists
		local commands_attr = lfs.attributes("lua/jj/commands.lua")
		assert.is_not_nil(commands_attr)
		assert.equals("file", commands_attr.mode)
	end)

	it("should be able to require lua modules without errors", function()
		-- Add lua path for testing
		package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

		-- This will test basic module structure
		assert.has_no.errors(function()
			require("jj.init")
		end)

		assert.has_no.errors(function()
			require("jj.config")
		end)

		assert.has_no.errors(function()
			require("jj.commands")
		end)
	end)
end)
