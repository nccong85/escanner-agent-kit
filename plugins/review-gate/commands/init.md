---
description: Create the project files review-gate reads (.claude/review-gate/) from the plugin templates, moving a pre-2.0 .claude/review-loop/ folder, without overwriting existing ones.
---

Set up `.claude/review-gate/` in the current project.

0. **Move a pre-2.0 folder first.** Before 2.0.0 the plugin was `review-loop` and its files lived in
   `.claude/review-loop/`. If that folder exists and `.claude/review-gate/` does not, move it (`git mv` when it is
   tracked, else `mv`); never copy, so there is one source. In the moved files that are regular files (not
   symlinks), rewrite the agent prefixes `review-loop:` → `review-gate:` and `flutter-native-agents:` →
   `flutter-native:`. In the *Legacy names* table rewrite only the last column (the name to dispatch now); the
   columns before it are old names on purpose. A
   symlinked file belongs to the project's own docs: do not edit it, list the lines that still use an old prefix.
   If both folders exist, touch neither: report the conflict and stop. Then go on with step 1, which only adds
   the files the moved folder lacks.
1. For each template below, copy it from `${CLAUDE_PLUGIN_ROOT}/templates/` to `.claude/review-gate/` **only if the
   target does not exist yet**. Never overwrite a file the project already has; list the ones you skipped.
   - `review_brief.md` — project facts (Part A) + the protocol (Part B)
   - `review_rules.md` — the closed rule vocabulary
   - `routing.md` — directory → agent routing, overlay gates, ownership
   - `common_pitfalls.md` — the defect corpus
   - `config.env` — paths the validator scripts use (edit if your docs live elsewhere)

   **Steps 2 and 3 edit only files that step 1 created in this run.** A file that already existed — including a
   symlink to the project's own docs — is the project's, even if it looks like an unfilled template: do not write
   to it. For those files, report what the draft would have changed as a suggestion instead.
2. For each of `review_brief.md` and `routing.md` that step 1 created: read the project's manifest, lint config,
   test layout and existing docs, then **draft Part A** of `review_brief.md` and the first rows of `routing.md` from
   what you actually find. Mark every fact you could not verify with `<VERIFY>`; do not guess.
3. List the installed agents (`/agents`). If step 1 created `routing.md`, fill the agent names in it; otherwise
   list the routing names that do not match an installed agent. Plugin agents are written `<plugin>:<agent>`.
4. Run `claude mcp list` (or inspect the available tools) and report whether MCP servers named exactly `serena`
   and `context7` are configured. If one is missing, print the install commands (`claude mcp add --transport http context7 https://mcp.context7.com/mcp`;
   serena: the Requirements section of this kit's README, https://github.com/nccong85/escanner-agent-kit) and say
   that the agents will fall back to Grep/Read and installed sources.
5. Create the reports directory named in `review_brief.md` §B7 (default `docs/reviews/`) if it does not exist.
6. Run `validate_rule_ids.sh R-NN-1` to confirm the scripts find the files; the template pitfall headings are
   unnumbered on purpose, so `R-PIT-*` resolves only after you add a real entry.
7. Report what was moved, created and skipped, and every `<VERIFY>` the user still has to settle.
