**English** · [Tiếng Việt](README.vi.md)

# dev-pipeline

Spec → ship, with a human gate after the spec and a review loop that ends. Requires `review-gate`: run
`/review-gate:init` and fill the Coder and Reviewer columns of `.claude/review-gate/routing.md` first, or
`implement` has no agent to dispatch.

| Command | Does |
|---|---|
| `/dev-pipeline:spec-create "<feature>"` | Plan-mode spec with diff-checkable acceptance criteria and mandatory Non-Goals. |
| `/dev-pipeline:spec-validate <spec>` | Six objective gate conditions, three settled by commands. Saves the verdict next to the spec. |
| `/dev-pipeline:task-decompose <spec>` | One-layer tasks with checkable Definitions of Done, contract-first ordering, and `execution_state.md`. |
| `/dev-pipeline:implement <spec> [--continuous]` | Coder → reviewers → validate → filter → fix (max 2) → delta review, resumable from `execution_state.md`. Stops after each task and prints `/clear` then the same command; `--continuous` stays in one session. After the last task, one more run does the feature-wide audit (Step 5). |
| `/dev-pipeline:research "<question>"` | Cost-tiered research; spawns `tech-researcher` only for depth/breadth questions; checks citations. |

| Agent | Does |
|---|---|
| `dev-pipeline:tech-researcher` | Researches one technical question with cited sources; dispatched by `research`. |

Files: specs, validation verdicts, `{feature}_tasks.md` and `execution_state.md` go in
`docs/features/<feature>/` (`FEATURES_DIR` in `config.env`), review reports in `docs/reviews/` (`review_brief.md`
§B7), research answers in `docs/research/`.

Convergence rules (`implement`):
- **C1** only Critical/High block · **C2** Medium/Low are deferred and triaged once · **C3** round ≥ 2 is a delta
  review of the fix · **C4** a new non-regression blocker on round ≥ 2 stops the run and asks the user.

Stop after the spec and review it before decomposing and implementing.
