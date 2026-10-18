**English** · [Tiếng Việt](README.vi.md) · [日本語](README.ja.md)

# dev-pipeline

From spec to ship.

| Command | Role |
|---|---|
| `/dev-pipeline:spec-create "<feature>"` | Writes the spec in plan mode, with checkable acceptance criteria |
| `/dev-pipeline:spec-validate <spec>` | Six objective gate conditions, three settled by commands. Saves the verdict next to the spec. |
| `/dev-pipeline:task-decompose <spec>` | Splits the work into tasks with a checkable Definition of Done (DoD), does contracts, and creates `execution_state.md`. |
| `/dev-pipeline:implement <spec> [--per-task]` | Coder → reviewers → validate → filter → fix (max 2) → delta review, resumable from `execution_state.md`. Runs every task, then the feature-wide audit (Step 5), in one session. `--per-task` stops after each task. |
| `/dev-pipeline:research "<question>"` | Researches how to implement something; calls `tech-researcher` only for questions that need depth or breadth; checks citations. |

| Agent | Role |
|---|---|
| `dev-pipeline:tech-researcher` | Researches one technical question; called by `research`. |

Files: specs, validation verdicts, `{feature}_tasks.md` and `execution_state.md` go in `docs/features/<feature>/`
(`FEATURES_DIR` in `config.env`), review reports in `docs/reviews/` (`review_brief.md` §B7), research answers in
`docs/research/`.

Convergence rules (`implement`):
- **C1** only Critical/High block · **C2** Medium/Low are deferred and triaged once · **C3** from round 2 on, only a
  delta review of the fix · **C4** from round 2 on, a new blocker that is not a regression stops the run and asks the
  user.

Stop after the spec step and review the spec before decomposing and implementing.
