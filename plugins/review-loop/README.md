# review-loop

The core of the marketplace: rule-ID-gated review that terminates.

| Component | Path | Notes |
|---|---|---|
| `review-filter` agent | `agents/review-filter.md` | Judges ONE finding against its hunk: `REAL` / `NOT_REAL` / `NEEDS_EVIDENCE`. Runs on `opus`. |
| `/review-loop:review` | `commands/review.md` | Route the diff → reviewers in parallel → validate rule IDs → filter blockers → aggregate. |
| `/review-loop:init` | `commands/init.md` | Create `.claude/review-loop/` from `templates/` without overwriting, and draft Part A from your code. |
| Validators | `bin/validate_rule_ids.sh`, `bin/validate_spec_refs.sh`, `bin/validate_citations.sh` | On the Bash `PATH` while the plugin is enabled. |
| Safety hook | `hooks/hooks.json` → `bin/block_destructive_git.sh auto` | Main session: blocks only work-destroying git commands. Subagents: also commit/push/rebase/merge/switch. |
| Templates | `templates/` | `review_brief.md`, `review_rules.md`, `routing.md`, `common_pitfalls.md`, `config.env`. |

Exit codes: validators return `0` when everything resolves, `1` when something does not, `2` on usage or missing
files. The hook returns `2` to block (Claude Code shows the message to the model) and `0` otherwise.
