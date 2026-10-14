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

## Important notes

- **A reference base, not a finished product.** This kit shows how to structure agents, rules and a review loop.
  Copy the patterns and adapt the agents, rule vocabulary and routing to your own project — the agents in
  `flutter-native-agents` will not fit an unrelated codebase unchanged.
- **Agents are token-hungry.** A single feature through the pipeline runs a coder, several reviewers, one filter
  call per blocking finding and possibly fix rounds, each a separate session on a strong model. Use it with a
  **Claude Max subscription**; on pay-per-token API billing it gets expensive quickly. For small changes use the
  main session plus `/review-loop:review`.
- **Models.** Agents use `model: inherit` (your session's model); only `review-filter` is pinned to `opus`,
  because a smaller model once rejected a true finding.

New here? Follow **[docs/guide-new-feature.md](docs/guide-new-feature.md)** — one real feature taken through every step.

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

**Required**
- Claude Code with plugin support
- `bash`, `git`, and `jq` or `python3` (used by the safety hook)

**Recommended** — the agents still work without them, just less precisely
- `serena`: finds callers and symbols
- `context7`: current library docs

```bash
claude mcp add --transport http context7 https://mcp.context7.com/mcp
claude mcp add --scope user serena -- serena start-mcp-server --context claude-code --project-from-cwd
```

The names must be exactly `serena` and `context7`.

**Your project's own tools** (Flutter, CMake, …) must be on `PATH` so the agents can run your tests.

## Safety hook

`review-loop` installs a `PreToolUse` hook on `Bash`:
- **Main session:** blocks only commands that destroy uncommitted work — `git checkout` of paths (with or
  without `--`, `.`, `--force`, `--patch`), `git restore` (only `--staged` alone is allowed), `git stash` (not
  `create|list|show`), `git clean` (not `-n`), `git reset --hard|--merge|--keep`, `git worktree remove --force`.
  Branch switching, commit and push still work.
- **Inside subagents** (detected from `agent_id`): additionally blocks commit, push, rebase, merge, branch
  switching, branch/tag/ref changes, gc/reflog expiry, and `git apply` without `--check`.
- The command is first normalized the way the shell would read it (line continuations joined, `$'…'` and empty
  quote pairs removed, `\x` escapes and single-word quotes unwrapped), then each part of a chained command
  (`;`, `&&`, `||`, `|`, newlines) is checked separately. Git commands built through an alias, a `$GIT` variable,
  `eval` or command substitution are refused.

It is a guard against accidents, not a security boundary — see [SECURITY.md](SECURITY.md).

Run a blocked command yourself with Claude Code's `!` prefix when you really mean it.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Run `bash tests/run.sh` and `claude plugin validate --strict .` before a PR.

## License

[MIT](LICENSE)
