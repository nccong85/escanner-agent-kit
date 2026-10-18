**English** · [Tiếng Việt](architecture.vi.md) · [日本語](architecture.ja.md)

# Architecture

## Design goals
1. **A bounded loop.** No pointless review rounds.
2. **Real findings.** A false finding (a finding is a defect a reviewer reports) costs a coder run plus a re-review.
3. **Facts are not duplicated.** Agents that each re-learn the project waste tokens.

## Components

| Component | Role | Deterministic? |
|---|---|---|
| `review_brief.md` Part A | Project facts every agent reads first | — |
| `review_brief.md` Part B | The protocol: severity gate, scope, delta review, ownership, report cap, hand-off | — |
| `review_rules.md` | Closed set of rule IDs | — |
| `routing.md` | Directory → agent, overlay gates, ownership | — |
| `validate_rule_ids.sh` | Drops findings whose rule ID does not exist | **yes** |
| `validate_findings.sh` | Drops findings that cite things that are not there | **yes** |
| `validate_spec_refs.sh` | Fails specs/tasks that cite missing files or unknown agents | **yes** |
| `validate_citations.sh` | Flags dead or fabricated URLs | **yes** |
| `block_destructive_git.sh` | Blocks git commands that discard uncommitted work | **yes** |
| `finding-checker` | Judges one finding against one changed section of the diff (hunk) | model |
| Area reviewers and gates | Review the diff | model |
| `device-tester` + drivers | Runs the build on real phones and reports evidence per case | drivers **yes**, agent model |

## Why each rule exists

- **Only Critical/High block.** Medium/Low are deferred and triaged once in the final review. Otherwise every
  round produces new nits and the count never converges.
- **Delta review from round 2.** The re-review checks only the fix. A defect round 1 missed is handled later
  instead of extending the loop.
- **A new blocker that is not a regression stops the run.** If a correct fix still surfaces new blockers, the
  spec is wrong, and more code changes will not fix it.
- **Rule IDs.** Structured output fixes a finding's *format*, not its *truth*. Requiring an existing rule stops
  reviewers from inventing standards.
- **The filter sees only the claim and the hunk.** A reviewer that reads the author's reasoning is led by it, and
  a second opinion is only worth having if it is independent. The filter is asymmetric: recall-first for data
  loss, privacy and crashes, evidence-first for performance, precision-first for everything else.
- **One agent owns each kind of defect.** Only one agent files findings on each concern. Two reviewers filing the
  same finding doubles the cost and creates contradictory fixes.
- **Fixed hand-off blocks.** The orchestrator parses `ACTION:` lines instead of guessing.
- **Compare with a snapshot, not a commit.** Code is usually not committed between tasks, so `git diff <sha>..`
  is always empty. So before the coder edits, the pipeline snapshots the files with `git stash create`. After the
  edit it compares with the snapshot to get exactly what was just changed. If the coder edited a file outside the
  task's scope, the pipeline restores its old content from the snapshot. The snapshot does not include newly
  created files, so reviewers also get a list of them.
