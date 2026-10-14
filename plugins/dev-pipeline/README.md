# dev-pipeline

Spec → ship with a human gate after the spec and a review loop that ends. Requires `review-loop`.

| Command | Does |
|---|---|
| `/dev-pipeline:spec-create "<feature>"` | Plan-mode spec with diff-checkable acceptance criteria and mandatory Non-Goals. |
| `/dev-pipeline:spec-validate <spec>` | Six objective gate conditions, three settled by commands. Saves the verdict next to the spec. |
| `/dev-pipeline:task-decompose <spec>` | One-layer tasks with checkable Definitions of Done, contract-first ordering, and `execution_state.md`. |
| `/dev-pipeline:implement <spec>` | Coder → reviewers → validate → filter → fix (max 2) → delta review, resumable from `execution_state.md`. |
| `/dev-pipeline:research "<question>"` | Cost-tiered research; spawns `research-tech` only for depth/breadth questions; checks citations. |

Convergence rules (`implement`):
- **C1** only Critical/High block · **C2** Medium/Low are deferred and triaged once · **C3** round ≥ 2 is a delta
  review of the fix · **C4** a new non-regression blocker on round ≥ 2 stops the run and asks the user.

Stop after the spec: review it before decomposing and implementing.
