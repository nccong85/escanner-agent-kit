# Changelog

All notable changes are documented here. Versions follow [Semantic Versioning](https://semver.org/) per plugin.

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
