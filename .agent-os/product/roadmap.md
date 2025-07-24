# Product Roadmap

> Last Updated: 2025-07-24
> Version: 1.0.0
> Status: Planning

## Phase 1: Core MVP Functionality (3-4 weeks)

**Goal:** Create a working Neovim plugin that displays jj log output in a dedicated window
**Success Criteria:** Users can open the plugin, see their jj log, and perform basic navigation

### Must-Have Features

- [ ] Plugin initialization and setup - Basic plugin structure with proper Neovim integration `M`
- [ ] jj log parsing and display - Parse `jj log --graph` output and display in buffer `L`
- [ ] Basic window management - Create and manage floating/split window for log display `M`
- [ ] Buffer navigation - Vim-style movement (j/k, gg/G) within log buffer `S`
- [ ] Auto-refresh on filesystem changes - Detect repo changes and update display `M`

### Should-Have Features

- [ ] Configurable window positioning - Allow users to customize window placement `S`
- [ ] Basic error handling - Handle cases where jj is not available or repo is invalid `M`

### Dependencies

- Neovim 0.11+ installed
- jujutsu (jj) available in PATH
- Basic understanding of jj repository structure

## Phase 2: Extensible Command Framework (2-3 weeks)

**Goal:** Build a flexible system for executing jj operations with user-customizable commands and keybindings
**Success Criteria:** Users can execute basic jj operations and easily add their own custom command/flag combinations

### Must-Have Features

- [ ] Command execution framework - Generic system for running jj commands with arguments `L`
- [ ] Keybinding registration system - Allow users to register custom keymaps for any jj operation `M`
- [ ] Default command set - Provide sensible defaults for common operations (new, rebase, squash, edit, abandon) `M`
- [ ] Operation feedback system - Display success/error messages with command output `S`
- [ ] Context-aware commands - Pass selected commit/change IDs to jj operations `M`

### Should-Have Features

- [ ] Command menu system - Interactive menu for discovering and executing commands `L`
- [ ] Argument prompting - Allow commands to prompt for additional arguments when needed `M`

### Dependencies

- Phase 1 completion
- Stable subprocess execution for jj commands
- Error handling framework from Phase 1

## Phase 3: Bookmark Management (1-2 weeks)

**Goal:** Provide intuitive bookmark creation, deletion, and navigation with extensible bookmark operations
**Success Criteria:** Users can manage all bookmark operations and customize bookmark-related commands

### Must-Have Features

- [ ] Bookmark visualization - Show bookmarks in log display with clear indicators `M`
- [ ] Default bookmark operations - Create, delete, and navigate bookmarks `M`
- [ ] Extensible bookmark commands - Allow users to add custom bookmark operations `S`

### Should-Have Features

- [ ] Remote bookmark handling - Display and manage remote bookmarks `L`
- [ ] Bookmark command templates - Pre-configured templates for common bookmark workflows `M`

### Dependencies

- Phase 2 completion
- Visual indicators system
- Command framework from Phase 2

## Phase 4: Enhanced Visualization and Command Discoverability (2-3 weeks)

**Goal:** Improve visual representation and make the extensible command system discoverable
**Success Criteria:** Users have a rich view of repository state and can easily discover/customize available commands

### Must-Have Features

- [ ] Syntax highlighting - Proper highlighting for commits, bookmarks, and operations `M`
- [ ] Commit details popup - Show detailed commit info on demand `M`
- [ ] Command palette/menu - Searchable interface for all available commands `L`
- [ ] Status indicators - Visual cues for conflict states, working copy, etc. `M`
- [ ] Keybinding help system - Display current keybindings and allow customization `M`

### Should-Have Features

- [ ] Graph drawing improvements - Better ASCII/Unicode graph rendering `L`
- [ ] Customizable colors - User-configurable color schemes `M`
- [ ] Command history - Track and repeat recent commands `S`

### Dependencies

- Phase 3 completion
- Neovim highlighting system understanding
- Menu/popup system implementation

## Phase 5: Advanced Customization and Polish (2-3 weeks)

**Goal:** Complete the extensible architecture and ensure production readiness
**Success Criteria:** Plugin is highly customizable, stable, well-documented, and handles edge cases gracefully

### Must-Have Features

- [ ] Comprehensive configuration system - Full user control over commands, keybindings, and display options `L`
- [ ] Command configuration DSL - Simple way for users to define custom jj operations with flags `L`
- [ ] Documentation and examples - Complete help docs, README, and customization examples `M`
- [ ] Error recovery - Robust handling of all error conditions `L`

### Should-Have Features

- [ ] Performance optimization - Efficient handling of large repositories `L`
- [ ] Plugin integration - Work well with other Neovim plugins `M`
- [ ] Command sharing - Allow users to share command configurations `M`
- [ ] Advanced command features - Support for multi-step operations, conditionals, and workflows `XL`

### Dependencies

- Phase 4 completion
- User feedback from earlier phases
- Performance profiling tools
- Documentation framework

## Extensibility Design Principles

### Command Customization
- Users should be able to define any jj command with any combination of flags
- Command definitions should support argument substitution (commit IDs, user input, etc.)
- Default commands serve as examples and starting points for customization

### Keybinding Flexibility
- All keybindings should be user-configurable
- Support for mode-specific keybindings (normal, visual, etc.)
- No hardcoded keybindings that can't be overridden

### Menu System Architecture
- Commands organized in customizable categories
- Support for nested menus and command groups
- Quick access patterns for frequently used operations

## Effort Scale Reference

- **XS:** 1 day
- **S:** 2-3 days  
- **M:** 1 week
- **L:** 2 weeks
- **XL:** 3+ weeks