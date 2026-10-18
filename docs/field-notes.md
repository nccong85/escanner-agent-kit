**English** · [Tiếng Việt](field-notes.vi.md) · [日本語](field-notes.ja.md)

# Field notes

Lessons from running this review loop on a real project.

1. **A wrong tool name is dropped silently.** Agents listed `serena` and `context7` in `tools:`. Claude Code
   expects `mcp__serena__*` / `mcp__context7__*`, so the bare names granted nothing, and subagents seemed unable to use
   MCP at all.
2. **Unknown frontmatter fields do nothing.** `allowed_commands`, `displayName` and `category` never restricted
   anything. A real restriction needs a mechanism Claude Code supports.
3. **Reviewers invent anchors.** Citations like `R-PIT-8.12` looked plausible but did not exist. The rule-ID
   validator rejected them with no model call.
4. **A suite that builds is not a suite that runs.** 74 C++ test cases reported a pass without ever having run.
   When they actually ran, they exposed an out-of-bounds read and guard tests that could never fail, because
   their fixtures broke the contract's own normalization.
5. **A test helper used `git checkout -- <file>` to undo a mutation** and wiped another task's uncommitted edits
   in that file. A prompt rule had not prevented it, so the hook now blocks the command.
6. **The written delta-review baseline was wrong.** The workflow told reviewers to read `git diff <sha>..`, which
   compares commits and is always empty when the team does not commit between tasks. Orchestrators had worked
   around it with a `git stash create` snapshot, but that skips untracked files (57 new files in one feature), so
   reviewers also need an explicit list of files the fix created. The workflow now says both.
7. **The hook blocked a harmless `grep "git restore"`, then let `git "stash"` through.** Regexes over shell text
   fail both ways. The hook now reads the command the way bash/zsh do, so quoted text is data unless the shell
   would run it (`sh -c`, `eval`, `$(…)`, a here-document fed to a shell).
8. **For small work, doing it yourself is faster.** Stop dispatching coder agents for routine fixes. The pipeline
   is for features, not one-line changes.
