# Changelog

All notable changes are documented here. Versions follow [Semantic Versioning](https://semver.org/) per plugin.

## [2.0.0] — 2026-10-18
All four plugins are 2.0.0. **Breaking:** two plugins are renamed so the name says what the plugin does.
`review-loop` runs one gated review pass (rule IDs, cited code, the finding-checker filter) and holds the git safety
hook; the fix loop is in `dev-pipeline`. `flutter-native-agents` drops a suffix no other plugin has.

| 1.x | 2.0 |
|---|---|
| `review-loop@escanner-agent-kit` | `review-gate@escanner-agent-kit` |
| `flutter-native-agents@escanner-agent-kit` | `flutter-native@escanner-agent-kit` |
| `/review-loop:init`, `/review-loop:review` | `/review-gate:init`, `/review-gate:review` |
| `review-loop:finding-checker` | `review-gate:finding-checker` |
| `flutter-native-agents:<agent>` (all eight) | `flutter-native:<agent>` |
| `.claude/review-loop/` | `.claude/review-gate/` |
| `REVIEW_LOOP_PROJECT_DIR` | `REVIEW_GATE_PROJECT_DIR` (the old one is still read) |

- Agent names are unchanged; `dev-pipeline` and `device-e2e` change only their dependency.
- `/review-gate:init` moves a pre-2.0 `.claude/review-loop/` folder (`git mv` when tracked) and rewrites the old
  agent prefixes in its regular files. Symlinked files are listed, not edited; two folders at once stop it.
- Until then the validators and `spec-validate` read `.claude/review-loop/` with a `NOTE`; `implement`,
  `spec-create`, `task-decompose`, `research` and `/review-gate:review` stop and ask for init.
- The routing template's *Legacy names* table maps 1.0.x and 1.1 names to 2.0 names. In a moved 1.1 project, init
  adds the `2.0 name` column to the project's table, and `implement` looks up an old name in any column.
- `marketplace.json` lists both renames under `renames`, so an installed plugin follows the new name.
- Tests: old names may appear only in history and in the migration; the fallback is pinned.

## [dev-pipeline 1.3.0 · device-e2e 1.2.0 · review-loop 1.1.1 · flutter-native-agents 1.1.1] — 2026-10-18
Fixes from the e-Scanner field test (TODO #11, #12, #8, #9, #5). New behavior in `dev-pipeline` and `device-e2e`;
wording-only fixes in `review-loop` and `flutter-native-agents`.
- `dev-pipeline`: `implement` takes the pre-fix snapshot before every fix round, and says so at each place that
  dispatches a fix coder: Step 3, both `Step=FIX` rows of the routing table, and the Step 5 audit fix, which
  skipped it once in the field test. With no snapshot the delta review has no base, so it becomes a full review of
  the fixed files, never a diff against the coder's own backups. A test pins every one of these lines.
- `flutter-native-agents`, `review-loop`: every agent with a review hand-off (the reviewer, both checkers, the four
  experts in review mode) and the brief's §B7 now say the report file is the one file a reviewer writes, and that it
  is required even when a harness default discourages creating `.md` files. In the field test `flutter-reviewer`
  wrote it in three rounds and returned it inline in the fourth. `implement` Step 2 and `/review-loop:review` check
  that the named report exists, re-prompt the reviewer once, and otherwise save the inline reply themselves.
- `dev-pipeline`: a task that needs the owner's yes for a build, a device run or a bench is marked
  `**Gate:** owner approval — <what>` by `task-decompose`. `implement` stops before dispatching it until Pipeline
  State records the approval, then passes that line to the agent (which is what `device-tester` waits for). An agent
  that reports `BLOCKED` with a reason now has its own routing row: save, stop, report, no retry. Stop 3 covers
  both, so there are still six sanctioned stops. In the field test the orchestrator had to make this stop up.
- `device-e2e`: new `/device-e2e:init` creates `.claude/device-e2e/project.md` from the playbook template (never
  over an existing file or symlink), fills only what it can read from the project (the app id and the build or install scripts), and lists every
  slot left as `<VERIFY>`. `task-decompose` warns when a task routes to `device-tester` and that file is missing or
  unfilled. Before, it was copied by hand, and a missing file showed up only as `BLOCKED` at dispatch.
- `dev-pipeline`: a `spec-create` question about performance or budget now quotes the Part A rule it touches, and an
  answer beyond that rule goes into the spec's Performance section as a scoped, dated owner exception.
  `spec-validate` accepts that form instead of failing every exceeded budget. In the field test the owner answered
  "+50 %" without seeing the 20 % regression rule, and had to be asked again after validate failed.
  `implement` passes those exception lines to the coder and to both review prompts (round 1 and delta), so the
  reviewer enforces the approved limit within its scope, and still blocks beyond it.
- `dev-pipeline`: in a delta review, a prior blocking finding verdicted `NOT CLOSED` goes back to the fix coder
  with the regressions (iteration cap unchanged); before, only regressions were routed, and a round with no new
  regression fell to rule C4 as a spec doubt. A full review that replaces a delta for lack of a snapshot routes a
  new blocking finding as a regression, since nothing can show it predates the fix.

## [dev-pipeline 1.2.0] — 2026-10-15
- `implement` now stops after each task by default and prints the resume line (`/clear`, then
  `/dev-pipeline:implement <spec>`), so every task runs in a fresh, small main session. The state was already in
  `execution_state.md`, so nothing is lost. Measured on e-Scanner: main sessions that grew past 400k tokens of
  context were 92% of all tokens spent; subagents were about 2%. `--continuous` keeps the old one-session run for
  small features. The boundary never falls inside a task, so fix rounds still resume the same coder.
- The other three plugins stay 1.1.0.

## [1.1.0] — 2026-10-15
All four plugins are 1.1.0. **Breaking:** every agent is renamed so a newcomer can read what it does from its name.
Names are now `<scope>-<role>`, with the role from a closed set tied to permissions: `-coder`, `-expert` (writes and
reviews one layer), `-reviewer`, `-checker`, `-tester`, `-researcher` (`docs/agent-guideline.md` §2).

| 1.0.x | 1.1 |
|---|---|
| `review-loop:review-filter` | `review-loop:finding-checker` |
| `dev-pipeline:research-tech` | `dev-pipeline:tech-researcher` |
| `device-e2e:test-device-e2e` | `device-e2e:device-tester` |
| `flutter-native-agents:dev-flutter` | `flutter-native-agents:flutter-coder` |
| `flutter-native-agents:review-flutter` | `flutter-native-agents:flutter-reviewer` |
| `flutter-native-agents:owner-native-engine` | `flutter-native-agents:cpp-engine-expert` |
| `flutter-native-agents:owner-platform` | `flutter-native-agents:ios-android-expert` |
| `flutter-native-agents:owner-contract` | `flutter-native-agents:contract-expert` |
| `flutter-native-agents:owner-build-release` | `flutter-native-agents:build-release-expert` |
| `flutter-native-agents:gate-security` | `flutter-native-agents:security-checker` |
| `flutter-native-agents:gate-performance` | `flutter-native-agents:performance-checker` |

**Upgrade:** update the names in `.claude/review-loop/routing.md`, and copy the old → new map from the template's
`Legacy names` section into it so plans and `execution_state.md` files written with 1.0.x still resolve.

The README gains an Agents section that says in one line what each agent does.

Vietnamese docs: every user-facing doc (README, `docs/`, each plugin README) has a `.vi.md` translation next to it,
linked from the first line of the English file.

## [1.0.1] — 2026-10-15
Fixes from the first field test of 1.0.0 (never released separately; shipped in 1.1.0). `review-loop` and
`dev-pipeline` were 1.0.1; the other two stayed 1.0.0.

- `review-loop`: `validate_rule_ids.sh` stops with `FATAL` and exit 2 when the pitfalls or brief file is missing
  or a broken symlink, instead of reporting every `R-PIT-*` / `R-NN-*` ID as `UNKNOWN`, which dropped those
  findings without a word. Each file is checked only when its ID family is cited. `validate_spec_refs.sh` does
  the same for a missing routing file.
- `review-loop`: `validate_spec_refs.sh` no longer accepts `wrong-plugin:x` because the project has
  `.claude/agents/x.md`; a project agent resolves only by its bare name. Its rejection hint, and `spec-create`,
  now name the planned-file forms it actually accepts (`` new `path` `` / `` create `path` ``) instead of
  "to be created", which failed when written after the path.
- `review-loop`: `/review-loop:review` says what exit 2 means: stop, drop no finding.
- `review-loop`: `/review-loop:init` drafts only into the files it created in that run; existing files and
  symlinks get suggestions, never edits.
- `dev-pipeline`: `implement` treats a validator `FATAL` as a fifth sanctioned stop and drops no finding over it.
- `dev-pipeline`: `spec-create` never writes over an existing spec and puts a follow-up in its own folder;
  `task-decompose` refuses to overwrite another spec's `{feature}_tasks.md` / `execution_state.md`.
- `dev-pipeline`: `task-decompose` now creates the same 8-column Cost Ledger that `implement` fills in (it
  created an old 7-column one without the two `Dropped` columns), and both define "Report lines".

## [1.0.0] — 2026-10-14
First stable release. All four plugins are 1.0.0.

- `review-loop`: closed rule vocabulary, `validate_rule_ids.sh`, `validate_findings.sh` (file, line and verbatim
  quote), `validate_spec_refs.sh`, `validate_citations.sh`, the `review-filter` agent, and a shell-aware git
  guard hook.
- `dev-pipeline`: spec → validate → decompose → implement, with resumed coders for fix rounds and a Cost Ledger
  that records what each deterministic gate dropped.
- `flutter-native-agents`: reference coder, reviewer, contract-owner and gate agents for Flutter + native stacks.
- `device-e2e`: real-device e2e on an iPhone (WebDriverAgent) and an Android phone (adb), with the
  `test-device-e2e` agent, the `device-e2e:playbook` skill and tested drivers.
