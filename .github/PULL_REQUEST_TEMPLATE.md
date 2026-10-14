## What and why

## Evidence
- [ ] `bash tests/run.sh` passes (paste the counts)
- [ ] `shellcheck -S warning plugins/review-loop/bin/*.sh tests/*.sh` is clean
- [ ] `claude plugin validate --strict` passes for the marketplace and every changed plugin
- [ ] Changed agents/commands were tried in a fresh Claude Code session — what you ran:

## Not verified
<!-- Say what you could not run. -->

## Checklist
- [ ] No project-specific paths or names in shared files
- [ ] Version bumped in the changed plugin's `plugin.json` and `CHANGELOG.md` updated
