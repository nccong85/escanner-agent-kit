# Changelog

All notable changes are documented here. Versions follow [Semantic Versioning](https://semver.org/) per plugin.

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
