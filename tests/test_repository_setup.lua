-- Tests for test repository creation and validation
-- Load vim mock and test utilities
require("helpers.vim_mock")
local test_repo = require("helpers.test_repository")

describe("Test Repository Setup", function()
  local lfs = require('lfs')
  
  it("should have test repository directory structure", function()
    -- Check fixtures directory exists
    local fixtures_attr = lfs.attributes("tests/fixtures")
    assert.is_not_nil(fixtures_attr)
    assert.equals("directory", fixtures_attr.mode)
    
    -- Check snapshots directory exists
    local snapshots_attr = lfs.attributes("tests/fixtures/snapshots")
    assert.is_not_nil(snapshots_attr)
    assert.equals("directory", snapshots_attr.mode)
  end)
  
  it("should have valid jj repository", function()
    assert.is_true(test_repo.is_test_repo_valid())
  end)
  
  it("should have expected snapshot files", function()
    for snapshot_name, filename in pairs(test_repo.snapshots) do
      local path = test_repo.snapshots_path .. "/" .. filename
      local file_attr = lfs.attributes(path)
      assert.is_not_nil(file_attr, "Missing snapshot file: " .. filename)
      assert.equals("file", file_attr.mode)
    end
  end)
  
  it("should be able to load snapshot files", function()
    for snapshot_name in pairs(test_repo.snapshots) do
      local content = test_repo.load_snapshot(snapshot_name)
      assert.is_not_nil(content)
      assert.is_true(#content > 0, "Snapshot " .. snapshot_name .. " is empty")
    end
  end)
  
  it("should have complex repository structure", function()
    -- Check that we have a reasonable number of commits (should be > 15)
    local commit_count = test_repo.get_expected_commit_count()
    assert.is_true(commit_count > 15, "Expected complex repository with many commits, got " .. commit_count)
    
    -- Check that we have expected bookmarks
    local bookmarks = test_repo.get_expected_bookmarks()
    assert.is_true(#bookmarks >= 5, "Expected multiple bookmarks, got " .. #bookmarks)
  end)
  
  it("should generate different template outputs", function()
    local minimal = test_repo.load_snapshot("minimal_template")
    local comprehensive = test_repo.load_snapshot("comprehensive_template")  
    local default = test_repo.load_snapshot("default_log")
    
    -- Each should be different
    assert.is_not.equals(minimal, comprehensive)
    assert.is_not.equals(minimal, default)
    assert.is_not.equals(comprehensive, default)
    
    -- Minimal should only contain commit IDs (shorter)
    assert.is_true(#minimal < #comprehensive, "Minimal template should be shorter")
  end)
end)