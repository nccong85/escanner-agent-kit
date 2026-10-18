**English** · [Tiếng Việt](README.vi.md) · [日本語](README.ja.md)

# eScanner Agent Kit

A kit of agents distilled and tuned from the real development of the e-Scanner app.

I made this repo to share how to build an agent that sticks closely to concrete requirements; this is how I
understand software engineering. It is built around the author's own thinking and workflow, so it is not a general
standard: use it as a reference and adapt it to your project.

I hope this small project helps. If you find it useful, please give the repo a Star ⭐️.
Thank you!

> **New here?** [docs/guide-new-feature.md](docs/guide-new-feature.md).

## About e-Scanner

If you are interested in the real app this kit grew out of, you can download and try e-Scanner here:

- [📱 App Store (iOS)](https://apps.apple.com/app/id6790476934?pt=129164581&ct=github_agent_kit&mt=8)
- [🤖 Google Play (Android)](https://play.google.com/store/apps/details?id=io.pbsolutions.escanner&referrer=utm_source%3Dgithub%26utm_medium%3Dreadme%26utm_campaign%3Dagent_kit)

## Plugins

| Plugin | For | Required | Features |
|---|---|---|---|
| [`review‑gate`](plugins/review-gate) | Any&nbsp;project,&nbsp;any&nbsp;language | **Core** | `finding-checker` agent<br>`/review-gate:review`<br>`/review-gate:init`<br>Rule/finding/spec validators<br>Hook that blocks unsafe git commands<br>Project templates |
| [`flutter‑native`](plugins/flutter-native) | Flutter apps with a C++ engine and iOS/Android code | Optional | `flutter-coder`, `flutter-reviewer`, `cpp-engine-expert`, `ios-android-expert`, `contract-expert`, `build-release-expert`, `security-checker`, `performance-checker` |
| [`dev‑pipeline`](plugins/dev-pipeline) | The&nbsp;flow:&nbsp;spec&nbsp;→&nbsp;task&nbsp;→&nbsp;code&nbsp;→&nbsp;review | Optional | `/dev-pipeline:spec-create` → `spec-validate` → `task-decompose` → `implement`, checkpointed in `execution_state.md`<br>`/dev-pipeline:research`<br>`tech-researcher` agent |
| [`device‑e2e`](plugins/device-e2e) | An&nbsp;agent&nbsp;that&nbsp;tests&nbsp;a&nbsp;mobile&nbsp;app&nbsp;on&nbsp;real&nbsp;devices | Optional | `device-tester` agent<br>`/device-e2e:init`<br>`device-e2e:playbook` skill<br>E2e test-plan template and validator<br>iPhone (WebDriverAgent) and Android (adb + uiautomator) drivers<br>Project template |

`review-gate` works on its own. On another stack (web, backend, …), install `review-gate` and add your own agents:
see [docs/customizing.md](docs/customizing.md).

## Agents

Names are `<scope>-<role>`, and the role says what the agent does:

| Role | What it does |
|---|---|
| `-coder` | Writes code |
| `-expert` | Writes and reviews |
| `-reviewer`, `-checker` | Only reads and writes its own report |
| `-tester` | Runs tests |
| `-researcher` | Consults documentation |

| Agent | Plugin | What it does |
|---|---|---|
| `finding‑checker` | `review‑gate` | Checks whether a finding really exists |
| `tech‑researcher` | `dev‑pipeline` | Finds a technical way to implement something (which library, which API, what a store rule says...) |
| `device‑tester` | `device‑e2e` | Runs end-to-end tests of the app on a real iPhone and Android phone |
| `flutter‑coder` | `flutter‑native` | Writes Flutter/Dart feature code: screens, state, routes, storage |
| `flutter‑reviewer` | `flutter‑native` | Reviews Flutter/Dart changes |
| `cpp‑engine‑expert` | `flutter‑native` | Writes and reviews C++ processing |
| `ios‑android‑expert` | `flutter‑native` | Writes and reviews Swift and Kotlin code |
| `contract‑expert` | `flutter‑native` | Keeps both sides of each contract in sync |
| `build‑release‑expert` | `flutter‑native` | Writes and reviews CI, app signing and store release |
| `security‑checker` | `flutter‑native` | Checks changes that touch encryption, keys, logging or user data |
| `performance‑checker` | `flutter‑native` | Checks changes on hot paths (startup, image pipeline, database) against the project's performance budgets |

## Install

**1. Install the plugins**

```bash
claude plugin marketplace add nccong85/escanner-agent-kit
claude plugin install review-gate@escanner-agent-kit
claude plugin install dev-pipeline@escanner-agent-kit            # optional
claude plugin install flutter-native@escanner-agent-kit          # optional, Flutter + native stacks
claude plugin install device-e2e@escanner-agent-kit              # optional, real-device e2e on iPhone + Android
```

**2. Initialize inside your project**

```
/review-gate:init
```

`init` creates `.claude/review-gate/` from the templates and drafts the project facts from your codebase:

| File | Holds |
|---|---|
| `review_brief.md` | Part A: verified project facts (layout, stack, commands, performance budgets, non-negotiables). Part B: the protocol. |
| `review_rules.md` | The rule set every finding uses. |
| `routing.md` | Directory → coder/reviewer, overlay gates, ownership. |
| `common_pitfalls.md` | The common defects (Symptom → Cause → Rule). |
| `config.env` | Paths the validators use. |

Filled-in examples of the brief and routing files are in [examples/](examples).

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
   validate_findings.sh ── drops findings whose file, line or quote is not there (no model call)
        │
        ▼
   finding-checker × each blocking finding ── REAL / NOT_REAL / NEEDS_EVIDENCE
        │
        ▼
   fix round (blocking only, allowed files only) ─► delta review of the fix ─► done (max 2 rounds)
        │
        ▼
   next task … ─► after the last task: feature-wide audit (Step 5)
                (--per-task: stop after each task, /clear, then run implement again)
```

[docs/architecture.md](docs/architecture.md) explains each step, and
[docs/field-notes.md](docs/field-notes.md) records what was measured while building it.

## Requirements

**Required**

- Claude Code (Max plan recommended)
- `bash`, `git`, and `jq` or `python3`
- `curl`, for `/dev-pipeline:research`

**Recommended**

- `serena`: finds callers and symbols
- `context7`: current library docs

```bash
claude mcp add --transport http context7 https://mcp.context7.com/mcp
claude mcp add --scope user serena -- serena start-mcp-server --context claude-code --project-from-cwd
```

Your project's own tools (Flutter, CMake, …) must be on `PATH` so the agents can run.

## Safety hook

`review-gate` installs a `PreToolUse` hook on `Bash`:
- **Main session:** blocks only commands that destroy uncommitted work:
  - `git checkout` of paths (with or without `--`, `.`, `--force`, `--patch`)
  - `git restore` (only `--staged` alone is allowed)
  - `git stash` (not `create|list|show`)
  - `git clean` (not `-n`)
  - `git reset --hard|--merge|--keep`
  - the `--force` forms of `switch`, `checkout-index`, `rm` (not `--cached`), `mv`, `worktree remove` and
    `submodule deinit|update`
  - `switch --discard-changes` and `read-tree -u`

  Branch switching, commit and push still work.
- **Inside subagents** (detected from `agent_id`): also blocks commit, push, rebase, merge, branch switching,
  branch/tag/ref changes, gc/reflog expiry, and `git apply` without `--check`.
- The hook first normalizes the command the way the shell would read it (line continuations joined, `$'…'` and
  empty quote pairs removed, `\x` escapes and single-word quotes unwrapped), then checks each part of a chained
  command (`;`, `&&`, `||`, `|`, newlines) separately. Git aliases and `eval` text are expanded and checked like any
  other command.

For security information, see [SECURITY.md](SECURITY.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
