# Technical Specification

This is the technical specification for the spec detailed in @.agent-os/specs/2025-07-31-interactive-terminal-commands/spec.md

> Created: 2025-07-31
> Version: 1.0.0

## Technical Requirements

- **Interactive Command Detection** - Programmatically identify commands that will spawn interactive processes (editors, diff tools, merge tools)
- **Floating Terminal Creation** - Use `vim.api.nvim_open_win()` with terminal buffer (`vim.api.nvim_open_term()`) for interactive command execution
- **Process Monitoring** - Track command execution state and detect completion without blocking the UI
- **Environment Preservation** - Ensure `$EDITOR`, `$VISUAL`, and jj tool configurations are properly passed to the terminal environment
- **Window Management** - Handle terminal window sizing, positioning, focus management, and cleanup
- **Async Integration** - Integrate with existing async command execution framework while supporting interactive input/output

## Approach Options

**Option A: Pre-classify Interactive Commands**
- Pros: Predictable behavior, simpler implementation, explicit control over which commands get terminal treatment
- Cons: Requires maintenance as jj evolves, may miss edge cases or custom user configurations

**Option B: Dynamic Interactive Detection** (Selected)
- Pros: Future-proof, handles custom editor configurations, works with any interactive command
- Cons: More complex implementation, requires runtime detection logic

**Option C: User Configuration Only**
- Pros: Maximum flexibility, users control the behavior
- Cons: Poor out-of-box experience, requires users to configure everything

**Rationale:** Option B provides the best balance of usability and flexibility. We can detect when jj is likely to spawn an interactive process (no `-m` flag for describe, `--interactive` flags, etc.) and fall back to terminal mode when uncertain. This aligns with the product decision to provide good defaults while remaining extensible.

## External Dependencies

- **Neovim Terminal API** - Built-in terminal emulation via `vim.api.nvim_open_term()`
- **Job Control API** - `vim.fn.jobstart()` and `vim.fn.jobwait()` for process management
- **Window Management API** - `vim.api.nvim_open_win()` for floating window creation

**Justification:** All dependencies are built-in Neovim APIs, maintaining zero external dependencies and ensuring compatibility across Neovim installations.

## Implementation Details

### Interactive Command Detection Logic

```lua
local function is_interactive_command(cmd, args)
  -- Commands that are always interactive without flags
  local always_interactive = {
    "split", "resolve", "diffedit"
  }
  
  -- Commands that are interactive without specific flags
  local conditional_interactive = {
    describe = function(args)
      return not (vim.tbl_contains(args, "-m") or vim.tbl_contains(args, "--message") or 
                  vim.tbl_contains(args, "--stdin") or vim.tbl_contains(args, "--no-edit"))
    end,
    squash = function(args)
      return vim.tbl_contains(args, "-i") or vim.tbl_contains(args, "--interactive")
    end
  }
  
  return vim.tbl_contains(always_interactive, cmd) or 
         (conditional_interactive[cmd] and conditional_interactive[cmd](args))
end
```

### Floating Terminal Management

```lua
local function create_interactive_terminal(cmd, args, on_exit)
  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " jj " .. cmd .. " ",
    title_pos = "center"
  })
  
  local job_id = vim.fn.termopen({"jj", cmd, unpack(args)}, {
    on_exit = function(_, exit_code)
      vim.api.nvim_win_close(win, true)
      on_exit(exit_code)
    end
  })
  
  return buf, win, job_id
end
```

### Integration with Existing Command System

The interactive terminal system will integrate with the existing command execution framework by:

1. **Command Router Enhancement** - Modify the command execution logic to check for interactive commands before standard execution
2. **Callback Integration** - Use the same callback system for log refresh and message display
3. **Error Handling** - Integrate with existing error handling and user feedback systems
4. **Configuration Respect** - Honor existing user configuration for command customization while adding terminal-specific options