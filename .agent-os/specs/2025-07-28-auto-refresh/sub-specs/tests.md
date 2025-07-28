# Tests Specification

This is the tests coverage details for the spec detailed in @.agent-os/specs/2025-07-28-auto-refresh/spec.md

> Created: 2025-07-28
> Version: 1.0.0

## Test Coverage

### Phase 1: Command-Triggered Refresh Tests

#### Unit Tests - Manual Refresh

**Refresh Module**
- `manual_refresh()` triggers complete log refresh and clears existing buffer content
- `setup_refresh_keymaps()` registers 'R' key for manual refresh in jj log buffers only
- Manual refresh preserves cursor position when possible after content update
- Refresh operations provide user feedback through status messages
- Manual refresh works correctly with empty repositories and error conditions
- 'R' keybinding is only active in jj log buffers, not other buffer types

**Command Queue Module**
- `is_refresh_active()` correctly reports refresh operation state
- `queue_command()` properly queues commands during active refresh operations
- `execute_queued_commands()` processes all queued commands after refresh completion
- Command queue handles multiple rapid commands without losing operations
- Queue system provides user feedback for pending operations
- Error in queued command doesn't break queue processing for subsequent commands

#### Unit Tests - Auto-Refresh

**Command Hook Integration**
- `register_command_hooks()` properly integrates with existing jj command execution
- `auto_refresh_after_command()` triggers refresh only after successful command completion
- Auto-refresh preserves navigation state and cursor position during refresh
- Hook system works with all supported jj commands (new, rebase, abandon, squash, edit)
- Failed commands don't trigger auto-refresh to avoid showing inconsistent state
- Command hooks can be enabled/disabled without affecting other plugin functionality

#### Integration Tests - Phase 1

**Complete Refresh Workflow**
- User can manually refresh log display using 'R' key in any window configuration
- Auto-refresh triggers seamlessly after jj commands without user intervention
- Commands are queued and executed properly during refresh operations
- Refresh system works with existing navigation and highlighting functionality
- Multiple rapid commands are handled gracefully with proper queuing
- Refresh preserves window state and user context when possible

**Buffer State Management**
- Refresh operations maintain cursor position when log structure is unchanged
- Buffer content updates don't interfere with active navigation or selection
- Window configuration (split, floating) is preserved through refresh operations
- Refresh system properly cleans up state when window is closed during refresh

### Phase 2: Smart Caching System Tests

#### Unit Tests - Cache Operations

**Cache Module**
- `cache_commit()` stores commit objects with proper indexing by commit_id
- `get_cached_commit()` retrieves commit data with O(1) lookup performance
- `invalidate_cache()` properly clears cache entries and updates metadata
- `cache_size_limit()` enforces memory limits with LRU eviction
- Cache validation detects corrupted data and triggers fallback to full parsing
- Cache statistics tracking provides accurate metrics for performance monitoring

**Current Commit Detection**
- `get_current_commit_state()` executes `jj log -T <template> -r @` with proper template
- Current commit detection handles working copy changes and conflict states
- `merge_current_commit()` updates cache with current working copy data
- Current commit queries fail gracefully when repository is in invalid state
- Template parsing works correctly for current commit with all required fields

#### Unit Tests - Cache Integration

**Performance Optimization**
- `render_from_cache()` achieves <200ms window open time for large repositories
- Cache hit rate >90% for typical workflow sessions with proper cache management
- Memory usage stays under 50MB for repositories with 10,000+ commits
- Cache-first rendering maintains data accuracy and consistency
- Fallback to full parsing works seamlessly when cache is invalid or missing

#### Integration Tests - Phase 2

**Complete Caching Workflow**
- Window opens instantly using cached data merged with current commit state
- Cache invalidation triggers properly when plugin commands modify repository
- Cache lifecycle management works correctly with window open/close events
- Performance targets are met consistently across different repository sizes
- Cache corruption recovery doesn't lose user data or cause plugin crashes

**Error Recovery and Edge Cases**  
- Cache system handles repository state changes gracefully
- Memory pressure triggers proper cache eviction without data corruption
- Network issues or jj command failures don't corrupt cache state
- Cache system works correctly with concurrent operations and race conditions

### Performance Tests

#### Benchmarking Requirements

**Refresh Performance**
- Manual refresh completes within 2 seconds for repositories with 1000+ commits
- Auto-refresh after commands completes within 1 second for typical repositories
- Command queuing introduces <100ms latency for typical command execution
- Cache-enabled window opening achieves >80% performance improvement

**Memory and Resource Usage**
- Cache memory usage scales linearly with repository size up to configured limits
- Refresh operations don't cause memory leaks or resource exhaustion
- Long-running sessions maintain stable memory usage with proper cache cleanup
- Concurrent refresh operations don't cause excessive resource contention

### Mocking Requirements

#### Phase 1 Mocking

- **Command Execution** - Mock jj command execution for testing refresh triggers
- **User Interface** - Mock status messages and user feedback for refresh operations
- **Timer/Async** - Mock timing functions for testing command queuing and delays
- **Buffer Management** - Mock buffer creation and content update for refresh testing

#### Phase 2 Mocking

- **System Resources** - Mock memory usage and system performance for cache testing
- **Repository State** - Mock jj repository state changes for cache invalidation testing
- **Template Execution** - Mock `jj log -T <template> -r @` for current commit detection
- **Cache Storage** - Mock Lua table operations for testing cache data structures

### Test Data Requirements

#### Sample Repositories

**Small Repository** (10-50 commits)
- Linear history for basic refresh testing
- Simple branch structure for cache validation
- Recent commits with various metadata for parsing tests

**Medium Repository** (100-500 commits)  
- Complex branching with merges for performance testing
- Mixed commit types (normal, merge, empty) for cache coverage
- Working copy changes for current commit detection testing

**Large Repository** (1000+ commits)
- Performance benchmark testing for cache effectiveness
- Memory usage validation for cache size limits
- Stress testing for command queuing under load

#### Edge Case Scenarios

- Empty repository (no commits)
- Repository with conflicts or invalid states
- Repository with very long commit messages or unusual characters
- Rapid command execution scenarios for queue testing
- Network interruption during jj command execution
- Plugin reload/restart scenarios with active cache

### Success Metrics

#### Phase 1 Success Criteria
- All manual refresh tests pass with 100% coverage
- Auto-refresh system achieves 95% reliability in command detection
- Command queuing prevents race conditions in 100% of test scenarios
- Integration tests pass with existing navigation and window management

#### Phase 2 Success Criteria
- Cache system achieves target performance improvements (>80%) in benchmark tests
- Cache hit rate >90% in realistic usage scenarios
- Memory usage stays within limits (50MB for 10k+ commits) across all test cases
- Error recovery tests pass with no data loss or corruption scenarios