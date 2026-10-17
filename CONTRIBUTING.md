# Contributing

Thanks for helping. This repository prefers **measured** changes to clever ones.

## What we accept
- Fixes to agents, commands, hooks and validators, with a test or a reproduction.
- New rules or protocol changes **backed by a case you observed** (what failed, how you measured it). Add it to
  `docs/field-notes.md` and `docs/field-notes.vi.md`.
- New stack plugins that follow [docs/agent-guideline.md](docs/agent-guideline.md) and depend on `review-gate`.

## What we do not accept
- Agents that duplicate an existing agent's responsibility.
- Product promotion inside agent or command text.
- Unknown frontmatter fields, bare MCP server names in `tools:`, or project-specific paths in shared files.

Every user-facing doc has a Vietnamese twin (`*.vi.md`) next to it. Change both in the same PR.

## Before you open a pull request
```bash
bash tests/run.sh
shellcheck -S warning plugins/review-gate/bin/*.sh tests/*.sh
claude plugin validate --strict .
for p in plugins/*; do claude plugin validate --strict "$p"; done
```
Then test the changed agent or command in a **fresh** Claude Code session (definitions load at session start), and
say in the PR what you ran and what you did not.

## Versioning
Bump `version` in the plugin's `plugin.json` for every release of that plugin (semver) and add a line to
`CHANGELOG.md`. Avoid renaming a published plugin. A rename is a major version: add the old → new name to `renames`
in `marketplace.json` (append only), and write the upgrade steps in the CHANGELOG and README.
