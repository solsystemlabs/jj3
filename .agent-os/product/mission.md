# Product Mission

> Last Updated: 2025-07-24
> Version: 1.0.0

## Pitch

jj3 is a Neovim plugin that helps jujutsu users visualize and interact with their version control workflow by providing an interactive log graph interface directly within their editor.

## Users

### Primary Customers

- **Neovim Users with jj**: Developers who use Neovim as their primary editor and jujutsu for version control
- **Version Control Power Users**: Developers who prefer visual interfaces for complex git/jj operations

### User Personas

**Developer using jj and Neovim** (25-45 years old)
- **Role:** Software Engineer, DevOps Engineer, or Technical Lead
- **Context:** Works on codebases managed with jujutsu version control system
- **Pain Points:** Switching between terminal and editor for version control operations, difficulty visualizing complex branching structures, inefficient workflow for common jj operations
- **Goals:** Streamline version control workflow, maintain focus within editor environment, quickly understand repository state

## The Problem

### Context Switching Overhead

Developers constantly switch between their editor and terminal to perform version control operations, breaking their flow and reducing productivity. This is especially problematic with jujutsu's powerful but complex command-line interface.

**Our Solution:** Integrate jj operations directly into the Neovim environment with visual feedback.

### Poor Visualization of Repository State

Understanding complex branching and change relationships in jujutsu requires mental mapping of text-based log output, making it difficult to grasp the overall repository structure.

**Our Solution:** Provide an interactive visual representation of the jj log graph with real-time updates.

### Inefficient Bookmark Management

Managing bookmarks in jj through CLI commands is cumbersome and doesn't provide good visibility into bookmark relationships and status.

**Our Solution:** Offer intuitive bookmark management through keybindings and visual indicators.

## Differentiators

### Native Neovim Integration

Unlike external GUI tools or web interfaces, we provide seamless integration within the user's existing Neovim workflow. This results in zero context switching and consistent keybinding patterns.

### Real-time State Synchronization

Unlike static visualizations, we maintain an always-accurate view of the repository state by monitoring filesystem changes and jj operations. This results in trustworthy information for decision-making.

### jj-First Design

Unlike git-focused tools adapted for jj, we design specifically for jujutsu's unique concepts and workflows. This results in intuitive operations that match jj's mental model.

## Key Features

### Core Features

- **Interactive Log Graph:** Visual representation of jj log with navigation and selection capabilities
- **In-Editor Operations:** Execute jj commands directly from the plugin interface without leaving Neovim
- **Real-time Updates:** Automatically refresh the log view when repository state changes
- **Keyboard-driven Interface:** Vim-style keybindings for all operations

### Collaboration Features

- **Bookmark Management:** Visual bookmark creation, deletion, and navigation with clear status indicators
- **Change Inspection:** View detailed information about commits, changes, and relationships
- **Operation Feedback:** Clear success/error messages for all jj operations performed through the plugin
- **Customizable Layout:** Resizable windows and configurable positioning to fit different workflow preferences