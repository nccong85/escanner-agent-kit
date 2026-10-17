**English** · [Tiếng Việt](README.vi.md)

# eScanner Agent Kit

The Claude Code agents, review rules and workflows I built while developing **e-Scanner**, a document scanner app
for iPhone and Android.

They come from one project and are tailored to it. Use them as a reference: copy the patterns and adapt the agents,
rule vocabulary and routing to your project (the `flutter-native` agents will not fit an unrelated codebase
unchanged). Improvements are welcome, and I'd be glad if any of it helps you.

- **Agents are token-hungry.** One feature through the pipeline runs a coder, several reviewers, one filter call per
  blocking finding and possibly fix rounds, each a separate session on a strong model. Use a **Claude Max
  subscription**; pay-per-token API billing gets expensive fast. For small changes, use the main session plus
  `/review-gate:review`.
- **Models.** Agents use `model: inherit` (your session's model). Only `finding-checker` is pinned to `opus`, because
  a smaller model once rejected a true finding.

**Get e-Scanner:** [App Store (iOS)](https://apps.apple.com/app/id6790476934?pt=129164581&ct=github_agent_kit&mt=8) ·
[Google Play (Android)](https://play.google.com/store/apps/details?id=io.pbsolutions.escanner&referrer=utm_source%3Dgithub%26utm_medium%3Dreadme%26utm_campaign%3Dagent_kit)

New here? **[docs/guide-new-feature.md](docs/guide-new-feature.md)** takes one real feature through every step.

## Plugins

Four plugins, so you install only what fits your project.

| Plugin | Who it is for | Required? | What you get |
|---|---|---|---|
| [`review-gate`](plugins/review-gate) | Any project, any language | **Core**, install it first | `finding-checker` agent · `/review-gate:review` · `/review-gate:init` · rule/finding/spec/citation validators · destructive-git hook · project templates |
| [`flutter-native`](plugins/flutter-native) | Flutter apps with a C/C++ engine and iOS/Android code, like e-Scanner | Optional | `flutter-coder`, `flutter-reviewer`, `cpp-engine-expert`, `ios-android-expert`, `contract-expert`, `build-release-expert`, `security-checker`, `performance-checker` |
| [`dev-pipeline`](plugins/dev-pipeline) | Teams that want the whole flow: spec → tasks → code → review | Optional | `/dev-pipeline:spec-create` → `spec-validate` → `task-decompose` → `implement`, checkpointed in `execution_state.md` · `/dev-pipeline:research` · `tech-researcher` agent |
| [`device-e2e`](plugins/device-e2e) | Anyone testing a mobile app on a real iPhone or Android phone | Optional | `device-tester` agent · `/device-e2e:init` · `device-e2e:playbook` skill · e2e test-plan template and validator · iPhone (WebDriverAgent) and Android (adb + uiautomator) drivers with one interface · project template |

`review-gate` works on its own. Each optional plugin depends on it and installs it too. On another stack (web,
backend, …), install `review-gate` and add your own agents: see [docs/customizing.md](docs/customizing.md).

## Agents

Names are `<scope>-<role>`, and the role says what the agent may do: a `-coder` writes code, an `-expert` writes and
reviews one layer, a `-reviewer` or `-checker` only reads and writes its own report, a `-tester` runs tests, a
`-researcher` only reads sources.

| Agent | Plugin | What it does |
|---|---|---|
| `finding-checker` | `review-gate` | Decides whether one problem a reviewer reported is real, before anyone spends a fix round on it |
| `tech-researcher` | `dev-pipeline` | Answers a technical question (which library, which API, what a store rule says) with cited sources |
| `device-tester` | `device-e2e` | Runs end-to-end tests of the app on a real iPhone and Android phone |
| `flutter-coder` | `flutter-native` | Writes Flutter/Dart feature code: screens, state, routes, storage |
| `flutter-reviewer` | `flutter-native` | Reviews Flutter/Dart changes |
| `cpp-engine-expert` | `flutter-native` | Writes and reviews the C++ image-processing engine |
| `ios-android-expert` | `flutter-native` | Writes and reviews the Swift (iOS) and Kotlin (Android) code the app calls |
| `contract-expert` | `flutter-native` | Keeps both sides of each contract between the parts (C ABI, encrypted file format, API shapes) in sync |
| `build-release-expert` | `flutter-native` | Writes and reviews CI, signing and store release work |
| `security-checker` | `flutter-native` | Checks changes that touch encryption, keys, logging or user data |
| `performance-checker` | `flutter-native` | Checks changes on hot paths (startup, image pipeline, database) against the project's budgets |

**Upgrading from 1.x?** 2.0.0 renamed two plugins: `review-loop` → `review-gate` and
`flutter-native-agents` → `flutter-native`. The marketplace maps the old names, so update it and install the new
names once:

```bash
claude plugin marketplace update escanner-agent-kit
claude plugin install review-gate@escanner-agent-kit
claude plugin install flutter-native@escanner-agent-kit   # if you used flutter-native-agents
```

Then run `/review-gate:init` in each project. It moves `.claude/review-loop/` to `.claude/review-gate/`, rewrites
the agent prefixes, and adds a `2.0 name` column to your *Legacy names* table so plans with 1.x names still resolve.
Until then the validators and `spec-validate` read the old folder (with a NOTE), while `implement`, `spec-create`,
`task-decompose`, `research` and `/review-gate:review` stop and ask for init.

**Upgrading from 1.0.x?** 1.1.0 renamed the agents (for example `review-filter` → `finding-checker`,
`owner-contract` → `contract-expert`). Update the names in your `.claude/review-gate/routing.md`. The full old → new
map is the `Legacy names` section of [the routing template](plugins/review-gate/templates/routing.md); copy it into
your routing file so plans written with 1.0.x still resolve.

## Install

```bash
claude plugin marketplace add nccong85/escanner-agent-kit
claude plugin install review-gate@escanner-agent-kit
claude plugin install dev-pipeline@escanner-agent-kit            # optional
claude plugin install flutter-native@escanner-agent-kit          # optional, Flutter + native stacks
claude plugin install device-e2e@escanner-agent-kit              # optional, real-device e2e on iPhone + Android
```

Then, inside your project:

```
/review-gate:init
```

`init` creates `.claude/review-gate/` from the templates and drafts the project facts from your code:

| File | Holds |
|---|---|
| `review_brief.md` | Part A: verified project facts (layout, stack, commands, budgets, non-negotiables). Part B: the protocol. |
| `review_rules.md` | The closed rule vocabulary findings must cite. |
| `routing.md` | Directory → coder/reviewer, overlay gates, exclusive ownership. |
| `common_pitfalls.md` | Your defect corpus (Symptom → Cause → Rule). |
| `config.env` | Paths the validators use, if your docs live somewhere else. |

Filled-in examples of the brief and routing files are in [examples/](examples).

Review a diff with `/review-gate:review`. Run a feature with `/dev-pipeline:spec-create "<feature>"`, then
`spec-validate`, `task-decompose` and `implement`. `implement` stops after each task so the next starts in a fresh
session: run `/clear`, then `implement` again (`--continuous` runs every task in one session, for small features).
It also stops before a task that needs your approval (a build or a device run).

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
   task done ── stop: /clear, then run implement again for the next task
                (after the last task: one more run for the feature-wide audit)
```

[docs/architecture.md](docs/architecture.md) explains each step, and [docs/field-notes.md](docs/field-notes.md)
records what was measured while building it.

## When not to use this

Small fixes, one-file changes and exploratory work are faster in a single session. Multi-agent runs cost many
times the tokens of a chat. See [docs/when-not-to-use.md](docs/when-not-to-use.md).

## Requirements

Required:
- Claude Code with plugin support
- `bash`, `git`, and `jq` or `python3` (used by the safety hook; without either it blocks every git command)
- `curl`, for `/dev-pipeline:research` (it checks that cited URLs exist)

Recommended (the agents work without them, less precisely):
- `serena`: finds callers and symbols
- `context7`: current library docs

```bash
claude mcp add --transport http context7 https://mcp.context7.com/mcp
claude mcp add --scope user serena -- serena start-mcp-server --context claude-code --project-from-cwd
```

The names must be exactly `serena` and `context7`: the agents list their tools as `mcp__serena__*` and
`mcp__context7__*`. A connector with another name (claude.ai's Context7 shows up as `claude_ai_Context7`) is not
seen by the agents.

Your project's own tools (Flutter, CMake, …) must be on `PATH` so the agents can run your tests.

## Safety hook

`review-gate` installs a `PreToolUse` hook on `Bash`:
- **Main session:** blocks only commands that destroy uncommitted work: `git checkout` of paths (with or
  without `--`, `.`, `--force`, `--patch`), `git restore` (only `--staged` alone is allowed), `git stash` (not
  `create|list|show`), `git clean` (not `-n`), `git reset --hard|--merge|--keep`, and the `--force` forms of
  `switch`, `checkout-index`, `rm` (not `--cached`), `mv`, `worktree remove` and `submodule deinit|update`, plus
  `switch --discard-changes` and `read-tree -u`. Branch switching, commit and push still work.
- **Inside subagents** (detected from `agent_id`): also blocks commit, push, rebase, merge, branch switching,
  branch/tag/ref changes, gc/reflog expiry, and `git apply` without `--check`.
- The hook first normalizes the command the way the shell would read it (line continuations joined, `$'…'` and
  empty quote pairs removed, `\x` escapes and single-word quotes unwrapped), then checks each part of a chained
  command (`;`, `&&`, `||`, `|`, newlines) separately. Git aliases and `eval` text are expanded and checked like any
  other command. Anything it cannot check (a `$GIT` variable, command substitution, an alias defined in the same
  command) is refused.

It guards against accidents and is not a security boundary: see [SECURITY.md](SECURITY.md).

To run a blocked command on purpose, run it yourself with Claude Code's `!` prefix.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the checks to run before a PR.

## License

[MIT](LICENSE)
