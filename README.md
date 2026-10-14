# eScanner Agent Kit

A Claude Code plugin marketplace for **agent code review that actually terminates**.

Multi-agent review usually fails in the same ways: reviewers invent rules, re-review the whole feature every
round, file each other's findings, and turn every Medium nit into another fix round. This repository packages
the opposite design, extracted from a production mobile app:

- **A closed rule vocabulary.** Every finding cites a rule ID; a script drops IDs that do not resolve — no model call.
- **A precision filter.** `review-filter` judges one finding against one diff hunk, without seeing the
  reviewer's reasoning, before any fix round starts.
- **Convergence rules.** Only Critical/High block, round 2+ is a delta review of the fix, fix rounds are capped,
  and a new non-regression blocker means the *spec* is wrong — stop and ask.
- **Exclusive ownership.** Each concern has one reviewer; everyone else mentions it in one line.
- **Machines over prompts.** A `PreToolUse` hook blocks git commands that would destroy uncommitted work, and
  recurring findings must graduate into tests.

## Plugins

| Plugin | What you get |
|---|---|
| [`review-loop`](plugins/review-loop) | `review-filter` agent · `/review-loop:review` · `/review-loop:init` · rule/spec/citation validators on `PATH` · destructive-git hook · project templates |
| [`dev-pipeline`](plugins/dev-pipeline) | `/dev-pipeline:spec-create` → `spec-validate` → `task-decompose` → `implement`, checkpointed in `execution_state.md` · `/dev-pipeline:research` · `research-tech` agent |
| [`flutter-native-agents`](plugins/flutter-native-agents) | Reference stack for Flutter apps with a C/C++ engine and iOS/Android code: `dev-flutter`, `review-flutter`, `owner-native-engine`, `owner-platform`, `owner-contract`, `owner-build-release`, `gate-security`, `gate-performance` |

`review-loop` is the core and works on its own. The other two depend on it.

## Install

```bash
claude plugin marketplace add nccong85/escanner-agent-kit
claude plugin install review-loop@escanner-agent-kit
claude plugin install dev-pipeline@escanner-agent-kit            # optional
claude plugin install flutter-native-agents@escanner-agent-kit   # optional, Flutter + native stacks
```

Then, inside your project:

```
/review-loop:init
```

`init` creates `.claude/review-loop/` from the templates and drafts the project facts from your code:

| File | Holds |
|---|---|
| `review_brief.md` | Part A: verified project facts (layout, stack, commands, budgets, non-negotiables). Part B: the protocol. |
| `review_rules.md` | The closed rule vocabulary findings must cite. |
| `routing.md` | Directory → coder/reviewer, overlay gates, exclusive ownership. |
| `common_pitfalls.md` | Your defect corpus (Symptom → Cause → Rule). |
| `config.env` | Paths the validators use, if your docs live somewhere else. |

Review a diff with `/review-loop:review`. Run a feature end to end with `/dev-pipeline:spec-create "<feature>"`.

## How it works

```
spec-create ─► spec-validate ─► task-decompose ─► implement
                                                    │
        ┌───────────────────────────────────────────┘
        ▼
   coder (or main session) ── SELF-CHECK + ACTION: REVIEW_REQUIRED
        │
        ▼
   area reviewer(s) + overlay gates (parallel, diff only, one column each)
        │  ACTION: ISSUES_FOUND (blocking=n, deferred=m)
        ▼
   validate_rule_ids.sh ── drops invented rule IDs (no model call)
        │
        ▼
   review-filter × each blocking finding ── REAL / NOT_REAL / NEEDS_EVIDENCE
        │
        ▼
   fix round (blocking only, allowed files only) ─► delta review of the fix ─► done (max 2 rounds)
```

See [docs/architecture.md](docs/architecture.md) for the reasoning behind each step and
[docs/field-notes.md](docs/field-notes.md) for what was measured while building it.

## When not to use this

Small fixes, one-file changes and exploratory work are faster in a single session. Multi-agent runs cost many
times the tokens of a chat. See [docs/when-not-to-use.md](docs/when-not-to-use.md).

## Requirements

- Claude Code with plugin support (developed and validated with v2.1.299).
- `bash`, `git`, and `jq` or `python3` for the hook and validators. `curl` for citation checks.
- Agents default to `model: inherit` so you control cost; `review-filter` uses `opus` on purpose (a smaller
  model once deleted a true finding, which is the one error the filter cannot recover from).

## Safety hook

`review-loop` installs a `PreToolUse` hook on `Bash`:
- **Main session:** blocks only commands that destroy uncommitted work — `git checkout -- <path>`,
  `git checkout .`, `git restore` (not `--staged`), `git stash` (not `create|list|show`), `git clean` (not `-n`),
  `git reset --hard|--merge|--keep`. Branch switching, commit and push still work.
- **Inside subagents** (detected from `agent_id`): additionally blocks commit, push, rebase, merge, branch
  switching and `git apply` without `--check`.

Run a blocked command yourself with Claude Code's `!` prefix when you really mean it.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Run `bash tests/run.sh` and `claude plugin validate --strict .` before a PR.

## License

[MIT](LICENSE)
