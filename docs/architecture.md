# Architecture

## Design goals
1. **The loop must end.** A review → fix → review cycle that keeps finding new things is the default failure of
   multi-agent review.
2. **Findings must be real.** A false blocking finding costs a coder run plus a re-review.
3. **Facts are written once.** Every agent re-deriving the project from scratch is slow and drifts.

## Components

| Component | Role | Deterministic? |
|---|---|---|
| `review_brief.md` Part A | Project facts every agent reads first | — |
| `review_brief.md` Part B | The protocol: severity gate, scope, delta review, ownership, report cap, hand-off | — |
| `review_rules.md` | Closed vocabulary of rule IDs | — |
| `routing.md` | Directory → agent, overlay gates, ownership | — |
| `validate_rule_ids.sh` | Drops findings whose rule ID does not resolve | **yes** |
| `validate_spec_refs.sh` | Fails specs/tasks that cite missing files or unknown agents | **yes** |
| `validate_citations.sh` | Flags dead or fabricated research URLs | **yes** |
| `block_destructive_git.sh` | Blocks git commands that discard uncommitted work | **yes** |
| `review-filter` | Judges one finding against one hunk | model |
| Area reviewers and gates | Review the diff, one column each | model |

## Why each rule exists

- **Only Critical/High block.** Medium/Low are deferred and triaged once at the end. Otherwise every round
  produces new nits and the loop never converges.
- **Delta review from round 2.** The re-review checks the fix, not the feature. A defect round 1 missed goes to
  follow-up; it does not extend the loop.
- **A new blocker that is not a regression stops the run.** If a correct fix keeps surfacing new blockers, the
  spec is wrong, and iterating on code will not fix it.
- **Rule IDs.** Structured output fixes the *format* of a finding, not its *truth*. Requiring a pre-existing rule
  stops reviewers from inventing standards, and a script can enforce it for free.
- **The filter sees only the claim and the hunk.** A reviewer that reads the author's reasoning anchors on it;
  independence is the value of a second opinion. The filter is asymmetric: recall-first for data loss, privacy
  and crashes, evidence-first for performance, precision-first for everything else.
- **Exclusive ownership.** Two reviewers filing the same finding doubles the cost and creates contradictory fixes.
- **Fixed hand-off blocks.** The orchestrator parses `ACTION:` lines instead of guessing from prose.
- **Snapshots, not SHAs.** Teams that do not commit between tasks get an empty `git diff <sha>..`. The pipeline
  diffs against a `git stash create` snapshot and restores out-of-scope edits from it.

## Relation to published guidance

- Anthropic's [multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system):
  multi-agent work costs roughly 15× a chat and pays off for parallel, breadth-first work. Here coders run
  sequentially per task; only read-only reviewers run in parallel.
- Cognition's [Don't build multi-agents](https://cognition.com/blog/dont-build-multi-agents): parallel agents
  that write code make conflicting decisions. Here no two agents write the same layer at the same time, and
  subagents answer narrow questions.
- Claude Code's [subagent](https://code.claude.com/docs/en/sub-agents) and
  [plugin](https://code.claude.com/docs/en/plugins-reference) references define the formats used here.
