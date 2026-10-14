# Field notes

Lessons measured while running this loop on a production codebase. Each one changed the design.

1. **A wrong tool name is dropped silently.** Agents listed `serena` and `context7` in `tools:`. Claude Code
   expects `mcp__serena` / `mcp__context7`, so the bare names granted nothing, and for weeks it looked as if
   subagents could not use MCP at all. A probe in a fresh session found the real cause.
2. **Unknown frontmatter fields do nothing.** Fields such as `allowed_commands`, `displayName` and `category`
   never restricted anything.
3. **Reviewers invent anchors.** Citations like `R-PIT-8.12` looked plausible but did not exist. The rule-ID
   validator rejected them with no model call.
4. **A smaller filter model deleted a true finding.** That is the one error the filter cannot recover from, so
   the filter runs on the strongest model. It stays cheap because each call sees one claim and one hunk.
5. **A suite that builds is not a suite that runs.** About 74 platform tests accumulated over several review rounds
   without executing once. When they finally ran, they exposed an out-of-bounds read and three guard tests that
   could never fail, because their fixtures violated the contract's own normalization.
6. **A test helper used `git checkout -- <file>` to undo a mutation** and erased another task's uncommitted
   work. A rule in a prompt had not prevented it, so the hook now blocks the command.
7. **`git diff <sha>..` was always empty** because the team does not commit between tasks. Delta reviews were
   checking nothing until the baseline became a `git stash create` snapshot.
8. **The hook blocked a harmless `grep "git restore"`.** Quoted text is now ignored unless the command re-enters
   a shell (`sh -c`, `eval`, `xargs`).
9. **Agents are slower than doing it yourself for small work.** The project owner stopped dispatching coder
   agents for routine fixes. The pipeline is for features, not one-line changes.
10. **Most agents in a catalog go unused.** Counting real dispatches over a month removed six of sixteen agents.
    Measure before you keep an agent.
