# Technical Specification

This is the technical specification for the spec detailed in @.agent-os/specs/2025-07-28-auto-refresh/spec.md

> Created: 2025-07-28
> Version: 1.0.0

## Technical Requirements

### Phase 1: Command-Triggered Refresh
- **Manual Refresh Keybinding** - Use `vim.api.nvim_buf_set_keymap()` to bind 'R' key in jj log buffers only
- **Command Hook Integration** - Hook into existing jj command execution to trigger automatic refresh
- **Command Queuing System** - Use Lua coroutines or callback queues to prevent concurrent operations
- **Refresh State Management** - Track refresh operations and provide user feedback via status messages
- **Non-blocking UI** - Ensure refresh operations don't freeze the interface

### Phase 2: Smart Caching System  
- **In-Memory Cache** - Use Lua tables to store parsed commit objects with commit_id as key
- **Current Commit Detection** - Execute `jj log -T <comprehensive_template> -r @` for working copy state
- **Cache Merging** - Update cached commit data with current working copy information
- **Cache Invalidation** - Clear/update cache entries when plugin commands modify repository
- **Memory Management** - Implement cache size limits and cleanup for large repositories

## Approach Options

**Option A: Filesystem Watching for External Changes**
- Pros: Detects all repository changes, complete coverage of external modifications
- Cons: Complex implementation, resource intensive, platform-specific APIs, race conditions
- **Rejected**: Too complex for the performance benefit gained

**Option B: Command-Only Refresh with Smart Caching** (Selected)
- Pros: Simple and reliable, covers 95% of use cases, easy to implement and debug
- Cons: Doesn't detect external jj commands, relies on plugin usage patterns
- **Rationale**: Most jj operations happen through the plugin, external changes are rare

**Option C: Periodic Polling** 
- Pros: Simple implementation, catches external changes eventually
- Cons: Wasteful of resources, introduces unnecessary delays, still misses rapid changes
- **Rejected**: Poor resource usage for minimal benefit

## External Dependencies

- **jujutsu (jj) CLI** - Required for current commit state queries (`jj log -r @`)
- **Neovim 0.11+** - Required for buffer-local keymaps and job control APIs
- **Existing Plugin Components** - Integration with log parser, window manager, and command executor

## Implementation Details

### Cache Architecture
```lua
-- In-memory cache structure
local commit_cache = {
  ["abc123def"] = {
    commit_id = "abc123def",
    change_id = "xyz789",
    author_name = "user",
    description = "Fix bug in navigation",
    timestamp = "2025-07-28T10:30:00",
    -- ... other commit fields
  },
  -- ... more commits
}

-- Cache metadata
local cache_meta = {
  last_updated = os.time(),
  total_commits = 150,
  current_commit_id = "abc123def"
}
```

### Command Queuing System
```lua
-- Command queue for handling concurrent operations
local command_queue = {
  active_refresh = false,
  pending_commands = {},
  
  execute_command = function(cmd)
    if active_refresh then
      table.insert(pending_commands, cmd)
      return "queued"
    else
      return execute_immediately(cmd)
    end
  end
}
```

### Current Commit Detection
```lua
-- Fast current commit check using minimal template
local function get_current_commit_state()
  local template = 'commit_id ++ "\\x00" ++ change_id ++ "\\x00" ++ ' ..
                  'description.first_line() ++ "\\x00" ++ author.name()'
  
  local result = executor.execute_with_template("log -r @ --no-graph", template)
  if result.success then
    return parser.parse_single_commit(result.output)
  end
  return nil
end
```

### Cache Integration Points
```lua
-- Window rendering with cache optimization
local function render_log_with_cache()
  local current_commit = get_current_commit_state()
  
  if current_commit and commit_cache[current_commit.commit_id] then
    -- Update current commit in cache
    commit_cache[current_commit.commit_id] = current_commit
    
    -- Render from cache (fast path)
    return render_from_cache(commit_cache)
  else
    -- Cache miss - fall back to full parsing
    return render_with_full_parse()
  end
end
```

### Performance Optimizations

**Memory Management**
- Limit cache to 1000 most recent commits
- Implement LRU eviction for memory pressure
- Clear cache on plugin reload

**Refresh Optimization**
- Skip refresh if no repository changes detected
- Batch multiple rapid commands into single refresh
- Use incremental parsing when possible

**Error Handling**
- Graceful fallback to full parse if cache corrupted
- Retry logic for transient jj command failures
- Clear cache and restart on persistent errors

## Integration Architecture

### Phase 1: Refresh Framework
```
Command Execution → Command Hook → Trigger Refresh → Update Display
                     ↓
                  Queue System → Execute After Refresh
```

### Phase 2: Caching Layer
```
Window Open → Check Cache → Current Commit Query → Merge Data → Fast Render
     ↓              ↓              ↓                    ↓
 Cache Miss → Full Parse → Update Cache → Store Results
```

## Testing Strategy

- **Unit Tests**: Cache operations, command queuing, current commit detection
- **Integration Tests**: Full refresh cycle, cache invalidation, error recovery
- **Performance Tests**: Cache hit rates, render times, memory usage
- **Edge Cases**: Concurrent commands, cache corruption, network failures

## Risk Mitigation

**Cache Corruption**: Implement cache validation and automatic fallback to full parsing
**Memory Leaks**: Set strict cache size limits and implement cleanup routines  
**Race Conditions**: Use proper locking and queuing for command operations
**Performance Regression**: Easy backout via separate commit for caching layer