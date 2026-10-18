# Changelog

All notable changes are documented here. Versions follow [Semantic Versioning](https://semver.org/) per plugin.

## Unreleased

### device-e2e
- `validate_e2e_plan.py --results`: every case PASS must cite an evidence file (a path with a directory, e.g. `evidence/E1_ios_1.png`), and every cited evidence file, in the table or a `BUG-n` entry, must exist relative to the summary.
- The agent, playbook, glossary and results template keep evidence in `evidence/` next to the summary, named `<ID>_<platform>_<n>.<ext>`.
