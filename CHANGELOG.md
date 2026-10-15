# Changelog

All notable changes are documented here. Versions follow [Semantic Versioning](https://semver.org/) per plugin.

## [1.0.1] — 2026-10-15
Fixes from the first field test of 1.0.0. `review-loop` and `dev-pipeline` are 1.0.1; the other two stay 1.0.0.

- `review-loop`: `validate_rule_ids.sh` stops with `FATAL` and exit 2 when the pitfalls or brief file is missing
  or a broken symlink, instead of reporting every `R-PIT-*` / `R-NN-*` ID as `UNKNOWN`, which dropped those
  findings without a word. Each file is checked only when its ID family is cited. `validate_spec_refs.sh` does
  the same for a missing routing file.
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
