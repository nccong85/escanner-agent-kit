**English** · [Tiếng Việt](README.vi.md)

# review-gate

The core of the marketplace: rule-ID-gated review that terminates.

| Component | Path | Notes |
|---|---|---|
| `finding-checker` agent | `agents/finding-checker.md` | Judges ONE finding against its hunk: `REAL` / `NOT_REAL` / `NEEDS_EVIDENCE`. Runs on `opus`. |
| `/review-gate:review` | `commands/review.md` | Route the diff → reviewers in parallel → validate rule IDs → filter blockers → aggregate. |
| `/review-gate:init` | `commands/init.md` | Creates `.claude/review-gate/` from `templates/` (no overwrite) and drafts Part A from your code. |
| Validators | `bin/validate_rule_ids.sh`, `bin/validate_findings.sh`, `bin/validate_spec_refs.sh`, `bin/validate_citations.sh` | On the Bash `PATH` while the plugin is enabled. Project root (`bin/lib_config.sh`): `REVIEW_GATE_PROJECT_DIR`, else `CLAUDE_PROJECT_DIR`, else the git root, else the current directory. |
| Safety hook | `hooks/hooks.json` → `bin/block_destructive_git.sh auto` | Main session: blocks only work-destroying git commands. Subagents: every git command that changes the working tree, index, refs or history (commit, push, rebase, merge, switch, stash, branch, tag, …). |
| Templates | `templates/` | `review_brief.md`, `review_rules.md`, `routing.md`, `common_pitfalls.md`, `config.env`. |

## Set up

Needs `jq` or `python3` (with neither, the hook blocks every git command), and `curl` for `validate_citations.sh`.

1. `claude plugin install review-gate@escanner-agent-kit`.
2. Run `/review-gate:init` in your project. It creates `.claude/review-gate/` and drafts Part A of
   `review_brief.md` from your code, marking each fact it could not verify with `<VERIFY>`.
3. Settle each `<VERIFY>`, then fill `routing.md` with your coder and reviewer agents.
4. Run `/review-gate:review` on a diff.

From 1.x: 2.0.0 renamed `review-loop` → `review-gate`. `/review-gate:init` moves `.claude/review-loop/` to
`.claude/review-gate/` and rewrites the old agent names; until then the validators read the old folder.

Exit codes: validators return `0` when everything resolves, `1` when something does not, `2` on usage errors or
missing files. The hook returns `2` to block (Claude Code shows the message to the model), else `0`.
