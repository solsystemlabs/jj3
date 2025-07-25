# Spec Tasks

These are the tasks to be completed for the spec detailed in @.agent-os/specs/2025-07-24-log-parsing-display/spec.md

> Created: 2025-07-24
> Status: Ready for Implementation

## Tasks

- [x] 1. Create test repository with complex jj graph states
  - [x] 1.1 Write tests for test repository creation and validation
  - [x] 1.2 Create jj repository with various graph patterns (merges, branches, linear history)
  - [x] 1.3 Add commits with different types (working copy, empty, hidden, bookmarks, tags)
  - [x] 1.4 Create snapshot files of expected jj log output for testing
  - [x] 1.5 Verify all test scenarios are covered and tests pass

- [x] 2. Implement repository detection and validation
  - [x] 2.1 Write tests for .jj directory detection and jj command availability
  - [x] 2.2 Implement lua/jj/utils/repository.lua with detection functions
  - [x] 2.3 Add error message handling for non-jj directories
  - [x] 2.4 Verify all tests pass

- [x] 3. Implement jj command execution framework
  - [x] 3.1 Write tests for jj command execution with various templates and scenarios
  - [x] 3.2 Implement lua/jj/log/executor.lua with async command execution
  - [x] 3.3 Add comprehensive template definitions (minimal and comprehensive)
  - [x] 3.4 Add error handling for command execution failures
  - [x] 3.5 Verify all tests pass

- [x] 4. Implement dual-pass log parsing
  - [x] 4.1 Write tests for parsing both minimal and comprehensive jj output using test repository
  - [x] 4.2 Implement lua/jj/log/parser.lua with commit ID extraction and graph parsing
  - [x] 4.3 Add comprehensive commit information parsing with null-byte field separation
  - [x] 4.4 Implement commit object creation and data structure population
  - [x] 4.5 Add commit-to-graph position mapping logic
  - [x] 4.6 Verify all tests pass against test repository snapshots

- [x] 5. Implement ANSI color processing
  - [x] 5.1 Write tests for ANSI escape sequence parsing and Neovim highlight mapping
  - [x] 5.2 Implement lua/jj/utils/ansi.lua with color code processing
  - [x] 5.3 Add Neovim highlight group creation and management
  - [x] 5.4 Verify all tests pass

- [x] 6. Implement buffer rendering engine
  - [x] 6.1 Write tests for buffer content generation and ANSI color application
  - [x] 6.2 Implement lua/jj/log/renderer.lua with display line generation
  - [x] 6.3 Add graph character and commit info combination logic
  - [x] 6.4 Implement ANSI color preservation and application to buffer
  - [x] 6.5 Verify all tests pass

- [x] 7. Implement window and buffer management
  - [x] 7.1 Write tests for buffer creation, reuse, and modifiable state management
  - [x] 7.2 Implement lua/jj/ui/window.lua with split window management
  - [x] 7.3 Add buffer lifecycle management (create, update, make non-modifiable)
  - [x] 7.4 Add configurable window positioning and sizing
  - [x] 7.5 Verify all tests pass

- [x] 8. Integrate log orchestration and connect to commands
  - [x] 8.1 Write tests for complete log display workflow using test repository
  - [x] 8.2 Implement lua/jj/log/init.lua with full orchestration logic
  - [x] 8.3 Connect log display to existing :JJ command and <leader>jl keybinding
  - [x] 8.4 Add repository detection integration with appropriate error messages
  - [x] 8.5 Verify all tests pass and manual testing shows expected log display