-- Simple debug test without mocking issues
package.path = package.path .. ";lua/?.lua;tests/?.lua"

-- Set up minimal vim environment
_G.vim = {
  fn = {
    getcwd = function() return "/Users/tayloreernisse/projects/jj3/tests/fixtures/complex-repo" end,
    isdirectory = function(path) return path:match("complex%-repo/%.jj$") and 1 or 0 end,
    fnamemodify = function(path, mod) return mod == ":h" and (path:match("^(.+)/[^/]*$") or "/") or path end,
    system = function(cmd) 
      if cmd:match("command %-v jj") then return "/usr/local/bin/jj\n"
      elseif cmd:match("jj.*version") then return "jj 0.15.1\n"
      elseif cmd:match("jj.*log") then return "test log output"
      end
      return ""
    end,
    shellescape = function(s) return "'" .. s .. "'" end,
    jobstart = function() return 1 end,
  },
  v = {shell_error = 0},
  notify = function(msg, level) print("NOTIFY:", msg, level) end,
  log = {levels = {ERROR = 1, INFO = 3}},
  api = {
    nvim_create_buf = function() return 1 end,
    nvim_buf_set_name = function() end,
    nvim_buf_set_option = function() end,
    nvim_buf_set_lines = function() end,
    nvim_open_win = function() return 1 end,
    nvim_win_is_valid = function() return true end,
    nvim_create_namespace = function() return 1 end,
    nvim_buf_clear_namespace = function() end,
    nvim_buf_add_highlight = function() end,
    nvim_set_hl = function() end,
  },
  wait = function() end,
  loop = {now = function() return 0 end},
}

-- Change directory
local lfs = require('lfs')
lfs.chdir("tests/fixtures/complex-repo")

-- Test repository module first
print("=== Testing repository module ===")
local repo = require("jj.utils.repository")
local validation = repo.validate_repository()
print("Validation:", vim.inspect or function(t) return tostring(t) end)(validation)

if validation.valid then
  print("=== Testing executor module ===")
  local executor = require("jj.log.executor")
  local result = executor.execute_jj_command("log --color=always")
  print("Executor result:", result.success, result.error)
  
  if result.success then
    print("=== Testing integration ===")
    local integration = require("jj.log.init")
    local success = integration.show_log()
    print("Integration result:", success)
  end
end