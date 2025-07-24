# Spec Tasks

These are the tasks to be completed for the spec detailed in @.agent-os/specs/2025-07-24-log-parsing-display/spec.md

> Created: 2025-07-24
> Status: Ready for Implementation

## Tasks

- [ ] 1. Create test repository with complex jj graph states
  - [ ] 1.1 Write tests for test repository creation and validation
  - [ ] 1.2 Create jj repository with various graph patterns (merges, branches, linear history)
  - [ ] 1.3 Add commits with different types (working copy, empty, hidden, bookmarks, tags)
  - [ ] 1.4 Create snapshot files of expected jj log output for testing
  - [ ] 1.5 Verify all test scenarios are covered and tests pass

- [ ] 2. Implement repository detection and validation
  - [ ] 2.1 Write tests for .jj directory detection and jj command availability
  - [ ] 2.2 Implement lua/jj/utils/repository.lua with detection functions
  - [ ] 2.3 Add error message handling for non-jj directories
  - [ ] 2.4 Verify all tests pass

- [ ] 3. Implement jj command execution framework
  - [ ] 3.1 Write tests for jj command execution with various templates and scenarios
  - [ ] 3.2 Implement lua/jj/log/executor.lua with async command execution
  - [ ] 3.3 Add comprehensive template definitions (minimal and comprehensive)
  - [ ] 3.4 Add error handling for command execution failures
  - [ ] 3.5 Verify all tests pass

- [ ] 4. Implement dual-pass log parsing
  - [ ] 4.1 Write tests for parsing both minimal and comprehensive jj output using test repository
  - [ ] 4.2 Implement lua/jj/log/parser.lua with commit ID extraction and graph parsing
  - [ ] 4.3 Add comprehensive commit information parsing with null-byte field separation
  - [ ] 4.4 Implement commit object creation and data structure population
  - [ ] 4.5 Add commit-to-graph position mapping logic
  - [ ] 4.6 Verify all tests pass against test repository snapshots

- [ ] 5. Implement ANSI color processing
  - [ ] 5.1 Write tests for ANSI escape sequence parsing and Neovim highlight mapping
  - [ ] 5.2 Implement lua/jj/utils/ansi.lua with color code processing
  - [ ] 5.3 Add Neovim highlight group creation and management
  - [ ] 5.4 Verify all tests pass

- [ ] 6. Implement buffer rendering engine
  - [ ] 6.1 Write tests for buffer content generation and ANSI color application
  - [ ] 6.2 Implement lua/jj/log/renderer.lua with display line generation
  - [ ] 6.3 Add graph character and commit info combination logic
  - [ ] 6.4 Implement ANSI color preservation and application to buffer
  - [ ] 6.5 Verify all tests pass

- [ ] 7. Implement window and buffer management
  - [ ] 7.1 Write tests for buffer creation, reuse, and modifiable state management
  - [ ] 7.2 Implement lua/jj/ui/window.lua with split window management
  - [ ] 7.3 Add buffer lifecycle management (create, update, make non-modifiable)
  - [ ] 7.4 Add configurable window positioning and sizing
  - [ ] 7.5 Verify all tests pass

- [ ] 8. Integrate log orchestration and connect to commands
  - [ ] 8.1 Write tests for complete log display workflow using test repository
  - [ ] 8.2 Implement lua/jj/log/init.lua with full orchestration logic
  - [ ] 8.3 Connect log display to existing :JJ command and <leader>jl keybinding
  - [ ] 8.4 Add repository detection integration with appropriate error messages
  - [ ] 8.5 Verify all tests pass and manual testing shows expected log display