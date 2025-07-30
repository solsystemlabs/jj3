# Spec Tasks

These are the tasks to be completed for the spec detailed in @.agent-os/specs/2025-07-30-cursor-line-highlighting/spec.md

> Created: 2025-07-30
> Status: Completed

## Tasks

- [x] 1. Fix full-width line highlighting for commit blocks
  - [x] 1.1 Define JJCommitBlock highlight group with background color
  - [x] 1.2 Replace nvim_buf_add_highlight with nvim_buf_set_extmark
  - [x] 1.3 Use line_hl_group and hl_eol parameters for full-width highlighting
  - [x] 1.4 Test that highlighting extends to window edge
  - [x] 1.5 Verify all lines in commit block are highlighted