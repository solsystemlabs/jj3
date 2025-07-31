-- Tests for interactive command detection system
require("helpers.vim_mock")

describe("Interactive Command Detection", function()
  local interactive_detection

  before_each(function()
    -- Load the interactive detection module
    interactive_detection = dofile("lua/jj/interactive_detection.lua")
    -- Reset config before each test
    interactive_detection.reset_config()
  end)

  describe("always_interactive commands", function()
    it("should detect split as always interactive", function()
      local result = interactive_detection.is_interactive_command("split", {})
      assert.is_true(result)
    end)

    it("should detect split as interactive with any args", function()
      local result = interactive_detection.is_interactive_command("split", {"-r", "abc123"})
      assert.is_true(result)
    end)

    it("should detect resolve as always interactive", function()
      local result = interactive_detection.is_interactive_command("resolve", {})
      assert.is_true(result)
    end)

    it("should detect resolve as interactive with file args", function()
      local result = interactive_detection.is_interactive_command("resolve", {"src/main.rs"})
      assert.is_true(result)
    end)

    it("should detect diffedit as always interactive", function()
      local result = interactive_detection.is_interactive_command("diffedit", {})
      assert.is_true(result)
    end)

    it("should detect diffedit as interactive with revision args", function()
      local result = interactive_detection.is_interactive_command("diffedit", {"-r", "@"})
      assert.is_true(result)
    end)
  end)

  describe("conditional interactive commands", function()
    describe("describe command", function()
      it("should be interactive without flags", function()
        local result = interactive_detection.is_interactive_command("describe", {})
        assert.is_true(result)
      end)

      it("should be interactive with only revision args", function()
        local result = interactive_detection.is_interactive_command("describe", {"-r", "abc123"})
        assert.is_true(result)
      end)

      it("should NOT be interactive with -m flag", function()
        local result = interactive_detection.is_interactive_command("describe", {"-m", "commit message"})
        assert.is_false(result)
      end)

      it("should NOT be interactive with --message flag", function()
        local result = interactive_detection.is_interactive_command("describe", {"--message", "commit message"})
        assert.is_false(result)
      end)

      it("should NOT be interactive with --stdin flag", function()
        local result = interactive_detection.is_interactive_command("describe", {"--stdin"})
        assert.is_false(result)
      end)

      it("should NOT be interactive with --no-edit flag", function()
        local result = interactive_detection.is_interactive_command("describe", {"--no-edit"})
        assert.is_false(result)
      end)

      it("should NOT be interactive with combined non-interactive flags", function()
        local result = interactive_detection.is_interactive_command("describe", {"-r", "abc123", "-m", "message"})
        assert.is_false(result)
      end)
    end)

    describe("squash command", function()
      it("should NOT be interactive without flags", function()
        local result = interactive_detection.is_interactive_command("squash", {})
        assert.is_false(result)
      end)

      it("should NOT be interactive with only revision args", function()
        local result = interactive_detection.is_interactive_command("squash", {"-r", "abc123"})
        assert.is_false(result)
      end)

      it("should be interactive with -i flag", function()
        local result = interactive_detection.is_interactive_command("squash", {"-i"})
        assert.is_true(result)
      end)

      it("should be interactive with --interactive flag", function()
        local result = interactive_detection.is_interactive_command("squash", {"--interactive"})
        assert.is_true(result)
      end)

      it("should be interactive with --tool flag", function()
        local result = interactive_detection.is_interactive_command("squash", {"--tool", "meld"})
        assert.is_true(result)
      end)

      it("should be interactive with combined interactive flags", function()
        local result = interactive_detection.is_interactive_command("squash", {"-r", "abc123", "--interactive"})
        assert.is_true(result)
      end)
    end)

    describe("new command", function()
      it("should be interactive without args (opens editor for description)", function()
        local result = interactive_detection.is_interactive_command("new", {})
        assert.is_true(result)
      end)

      it("should NOT be interactive with -m flag", function()
        local result = interactive_detection.is_interactive_command("new", {"-m", "new commit"})
        assert.is_false(result)
      end)

      it("should NOT be interactive with --message flag", function()
        local result = interactive_detection.is_interactive_command("new", {"--message", "new commit"})
        assert.is_false(result)
      end)
    end)

    describe("commit command", function()
      it("should be interactive without flags (opens editor)", function()
        local result = interactive_detection.is_interactive_command("commit", {})
        assert.is_true(result)
      end)

      it("should NOT be interactive with -m flag", function()
        local result = interactive_detection.is_interactive_command("commit", {"-m", "commit message"})
        assert.is_false(result)
      end)
    end)
  end)

  describe("never_interactive commands", function()
    it("should detect log as never interactive", function()
      local result = interactive_detection.is_interactive_command("log", {})
      assert.is_false(result)
    end)

    it("should detect log as never interactive with any args", function()
      local result = interactive_detection.is_interactive_command("log", {"--graph", "-r", "abc123"})
      assert.is_false(result)
    end)

    it("should detect show as never interactive", function()
      local result = interactive_detection.is_interactive_command("show", {"abc123"})
      assert.is_false(result)
    end)

    it("should detect status as never interactive", function()
      local result = interactive_detection.is_interactive_command("status", {})
      assert.is_false(result)
    end)

    it("should detect diff as never interactive", function()
      local result = interactive_detection.is_interactive_command("diff", {})
      assert.is_false(result)
    end)
  end)

  describe("user configuration overrides", function()
    it("should respect force_interactive override", function()
      local config = {
        force_interactive = {"log"}
      }
      interactive_detection.set_user_config(config)
      
      local result = interactive_detection.is_interactive_command("log", {})
      assert.is_true(result)
    end)

    it("should respect force_non_interactive override", function()
      local config = {
        force_non_interactive = {"describe"}
      }
      interactive_detection.set_user_config(config)
      
      local result = interactive_detection.is_interactive_command("describe", {})
      assert.is_false(result)
    end)

    it("should respect custom interactive flags", function()
      local config = {
        custom_interactive_flags = {
          ["my-command"] = {"-e", "--edit"}
        }
      }
      interactive_detection.set_user_config(config)
      
      local result = interactive_detection.is_interactive_command("my-command", {"-e"})
      assert.is_true(result)
    end)

    it("should prioritize force_interactive over force_non_interactive", function()
      local config = {
        force_interactive = {"describe"},
        force_non_interactive = {"describe"}
      }
      interactive_detection.set_user_config(config)
      
      local result = interactive_detection.is_interactive_command("describe", {})
      assert.is_true(result)
    end)
  end)

  describe("edge cases", function()
    it("should handle unknown commands as non-interactive by default", function()
      local result = interactive_detection.is_interactive_command("unknown-command", {})
      assert.is_false(result)
    end)

    it("should handle nil command gracefully", function()
      local result = interactive_detection.is_interactive_command(nil, {})
      assert.is_false(result)
    end)

    it("should handle nil args gracefully", function()
      local result = interactive_detection.is_interactive_command("describe", nil)
      assert.is_true(result)
    end)

    it("should handle empty string command", function()
      local result = interactive_detection.is_interactive_command("", {})
      assert.is_false(result)
    end)

    it("should handle non-string command", function()
      local result = interactive_detection.is_interactive_command(123, {})
      assert.is_false(result)
    end)

    it("should handle non-table args", function()
      local result = interactive_detection.is_interactive_command("describe", "not-a-table")
      assert.is_true(result)
    end)
  end)

  describe("flag parsing utilities", function()
    it("should correctly identify single character flags", function()
      local has_flag = interactive_detection._has_flag({"-m", "message"}, "-m")
      assert.is_true(has_flag)
    end)

    it("should correctly identify long flags", function()
      local has_flag = interactive_detection._has_flag({"--message", "text"}, "--message")
      assert.is_true(has_flag)
    end)

    it("should handle combined short flags", function()
      local has_flag = interactive_detection._has_flag({"-im", "message"}, "-i")
      assert.is_true(has_flag)
    end)

    it("should return false for absent flags", function()
      local has_flag = interactive_detection._has_flag({"-r", "abc123"}, "-m")
      assert.is_false(has_flag)
    end)

    it("should handle any_flag detection", function()
      local has_any = interactive_detection._has_any_flag({"-m", "message"}, {"-m", "--message", "--stdin"})
      assert.is_true(has_any)
    end)

    it("should handle any_flag with no matches", function()
      local has_any = interactive_detection._has_any_flag({"-r", "abc123"}, {"-m", "--message", "--stdin"})
      assert.is_false(has_any)
    end)
  end)
end)