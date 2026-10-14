# Field notes

Lessons measured while running this loop on a production codebase. Each one changed the design.

1. **A wrong tool name is dropped silently.** Agents listed `serena` and `context7` in `tools:`. Claude Code
   expects `mcp__serena` / `mcp__context7`, so the bare names granted nothing, and for weeks it looked as if
   subagents could not use MCP at all. A probe in a fresh session found the real cause.
2. **Unknown frontmatter fields do nothing.** Fields such as `allowed_commands`, `displayName` and `category`
   never restricted anything.
3. **Reviewers invent anchors.** Citations like `R-PIT-8.12` looked plausible but did not exist. The rule-ID
   validator rejected them with no model call.
4. **A smaller filter model returned `NOT_REAL` for a true finding**, which would have dropped it. That is the one
   error the filter cannot recover from, so
   the filter runs on the strongest model. It stays cheap because each call sees one claim and one hunk.
5. **A suite that builds is not a suite that runs.** About 74 platform tests accumulated over several review rounds
   without executing once. When they finally ran, they exposed an out-of-bounds read and three guard tests that
   could never fail, because their fixtures violated the contract's own normalization.
6. **A test helper used `git checkout -- <file>` to undo a mutation** and wiped another task's uncommitted edits
   in that file. The agent noticed and rebuilt the file by hand, which was luck rather than a safeguard. A rule in a
   prompt had not prevented it, so the hook now blocks the command.
7. **The written delta-review baseline was wrong.** The workflow told reviewers to read `git diff <sha>..`, which
   compares commits and is always empty when the team does not commit between tasks. Orchestrators had been
   working around it with a `git stash create` snapshot, but that snapshot skips untracked files — 57 new files in
   one feature — so reviewers also need an explicit list of the files the fix created. The workflow now says both.
8. **The hook blocked a harmless `grep "git restore"`, then let `git "stash"` through.** Regexes over shell text
   fail in both directions. The hook now reads the command the way bash/zsh do, so quoted text is data unless the
   shell would run it (`sh -c`, `eval`, `$(…)`, a here-document fed to a shell).
9. **Agents are slower than doing it yourself for small work.** The project owner stopped dispatching coder
   agents for routine fixes. The pipeline is for features, not one-line changes.
10. **Most agents in a catalog go unused.** Counting real dispatches over a month removed six of sixteen agents.
    Measure before you keep an agent.
