
- [ ] We should not be extracting commit ids using regexes, we already have a data structure tracking commits. Commits in this data structure should have the line numbers associated with it stored so we can look up commits in this data structure by line number.
- [ ] Quick commands should never show the menu. They should operate on the commit currently under the cursor and execute their command immediately.
- [ ] The describe command freezes the UI because in the background it tries to open an editor. Describe should only prompt the user for a description using a vim input.
  - Spec created: @.agent-os/specs/2025-07-30-describe-command-fix/spec.md
- [ ] Fix cursor highlighting to highlight entire lines
- [ ] Make log window always appear on the right-most side of neovim
  - Spec created: @.agent-os/specs/2025-07-30-log-window-positioning/spec.md
