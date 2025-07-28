# Spec Tasks

These are the tasks to be completed for the spec detailed in @.agent-os/specs/2025-07-28-auto-refresh/spec.md

> Created: 2025-07-28
> Status: In Progress (Tasks 1-3 Complete)

## Phase 1: Command-Triggered Refresh Tasks

- [x] 1. Implement manual refresh functionality
  - [x] 1.1 Write tests for manual refresh keybinding behavior
  - [x] 1.2 Add 'R' keybinding to jj log buffers using `vim.api.nvim_buf_set_keymap()`
  - [x] 1.3 Create `manual_refresh()` function that triggers complete log refresh
  - [x] 1.4 Add user feedback during refresh operations (status messages)
  - [x] 1.5 Ensure refresh clears existing buffer content before rendering new content
  - [x] 1.6 Verify manual refresh works with navigation system and preserves cursor position when possible

- [x] 2. Build command-triggered auto-refresh system
  - [x] 2.1 Write tests for auto-refresh behavior after jj commands
  - [x] 2.2 Create command execution hooks to detect when jj commands complete
  - [x] 2.3 Implement `auto_refresh_after_command()` function for seamless refresh
  - [x] 2.4 Add refresh triggering to existing jj command execution workflow
  - [x] 2.5 Ensure auto-refresh preserves navigation state and cursor position
  - [x] 2.6 Verify auto-refresh works with all supported jj commands (new, rebase, abandon, etc.)

- [x] 3. Implement command queuing during refresh operations
  - [x] 3.1 Write tests for command queuing behavior and race condition prevention
  - [x] 3.2 Create `command_queue` module to manage concurrent operations
  - [x] 3.3 Implement queue system that blocks new commands during active refresh
  - [x] 3.4 Add command execution after refresh completion
  - [x] 3.5 Provide user feedback for queued commands (show pending operations)
  - [x] 3.6 Verify queuing handles multiple rapid commands and error recovery

- [x] 4. Integrate refresh system with existing plugin architecture
  - [x] 4.1 Write integration tests ensuring refresh works with window management
  - [x] 4.2 Update existing log display functions to support refresh triggers
  - [x] 4.3 Ensure refresh system works with all window configurations (split, floating)
  - [x] 4.4 Add refresh state management and cleanup on window close
  - [x] 4.5 Verify refresh system doesn't interfere with existing navigation or highlighting
  - [x] 4.6 Test complete integration with existing plugin functionality

## Phase 2: Smart Caching System Tasks (Separate Commit)

- [ ] 5. Implement in-memory commit cache
  - [ ] 5.1 Write tests for cache operations (store, retrieve, invalidate)
  - [ ] 5.2 Create `commit_cache` module with Lua table-based storage
  - [ ] 5.3 Implement cache data structures for commit objects with metadata
  - [ ] 5.4 Add cache size limits and LRU eviction for memory management
  - [ ] 5.5 Create cache validation and corruption recovery mechanisms
  - [ ] 5.6 Verify cache performance meets target metrics (<200ms window open)

- [ ] 6. Build current commit detection and merging
  - [ ] 6.1 Write tests for current commit state detection and cache merging
  - [ ] 6.2 Implement `get_current_commit_state()` using `jj log -T <template> -r @ --no-graph`
  - [ ] 6.3 Create cache merging logic to update current commit data in cache
  - [ ] 6.4 Add fast-path rendering using cached data with current commit updates
  - [ ] 6.5 Implement fallback to full parsing when cache is invalid or missing
  - [ ] 6.6 Verify cache merging maintains data consistency and accuracy

- [ ] 7. Implement cache invalidation and lifecycle management
  - [ ] 7.1 Write tests for cache invalidation scenarios and cleanup behavior
  - [ ] 7.2 Create cache invalidation triggers for plugin command execution
  - [ ] 7.3 Implement window open/close cache lifecycle management
  - [ ] 7.4 Add cache cleanup and reset functionality for error recovery
  - [ ] 7.5 Create cache statistics and monitoring for performance tuning
  - [ ] 7.6 Verify cache invalidation prevents stale data and maintains accuracy

- [ ] 8. Optimize window opening performance with cache integration
  - [ ] 8.1 Write performance tests measuring window open times with cache
  - [ ] 8.2 Integrate cache system with existing window rendering pipeline
  - [ ] 8.3 Implement cache-first rendering with current commit state merging
  - [ ] 8.4 Add performance monitoring and metrics collection
  - [ ] 8.5 Optimize cache data structures and access patterns for speed
  - [ ] 8.6 Verify performance targets are met (>80% improvement for large repos)

## Phase 3: Background Optimizations (Future Enhancement)

- [ ] 9. Implement async refresh operations
  - [ ] 9.1 Write tests for non-blocking refresh behavior
  - [ ] 9.2 Create async refresh system using Neovim job control APIs
  - [ ] 9.3 Implement progressive loading for very large repositories
  - [ ] 9.4 Add background cache warming and preloading strategies
  - [ ] 9.5 Ensure async operations don't interfere with user interactions
  - [ ] 9.6 Verify async system improves perceived performance and responsiveness

## Integration and Polish Tasks

- [ ] 10. Comprehensive testing and error handling
  - [ ] 10.1 Write end-to-end tests covering complete refresh and cache workflows
  - [ ] 10.2 Add error recovery for all failure scenarios (command failures, cache corruption)
  - [ ] 10.3 Implement comprehensive logging and debugging support
  - [ ] 10.4 Add performance benchmarking and regression testing
  - [ ] 10.5 Create user documentation for refresh behavior and configuration
  - [ ] 10.6 Verify system handles edge cases gracefully (empty repos, network issues)

## Success Criteria

### Phase 1 Completion
- 'R' key manually refreshes log display in all window configurations
- All jj commands executed through plugin automatically trigger refresh
- Commands are properly queued during refresh operations with user feedback
- Refresh system integrates seamlessly with existing navigation and highlighting

### Phase 2 Completion  
- Log window opens in <200ms using cached data for large repositories
- Cache hit rate >90% for typical workflow sessions
- Memory usage remains under 50MB for repositories with 10,000+ commits
- Cache invalidation prevents stale data while maintaining performance
- Easy backout capability via separate commit structure