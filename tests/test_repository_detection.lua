-- Tests for repository detection and validation
require("helpers.vim_mock")
local test_repo = require("helpers.test_repository")

-- Load the repository module from the plugin directory
local repository = dofile("lua/jj/utils/repository.lua")

describe("Repository Detection", function()
  local lfs = require('lfs')
  local original_cwd

  before_each(function()
    -- Save original working directory
    original_cwd = lfs.currentdir()
  end)

  after_each(function() 
    -- Restore original working directory
    lfs.chdir(original_cwd)
  end)

  describe("jj directory detection", function()
    it("should detect valid jj repository", function()
      -- Debug: print current working directory
      print("Test working dir:", lfs.currentdir())
      
      -- Change to test repository directory
      lfs.chdir(test_repo.test_repo_path)
      
      assert.is_true(repository.is_jj_repository())
    end)

    it("should detect invalid jj repository in non-jj directory", function()
      -- Change to a directory without .jj
      lfs.chdir("tests/fixtures/non-jj-dir")
      
      assert.is_false(repository.is_jj_repository())
    end)

    it("should detect .jj directory in parent directories", function()
      -- Change to subdirectory of test repository
      lfs.chdir(test_repo.test_repo_path)
      lfs.mkdir("subdir")
      lfs.chdir("subdir")
      
      assert.is_true(repository.is_jj_repository())
      
      -- Cleanup
      lfs.chdir("..")
      os.remove("subdir")
    end)

    it("should return repository root path", function()
      lfs.chdir(test_repo.test_repo_path)
      
      local repo_root = repository.get_repository_root()
      
      assert.is_not_nil(repo_root)
      assert.is_true(repo_root:match("complex-repo$") ~= nil)
    end)

    it("should return nil for repository root when not in jj repo", function()
      lfs.chdir("tests/fixtures/non-jj-dir")
      
      local repo_root = repository.get_repository_root()
      
      assert.is_nil(repo_root)
    end)
  end)

  describe("jj command availability", function()
    it("should detect jj command availability", function()
      assert.is_true(repository.is_jj_available())
    end)

    it("should return jj version information", function()
      local version = repository.get_jj_version()
      
      assert.is_not_nil(version)
      assert.is_string(version)
      assert.is_true(#version > 0)
    end)
  end)

  describe("repository validation", function()
    it("should validate complete repository setup", function()
      lfs.chdir(test_repo.test_repo_path)
      
      local validation = repository.validate_repository()
      
      assert.is_true(validation.valid)
      assert.is_nil(validation.error)
      assert.is_not_nil(validation.repository_root)
      assert.is_not_nil(validation.jj_version)
    end)

    it("should return validation error for non-jj directory", function()
      lfs.chdir("tests/fixtures/non-jj-dir")
      
      local validation = repository.validate_repository()
      
      assert.is_false(validation.valid)
      assert.is_not_nil(validation.error)
      assert.is_nil(validation.repository_root)
    end)

    it("should return appropriate error messages", function()
      lfs.chdir("tests/fixtures/non-jj-dir")
      
      local validation = repository.validate_repository()
      
      assert.is_string(validation.error)
      assert.is_true(validation.error:match("jj repository") ~= nil)
    end)
  end)
end)