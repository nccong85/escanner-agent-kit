# Contributing

Thanks for helping. This repository values **measured** changes over clever ones.

## What we accept
- Fixes to agents, commands, hooks and validators, with a test or a reproduction.
- New rules or protocol changes **backed by a case you observed** (what failed, how you measured it). Add it to
  `docs/field-notes.md`.
- New stack plugins that follow [docs/agent-guideline.md](docs/agent-guideline.md) and depend on `review-loop`.

## What we do not accept
- Agents that duplicate an existing agent's responsibility.
- Product promotion inside agent or command text.
- Unknown frontmatter fields, bare MCP server names in `tools:`, or project-specific paths in shared files.

## Before you open a pull request
```bash
bash tests/run.sh
shellcheck -S warning plugins/review-loop/bin/*.sh tests/*.sh
claude plugin validate --strict .
for p in plugins/*; do claude plugin validate --strict "$p"; done
```
Then test the changed agent or command in a **fresh** Claude Code session (definitions load at session start) and
say in the PR what you ran and what you did not.

## Versioning
Bump `version` in the plugin's `plugin.json` for every release of that plugin (semver) and add a line to
`CHANGELOG.md`. Never rename a published plugin; use `renames` in `marketplace.json` if you must.
