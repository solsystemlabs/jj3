# Technical Specification

This is the technical specification for the spec detailed in @.agent-os/specs/2025-07-24-log-parsing-display/spec.md

> Created: 2025-07-24
> Version: 1.0.0

## Technical Requirements

- **Dual-Pass Log Processing**: Execute two separate jj commands - one for graph structure and commit IDs, another for detailed commit information
- **Structured Data Parsing**: Parse jj log output into Lua tables representing commits, graph lines, and relationships
- **ANSI Color Rendering**: Preserve and render ANSI color codes from jj output in Neovim buffer
- **Template Engine Integration**: Support jj's native templating system with user customization
- **Buffer Management**: Efficiently reuse buffers and handle modifiable state transitions
- **Repository Detection**: Validate jj repository context before executing commands

## Approach Options

**Option A:** Single-pass parsing with regex extraction
- Pros: Simpler implementation, fewer jj command executions
- Cons: Brittle parsing, difficult to extract all commit details reliably

**Option B:** Dual-pass parsing with structured data (Selected)
- Pros: Robust data extraction, enables future features, reliable commit ID mapping
- Cons: More complex implementation, requires two jj command executions

**Rationale:** The dual-pass approach provides the foundation for all future interactive features and ensures reliable data parsing without fragile regex patterns.

## External Dependencies

- **jujutsu (jj)** - Command-line tool for log generation and templating
- **Neovim 0.11+ APIs** - For buffer management, job control, and ANSI rendering
- **No external Lua libraries** - Pure Lua implementation for maximum compatibility

## Architecture Overview

### Module Structure
```
lua/jj/
├── log/
│   ├── init.lua          # Main log orchestration
│   ├── parser.lua        # Log output parsing logic
│   ├── executor.lua      # jj command execution
│   └── renderer.lua      # Buffer rendering with ANSI colors
├── ui/
│   └── window.lua        # Window/buffer management
└── utils/
    ├── ansi.lua          # ANSI color code processing
    └── repository.lua    # Repository detection utilities
```

### Data Structures

**Commit Object:**
```lua
{
  commit_id = "abc123...",              -- Full commit ID
  change_id = "xyz789...",              -- jj change ID
  graph_line = "├─ ",                   -- Graph characters for this commit
  author = {
    name = "...",                       -- Author name
    email = "...",                      -- Author email
    timestamp = "..."                   -- Author timestamp
  },
  committer = {
    name = "...",                       -- Committer name
    email = "...",                      -- Committer email
    timestamp = "..."                   -- Committer timestamp
  },
  bookmarks = "...",                    -- Associated bookmarks string
  tags = "...",                         -- Associated tags string
  description = "...",                  -- Full commit description
  mine = true,                          -- Boolean: authored by current user
  current_working_copy = false,         -- Boolean: is working copy commit
  hidden = false,                       -- Boolean: is abandoned/hidden
  empty = false,                        -- Boolean: modifies no files
  parents = {"parent1_id", "parent2_id"}, -- List of parent commit IDs
  display_line = "..."                  -- Rendered line for display
}
```

**Log Data Structure:**
```lua
{
  commits = {[1] = commit1, [2] = commit2, ...},  -- Ordered list of commits
  template = "...",                                -- Template used for rendering
  repository_valid = true,                         -- Repository state
  error_message = nil                              -- Error details if any
}
```

### Dual-Pass Processing Flow

1. **Pass 1 - Graph Structure:**
   - Execute: `jj log --template 'commit_id ++ "\n"'`
   - Parse commit IDs and their positions in output
   - Extract graph characters associated with each commit
   - Build ordered list of commit IDs with graph information

2. **Pass 2 - Detailed Information:**
   - Execute: `jj log --template '<comprehensive_template>'` with null-byte separated fields
   - Parse all available commit information for each commit ID
   - Match commit details to graph positions from Pass 1
   - Combine graph structure with commit details

3. **Rendering:**
   - Generate display lines combining graph and commit info
   - Preserve ANSI color codes from original output
   - Handle buffer state transitions (modifiable/non-modifiable)

### Template Strategy

**Pass 1 Template (Minimal):**
```
commit_id ++ "\n"
```
Used to extract commit IDs and associate them with graph positions.

**Pass 2 Template (Comprehensive):**
```
commit_id ++ "\x00" ++
change_id ++ "\x00" ++
author.name() ++ "\x00" ++
author.email() ++ "\x00" ++
author.timestamp() ++ "\x00" ++
committer.name() ++ "\x00" ++
committer.email() ++ "\x00" ++
committer.timestamp() ++ "\x00" ++
bookmarks ++ "\x00" ++
tags ++ "\x00" ++
description ++ "\x00" ++
mine ++ "\x00" ++
current_working_copy ++ "\x00" ++
hidden ++ "\x00" ++
empty ++ "\x00" ++
parents.map(|p| p.commit_id()).join(" ") ++ "\n"
```
Extracts all available commit information using null bytes as field separators for reliable parsing.

**Display Rendering:**
After parsing, the structured data is rendered using jj's default visual style to match command-line output appearance while having access to all parsed fields for future features.

### Repository Detection

**Detection Strategy:**
1. Check for `.jj` directory in current working directory or parents
2. Validate jj command availability in PATH
3. Test repository access with `jj log --limit 1`

**Error States:**
- Not in jj repository: Display informational message
- jj command not found: Display error message
- Repository access issues: Display basic error message

### Buffer Management

**Buffer Lifecycle:**
1. Create or reuse existing log buffer
2. Set buffer as modifiable temporarily
3. Clear existing content
4. Render new log content with ANSI processing
5. Apply syntax highlighting and formatting
6. Set buffer as non-modifiable

**ANSI Color Processing:**
- Parse ANSI escape sequences from jj output
- Map to Neovim highlight groups
- Apply highlighting after content rendering
- Preserve original color scheme from jj
