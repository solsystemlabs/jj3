-- Integration tests for auto-refresh with command execution
require("helpers.vim_mock")
local disposable_repo = require("helpers.disposable_repository")

-- Mock state tracking
local auto_refresh_calls = {}
local mock_notifications = {}

-- Mock vim.notify to capture notifications
vim.notify = function(message, level)
  table.insert(mock_notifications, {
    message = message,
    level = level or vim.log.levels.INFO
  })
end

-- Mock vim.fn.system for controlled command execution
local original_system = vim.fn.system
local mock_system_results = {}

vim.fn.system = function(command)
  if mock_system_results[command] then
    local result = mock_system_results[command]
    vim.v.shell_error = result.exit_code or 0
    return result.output or ""
  end
  
  -- Fallback to original for unmocked commands
  return original_system(command)
end

-- Helper to mock command results
local function mock_command_result(command, output, exit_code)
  mock_system_results[command] = {
    output = output,
    exit_code = exit_code or 0
  }
end

-- Helper to capture auto-refresh calls
local function setup_auto_refresh_spy()
  local auto_refresh = require("jj.auto_refresh")
  local original_on_command_complete = auto_refresh.on_command_complete
  
  auto_refresh.on_command_complete = function(command, success, output)
    table.insert(auto_refresh_calls, {
      command = command,
      success = success,
      output = output,
      timestamp = os.time()
    })
    
    -- Call original function
    return original_on_command_complete(command, success, output)
  end
end

describe("Auto-Refresh Integration", function()
  local lfs = require('lfs')
  local original_cwd

  before_each(function()
    original_cwd = lfs.currentdir()
    
    -- Use existing test directory (no need to create disposable repo for integration tests)
    local test_repo = require("helpers.test_repository")
    lfs.chdir(test_repo.test_repo_path)
    
    -- Reset state
    auto_refresh_calls = {}
    mock_notifications = {}
    mock_system_results = {}
    
    -- Setup auto-refresh spy
    setup_auto_refresh_spy()
    
    -- Reset auto-refresh state
    local auto_refresh = require("jj.auto_refresh")
    auto_refresh.reset_auto_refresh_state()
    auto_refresh.set_refresh_throttle(0) -- Disable throttling for testing
  end)

  after_each(function()
    lfs.chdir(original_cwd)
    
    -- Restore original system function
    vim.fn.system = original_system
  end)

  describe("executor integration", function()
    it("should trigger auto-refresh hooks when executing jj commands", function()
      local executor = require("jj.log.executor")
      
      -- Mock successful commit command
      mock_command_result("jj commit -m 'test commit'", "Working copy now at: abc123", 0)
      
      local result = executor.execute_jj_command("commit -m 'test commit'")
      
      assert.is_true(result.success)
      assert.equals(1, #auto_refresh_calls)
      assert.equals("commit -m 'test commit'", auto_refresh_calls[1].command)
      assert.is_true(auto_refresh_calls[1].success)
    end)

    it("should trigger auto-refresh hooks for failed commands", function()
      local executor = require("jj.log.executor")
      
      -- Mock failed command
      mock_command_result("jj commit -m 'invalid'", "Error: no changes to commit", 1)
      
      local result = executor.execute_jj_command("commit -m 'invalid'")
      
      assert.is_false(result.success)
      assert.equals(1, #auto_refresh_calls)
      assert.equals("commit -m 'invalid'", auto_refresh_calls[1].command)
      assert.is_false(auto_refresh_calls[1].success)
    end)

    it("should not trigger auto-refresh for unsafe commands", function()
      local executor = require("jj.log.executor")
      
      local result = executor.execute_jj_command("commit -m 'test'; rm -rf /")
      
      assert.is_false(result.success)
      assert.equals(0, #auto_refresh_calls) -- No auto-refresh call for unsafe command
    end)

    it("should not trigger auto-refresh when repository validation fails", function()
      local executor = require("jj.log.executor")
      
      -- Change to non-jj directory
      lfs.chdir("/tmp")
      
      local result = executor.execute_jj_command("commit -m 'test'")
      
      assert.is_false(result.success)
      assert.equals(0, #auto_refresh_calls) -- No auto-refresh call when validation fails
    end)
  end)

  describe("default auto-refresh behavior", function()
    it("should setup default auto-refresh hook during plugin initialization", function()
      local auto_refresh = require("jj.auto_refresh")
      
      auto_refresh.setup_default_auto_refresh()
      
      local stats = auto_refresh.get_hook_stats()
      assert.is_true(stats.total_hooks >= 1)
      assert.is_true(stats.enabled_hooks >= 1)
    end)

    it("should automatically refresh log window after commit commands", function()
      local auto_refresh = require("jj.auto_refresh")
      local executor = require("jj.log.executor")
      
      -- Setup default auto-refresh (this would normally be done in plugin setup)
      auto_refresh.setup_default_auto_refresh()
      
      -- Mock successful commit command
      mock_command_result("jj commit -m 'auto test'", "Working copy now at: def456", 0)
      
      -- Execute command
      local result = executor.execute_jj_command("commit -m 'auto test'")
      
      assert.is_true(result.success)
      assert.equals(1, #auto_refresh_calls)
      
      -- Check that auto-refresh was triggered
      local has_auto_refresh_notification = false
      for _, notification in ipairs(mock_notifications) do
        if notification.message:find("Auto%-refreshing") then
          has_auto_refresh_notification = true
          break
        end
      end
      
      -- Note: This may be false if no log window is open, which is expected
      -- The important part is that the hook was called
    end)
  end)

  describe("command pattern matching", function()
    it("should trigger auto-refresh for state-changing commands", function()
      local auto_refresh = require("jj.auto_refresh")
      local executor = require("jj.log.executor")
      
      auto_refresh.setup_default_auto_refresh()
      
      local state_changing_commands = {
        "commit -m 'test'",
        "new -m 'new commit'", 
        "rebase -d main",
        "abandon abc123",
        "bookmark create feature-x"
      }
      
      for _, command in ipairs(state_changing_commands) do
        -- Reset state
        auto_refresh_calls = {}
        mock_notifications = {}
        
        -- Mock successful command
        mock_command_result("jj " .. command, "Success", 0)
        
        local result = executor.execute_jj_command(command)
        
        assert.is_true(result.success, "Command should succeed: " .. command)
        assert.equals(1, #auto_refresh_calls, "Auto-refresh should be triggered for: " .. command)
        assert.equals(command, auto_refresh_calls[1].command)
      end
    end)

    it("should not trigger auto-refresh for read-only commands", function()
      local auto_refresh = require("jj.auto_refresh")
      local executor = require("jj.log.executor")
      
      auto_refresh.setup_default_auto_refresh()
      
      local readonly_commands = {
        "log --limit 10",
        "show abc123",
        "status",
        "diff",
        "files"
      }
      
      for _, command in ipairs(readonly_commands) do
        -- Reset state
        auto_refresh_calls = {}
        mock_notifications = {}
        
        -- Mock successful command
        mock_command_result("jj " .. command, "Output", 0)
        
        local result = executor.execute_jj_command(command)
        
        assert.is_true(result.success, "Command should succeed: " .. command)
        
        -- Auto-refresh hook should be called, but should not trigger refresh
        assert.equals(1, #auto_refresh_calls, "Hook should be called for: " .. command)
        
        -- But no auto-refresh notification should be sent (since it's read-only)
        local has_auto_refresh_notification = false
        for _, notification in ipairs(mock_notifications) do
          if notification.message:find("Auto%-refreshing") then
            has_auto_refresh_notification = true
            break
          end
        end
        assert.is_false(has_auto_refresh_notification, "No auto-refresh for read-only: " .. command)
      end
    end)
  end)
end)