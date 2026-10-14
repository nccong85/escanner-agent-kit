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

## [0.1.5] — 2026-10-14
### Security
- `review-loop` 0.1.4: the git guard normalizes a command the way the shell reads it before checking it. These
  bypasses were confirmed and are now blocked: a quoted verb (`git "stash"`, `git 'checkout' -- f`), a line
  continuation (`git \⏎stash`), ANSI-C quoting (`git $'stash'`), empty-quote splicing (`g""it stash`,
  `git stas""h`) and backslash escapes (`git st\ash`). Newlines now separate commands.
- 21 new security test cases, including the legitimate commands that must stay allowed (quoted grep patterns,
  multi-word and single-word commit messages, `--grep=`).

## [0.1.4] — 2026-10-14
### Changed
- `review-loop` 0.1.3: `/review-loop:init` points to this kit's README for the serena install command (it read as
  serena's own README).
- Guide: how to update the plugins, and what to do when an update reports "already at the latest version" for a
  second project or a moved project folder.

## [0.1.3] — 2026-10-14
### Changed
- README: one short **Requirements** section (required / recommended / your own tools) replaces the separate
  requirements and MCP sections; a one-line note on models.
- `dev-pipeline` 0.1.2: `implement` no longer names skills from the project the kit was extracted from.

## [0.1.2] — 2026-10-14
### Added
- `docs/guide-new-feature.md`: one real feature ("pin/unpin notes") taken through spec-create, spec-validate,
  task-decompose and implement on a test project, with the actual outputs.
- README "Important notes": the kit is a reference base, and agents are token-hungry (use a Claude Max subscription).
- README "Recommended MCP servers": install commands for `serena` and `context7`, and what happens without them.
- Every agent that lists `serena`/`context7` has a **Tool availability** section: check what is installed, fall back
  to Grep/Read (or grep/find through Bash) and the installed package source, never stop because an optional tool is
  missing. Read-only agents never edit files to prove a point.
- `/review-loop:init` reports whether `serena` and `context7` are configured.
### Changed
- `review_brief.md` template §B2: reviewers never modify files, not even temporarily (seen in a real run).
- Docs: corrected an overstated field note about the delta-review baseline, the number of command-checked gate
  conditions (three, not four), and described the demo run as non-interactive.

Plugin versions: `review-loop` 0.1.2 · `dev-pipeline` 0.1.1 · `flutter-native-agents` 0.1.1.

## [0.1.1] — 2026-10-14
### Fixed
- `review-loop` templates: the example headings in `common_pitfalls.md` are unnumbered, so `R-PIT-1` / `R-PIT-1.1`
  no longer resolve before a real pitfall exists (found by installing the kit into a test project).
- `review-loop` templates: `review_brief.md` §B7 now defaults the reports directory to `docs/reviews/`, and
  `/review-loop:init` creates it.
- Regression test: the unmodified pitfall template must not resolve any `R-PIT-*` ID.

## [0.1.0] — 2026-10-14
### Added
- `review-loop`: `review-filter` agent, `/review-loop:review`, `/review-loop:init`, rule/spec/citation
  validators, destructive-git `PreToolUse` hook (main-session and subagent modes), project templates.
- `dev-pipeline`: `spec-create`, `spec-validate`, `task-decompose`, `implement`, `research`, `research-tech` agent.
- `flutter-native-agents`: `dev-flutter`, `review-flutter`, `owner-native-engine`, `owner-platform`,
  `owner-contract`, `owner-build-release`, `gate-security`, `gate-performance`.
- Tests for the hook (74 cases), validators, and security cases, CI workflow, documentation.
### Security
- `config.env` is parsed as data instead of being sourced (a hostile repository could otherwise run code).
- The git guard checks each part of a chained command, blocks path checkouts without `--`, `--force`,
  `restore --staged --worktree`, `worktree remove --force`, and git commands built through aliases, variables,
  `eval` or command substitution.
