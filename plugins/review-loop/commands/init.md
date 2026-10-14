---
description: Create the project files the review loop reads (.claude/review-loop/) from the plugin templates, without overwriting existing ones.
---

Set up `.claude/review-loop/` in the current project.

1. For each template below, copy it from `${CLAUDE_PLUGIN_ROOT}/templates/` to `.claude/review-loop/` **only if the
   target does not exist yet**. Never overwrite a file the project already has; list the ones you skipped.
   - `review_brief.md` — project facts (Part A) + the protocol (Part B)
   - `review_rules.md` — the closed rule vocabulary
   - `routing.md` — directory → agent routing, overlay gates, ownership
   - `common_pitfalls.md` — the defect corpus
   - `config.env` — paths the validator scripts use (edit if your docs live elsewhere)
2. Read the project's manifest, lint config, test layout and existing docs, then **draft Part A** of
   `review_brief.md` and the first rows of `routing.md` from what you actually find. Mark every fact you could
   not verify with `<VERIFY>`; do not guess.
3. List the installed agents (`/agents`) and fill the agent names in `routing.md`. Plugin agents are written
   `<plugin>:<agent>`.
4. Run `validate_rule_ids.sh R-NN-1` to confirm the scripts find the files.
5. Report what was created, what was skipped, and every `<VERIFY>` the user still has to settle.
