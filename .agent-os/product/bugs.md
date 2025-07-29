
- [ ] We should not be extracting commit ids using regexes, we already have a data structure tracking commits. Commits in this data structure should have the line numbers associated with it stored so we can look up commits in this data structure by line number.
- [ ] The selection menu appears on the wrong side of the log window's left side: it covers the log window
- [ ] Selections don't work. The error "No commit ID found on current line" appears when trying to select, and the Enter key doesn't seem to work.
- [ ] Quick commands should never show the menu. They should operate on the commit currently under the cursor and execute their command immediately.
- [ ] The describe command freezes the UI because in the background it tries to open an editor. Describe should only prompt the user for a description using a vim input.
- [ ] Fix cursor highlighting to highlight entire lines
