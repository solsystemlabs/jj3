# Technical Stack

> Last Updated: 2025-07-24
> Version: 1.0.0

## Core Technology Choices

### Application Framework
- **Neovim Plugin Architecture** (Neovim 0.11+)
- Plugin manager compatibility: lazy.nvim, packer.nvim, vim-plug

### Programming Language
- **Lua 5.1** (Neovim's embedded Lua runtime)
- LuaJIT compatibility for performance-critical operations

### JavaScript Framework
- **N/A** - Pure Lua implementation

### Import Strategy
- **Lua require() system** - Native Lua module system
- Neovim's plugin loading mechanism

### CSS Framework
- **N/A** - Terminal-based UI using Neovim's built-in highlighting

### UI Component Library
- **Neovim built-in UI APIs**
  - `vim.api.nvim_open_win()` for floating windows
  - `vim.api.nvim_buf_set_lines()` for content rendering
  - `vim.api.nvim_buf_set_keymap()` for keybindings
  - `vim.highlight` for syntax highlighting

### Fonts Provider
- **User's terminal/Neovim font configuration**
- Unicode support for drawing characters (├─ └─ etc.)

### Icon Library
- **Unicode characters and Nerd Fonts**
- Fallback to ASCII characters for compatibility

## Infrastructure Choices

### Application Hosting
- **User's local Neovim installation**
- Distributed via plugin managers (GitHub releases)

### Database System
- **N/A** - Stateless plugin, relies on jj's filesystem state
- Temporary caching in Lua tables as needed

### Database Hosting
- **N/A** - No persistent storage required

### Asset Hosting
- **GitHub Releases** for plugin distribution
- **GitHub Repository** for source code and documentation

### Deployment Solution
- **Plugin Manager Installation**
  - lazy.nvim: `{ 'username/jj3.nvim' }`
  - Manual installation to `~/.config/nvim/pack/*/start/`

### Code Repository URL
- **To be determined** - Will be created on GitHub under user's account

## Development Dependencies

### Runtime Dependencies
- **jujutsu (jj)** - Version control system (minimum version 0.8.0)
- **Neovim** - Version 0.11 or later
- **Unix-like OS** - For subprocess execution (Linux, macOS)

### Development Dependencies
- **luacheck** - Lua linting
- **stylua** - Lua code formatting
- **busted** - Lua testing framework (optional)

### External Commands
- **jj** - All operations executed via subprocess calls to jj CLI
- **git** - For fallback operations if needed (optional)

## Plugin Architecture

### Module Structure
```
lua/
├── jj3/
│   ├── init.lua           # Main plugin entry point
│   ├── config.lua         # Configuration management
│   ├── log.lua           # jj log parsing and display
│   ├── operations.lua    # jj command execution
│   ├── ui.lua            # UI management and windows
│   ├── keymaps.lua       # Keybinding management
│   └── utils.lua         # Utility functions
```

### Integration Points
- **Neovim Events** - `BufEnter`, `DirChanged` for auto-refresh
- **Job Control** - `vim.fn.jobstart()` for async jj command execution
- **User Commands** - `:JJ` command registration
- **Keymaps** - Buffer-local and global keybinding registration