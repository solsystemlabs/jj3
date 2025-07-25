-- Minimal debug test
require("helpers.vim_mock")

-- Mock vim.notify to capture messages
local notifications = {}
vim.notify = function(message, level)
  table.insert(notifications, {message = message, level = level})
  print("NOTIFY:", message, level)
end

vim.log = {
  levels = {
    ERROR = 1,
    WARN = 2,
    INFO = 3,
    DEBUG = 4
  }
}

-- Mock vim.fn functions
vim.fn = vim.fn or {}
vim.fn.getcwd = function()
  return "/Users/tayloreernisse/projects/jj3/tests/fixtures/complex-repo"
end

vim.fn.isdirectory = function(path)
  print("ISDIRECTORY CHECK:", path)
  if path:match("complex%-repo/%.jj$") then
    return 1
  end
  return 0
end

vim.fn.fnamemodify = function(path, modifier)
  if modifier == ":h" then
    return path:match("^(.+)/[^/]*$") or "/"
  end
  return path
end

vim.fn.system = function(command)
  print("SYSTEM COMMAND:", command)
  if command:match("command %-v jj") then
    return "/usr/local/bin/jj\n"
  elseif command:match("jj %-%-version") then
    return "jj 0.15.1\n"
  elseif command:match("jj.*log") then
    return "commit1\ncommit2\ncommit3"
  end
  return ""
end

vim.v = {shell_error = 0}

-- Test repository validation first
print("Testing repository validation...")
local repository = require("jj.utils.repository")
local validation = repository.validate_repository()
print("Validation result:", vim.inspect(validation))

if not validation.valid then
  print("Repository validation failed:", validation.error)
else
  print("Repository validation succeeded")
end