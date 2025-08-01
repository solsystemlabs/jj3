# Spec Requirements Document

> Spec: Keybind Help Section
> Created: 2025-08-01
> Status: Planning

## Overview

Add a keybind help section at the bottom of the log window that displays available keybindings from both default commands and user-configured commands, improving discoverability and user experience within the plugin interface.

## User Stories

### Keybind Discovery

As a jj3 plugin user, I want to see available keybindings displayed in the log window, so that I can discover and use commands without memorizing or looking up documentation.

The help section should show at the bottom of the log window, displaying key combinations and their corresponding command descriptions. It should merge both default plugin keybindings and any user-configured custom keybindings, updating dynamically when configuration changes.

### Command Reference

As a power user with custom keybindings, I want the help section to show my personalized keybind configuration, so that I can reference my custom commands without switching contexts or checking configuration files.

The display should prioritize user-configured keybindings over defaults when conflicts exist, and clearly indicate which commands are custom versus default.

## Spec Scope

1. **Help Section Rendering** - Display keybind information at bottom of log window with clear formatting
2. **Keybind Merging** - Combine default_commands and user-configured keybinds with proper precedence
3. **Dynamic Updates** - Refresh help section when keybind configuration changes
4. **Space Management** - Automatically adjust log content area to accommodate help section
5. **Toggle Functionality** - Allow users to show/hide the help section as needed

## Out of Scope

- Keybind editing interface within the plugin
- Full command palette or menu system
- Interactive help system with command execution
- Detailed command documentation beyond key + description

## Expected Deliverable

1. Log window displays keybind help section at bottom with current available commands
2. Help section correctly merges and displays both default and user-configured keybindings
3. Users can toggle the help section visibility and log content adjusts appropriately

## Spec Documentation

- Tasks: @.agent-os/specs/2025-08-01-keybind-help-section/tasks.md
- Technical Specification: @.agent-os/specs/2025-08-01-keybind-help-section/sub-specs/technical-spec.md
- Tests Specification: @.agent-os/specs/2025-08-01-keybind-help-section/sub-specs/tests.md