# Tests Specification

This is the tests coverage details for the spec detailed in @.agent-os/specs/2025-07-24-log-parsing-display/spec.md

> Created: 2025-07-24
> Version: 1.0.0

## Test Coverage

### Unit Tests

**lua/jj/log/executor.lua**
- jj command execution with various templates
- Repository detection and validation
- Error handling for missing jj command
- Command output capture and processing

**lua/jj/log/parser.lua**
- Commit ID extraction from log output
- Graph character parsing and association
- Dual-pass data combination and validation
- Template output parsing for various formats

**lua/jj/log/renderer.lua**
- ANSI color code processing and conversion
- Buffer content generation and formatting
- Graph line rendering with proper alignment
- Buffer state management (modifiable/non-modifiable)

**lua/jj/ui/window.lua**
- Buffer creation and reuse logic
- Window positioning and sizing
- Split window configuration management

**lua/jj/utils/ansi.lua**
- ANSI escape sequence parsing
- Color code mapping to Neovim highlights
- Color preservation and rendering

**lua/jj/utils/repository.lua**
- .jj directory detection
- Repository validity checking
- Working directory context handling

### Integration Tests

**Log Display Pipeline**
- End-to-end log parsing and display workflow
- Dual-pass processing with real jj repository
- Template application and rendering integration
- Buffer management throughout complete cycle

**Default Template Processing**
- Default jj log format parsing and rendering
- Proper handling of jj's built-in log formatting

**Repository Context Handling**
- Log display in valid jj repository
- Error message display in non-jj directory
- Behavior when jj command is unavailable
- Repository detection across different working directories

### Feature Tests

**Log Visualization**
- Visual comparison of plugin output vs command line jj log
- ANSI color rendering accuracy
- Graph character positioning and alignment
- Commit information completeness and formatting

**Default Log Display**
- Log renders with same visual fidelity as command line
- Default jj log format displays correctly
- All commit information is present and properly formatted

**Buffer Behavior**
- Log buffer is non-modifiable for user interaction
- Buffer content updates correctly on refresh
- Buffer reuse prevents memory leaks
- Multiple log windows handle buffer sharing correctly

### Mocking Requirements

**jj Command Execution**
- Mock jj log output for consistent testing
- Mock repository detection responses
- Mock various error conditions (command not found, invalid repo)
- Mock ANSI color output for rendering tests

**Neovim APIs**
- Mock buffer creation and management functions
- Mock job execution for subprocess calls
- Mock highlight group application
- Mock window and split management

**File System Operations**
- Mock .jj directory detection
- Mock working directory changes for repository context

### Performance Tests

**Large Repository Handling**
- Test parsing performance with 1000+ commits
- Memory usage monitoring during log processing
- Buffer rendering time for complex graphs
- Template processing efficiency with detailed formats

**Default Template Processing Performance**
- Default log format parsing speed
- Built-in template processing efficiency