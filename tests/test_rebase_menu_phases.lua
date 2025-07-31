-- Tests to verify rebase menu options properly transition to selection state
describe("rebase menu phases", function()
  local default_commands
  local command_context
  
  before_each(function()
    -- Reset modules
    package.loaded["jj.default_commands"] = nil
    package.loaded["jj.command_context"] = nil
    
    default_commands = require("jj.default_commands")
    command_context = require("jj.command_context")
  end)

  describe("rebase menu option phases", function()
    it("should have phases defined for all rebase menu options", function()
      local rebase_def = default_commands.get_command_definition("rebase")
      
      assert.is_not_nil(rebase_def)
      assert.is_not_nil(rebase_def.menu)
      assert.is_not_nil(rebase_def.menu.options)
      
      -- Check that all rebase menu options have phases
      for i, option in ipairs(rebase_def.menu.options) do
        assert.is_not_nil(option.phases, "Menu option " .. i .. " missing phases")
        assert.is_true(#option.phases > 0, "Menu option " .. i .. " has empty phases")
        
        -- Verify they all have target phase
        local has_target_phase = false
        for _, phase in ipairs(option.phases) do
          if phase.key == "target" then
            has_target_phase = true
            break
          end
        end
        assert.is_true(has_target_phase, "Menu option " .. i .. " missing target phase")
      end
    end)
    
    it("should have target phase for option 1 (Rebase current onto selected)", function()
      local rebase_def = default_commands.get_command_definition("rebase")
      local option1 = rebase_def.menu.options[1]
      
      assert.are.equal("1", option1.key)
      assert.are.equal("Rebase current onto selected", option1.desc)
      assert.is_not_nil(option1.phases)
      assert.are.equal(1, #option1.phases)
      assert.are.equal("target", option1.phases[1].key)
      assert.matches("Select target commit", option1.phases[1].prompt)
    end)
    
    it("should have target phase for option 2 (Rebase branch onto selected)", function()
      local rebase_def = default_commands.get_command_definition("rebase")
      local option2 = rebase_def.menu.options[2]
      
      assert.are.equal("2", option2.key)
      assert.are.equal("Rebase branch onto selected", option2.desc)
      assert.is_not_nil(option2.phases)
      assert.are.equal(1, #option2.phases)
      assert.are.equal("target", option2.phases[1].key)
      assert.matches("Select target commit", option2.phases[1].prompt)
    end)
    
    it("should have target phase for option 3 (Rebase with descendants)", function()
      local rebase_def = default_commands.get_command_definition("rebase")
      local option3 = rebase_def.menu.options[3]
      
      assert.are.equal("3", option3.key)
      assert.are.equal("Rebase with descendants", option3.desc)
      assert.is_not_nil(option3.phases)
      assert.are.equal(1, #option3.phases)
      assert.are.equal("target", option3.phases[1].key)
      assert.matches("Select target commit", option3.phases[1].prompt)
    end)
  end)
  
  describe("consistency with quick_action", function()
    it("should have consistent phase configuration between quick_action and menu options", function()
      local rebase_def = default_commands.get_command_definition("rebase")
      
      -- Quick action should have phases
      assert.is_not_nil(rebase_def.quick_action.phases)
      assert.are.equal(1, #rebase_def.quick_action.phases)
      assert.are.equal("target", rebase_def.quick_action.phases[1].key)
      
      -- All menu options should also have target phases
      for i, option in ipairs(rebase_def.menu.options) do
        assert.is_not_nil(option.phases, "Menu option " .. i .. " missing phases")
        
        local has_target_phase = false
        for _, phase in ipairs(option.phases) do
          if phase.key == "target" then
            has_target_phase = true
            break
          end
        end
        assert.is_true(has_target_phase, "Menu option " .. i .. " missing target phase")
      end
    end)
  end)
  
  describe("command arguments verification", function()
    it("should verify all rebase options use {target} in args", function()
      local rebase_def = default_commands.get_command_definition("rebase")
      
      -- Quick action should use {target}
      local qa_args = rebase_def.quick_action.args
      local qa_has_target = false
      for _, arg in ipairs(qa_args) do
        if arg == "{target}" then
          qa_has_target = true
          break
        end
      end
      assert.is_true(qa_has_target, "Quick action missing {target} in args")
      
      -- All menu options should use {target}
      for i, option in ipairs(rebase_def.menu.options) do
        local has_target = false
        for _, arg in ipairs(option.args) do
          if arg == "{target}" then
            has_target = true
            break
          end
        end
        assert.is_true(has_target, "Menu option " .. i .. " missing {target} in args")
      end
    end)
  end)
end)