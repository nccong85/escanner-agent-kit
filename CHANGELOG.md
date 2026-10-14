# Changelog

All notable changes are documented here. Versions follow [Semantic Versioning](https://semver.org/) per plugin.

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
