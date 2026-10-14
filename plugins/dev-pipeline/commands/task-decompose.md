---
description: Break a validated spec into single-layer tasks with checkable Definitions of Done, contract-first ordering, and the execution_state.md checkpoint /dev-pipeline:implement resumes from.
argument-hint: "<path-to-spec-file>"
---

# Task Decompose

**Input:** the spec at `$ARGUMENTS`.
**Output (same folder as the spec):** `{feature}_tasks.md` and `execution_state.md`.

## Step 1: Read the spec
Extract the feature name, the layers, the **contract impact** (none | abi | wire | api) and the dependencies.

## Step 2: Write the task breakdown
```markdown
# Task Breakdown: {Feature Name}
**Source:** {spec-path}
**Generated:** {YYYY-MM-DD}

## Task 1: {Title}
**Layer/Dir:** {path prefix from routing.md}
**Agent:** {coder from routing.md, e.g. my-plugin:dev-x} | main session
**Dependencies:** None | Task X

### Requirements
- {from the spec}

### Implementation Details
{guidance; "See spec Section X.Y" is allowed}

### Definition of Done
- [ ] {named command from Part A} passes — pasted output required
- [ ] Follows the reference pattern named in the spec
- [ ] (contract task) interop test added and passing
- [ ] (hot path) within budget; numbers reported
- [ ] Output: SELF-CHECK block, then ACTION: REVIEW_REQUIRED
```

**Write a DoD the reviewer can grade against.** Each line is checkable from the diff alone: a named command, test,
budget or invariant. It is passed verbatim to the reviewer, and closing the task needs the pasted output of every
command it names.

### Sizing and boundary rules
- **One task, one layer**, so it routes to one agent. Take the agent from the **Coder** column of
  `.claude/review-loop/routing.md`; do not restate the mapping.
- **Contract-first (when contract impact ≠ none):**
  1. Task 1 changes the contract (header, wire-format section, API shapes). Agent: the contract owner. It blocks
     every per-layer task.
  2. Then the per-side updates, each depending on Task 1.
  3. Then an interop-test task (round-trip across the boundary, cross-platform vectors plus negative tests).
- Security-sensitive tasks are always reviewed by the security gate.
- Prefer larger cohesive tasks; split only across layers or for contract-first ordering.

## Step 3: Initialize `execution_state.md`
```markdown
# Execution State: {Feature Name}
**Status:** PENDING
**Last Updated:** {YYYY-MM-DD HH:mm}
**Spec:** {spec-path}  |  **Tasks:** {feature}_tasks.md
**Contract impact:** none | abi | wire | api

## Pipeline State
- **Current Task:** Task 1: {Title}
- **Step:** IMPLEMENT
- **Fix Iteration:** 0/2
- **Review Round:** 1
- **Pre-fix snapshot:** (none)
- **Last ACTION:** (none)
- **Files:** (none)
- **Report:** (none)
- **Next Action:** Launch {agent} to implement Task 1

## Progress
- [ ] Task 1: {Title}

## Accumulative File List

## Current Issues (BLOCKING only — Critical/High)
| File | Issue | Severity |
|------|-------|----------|

## Deferred Findings (Medium/Low + filtered-out + out-of-diff — triaged once at the end)
| Rule | File | Severity | Summary | From report | Task | Outcome |
|------|------|----------|---------|-------------|------|---------|

## Cost Ledger
| Task | Review rounds | Raised | Survived validate | Survived filter | Fix rounds | Report lines |
|------|---------------|--------|-------------------|-----------------|------------|--------------|

## Resume Instructions
Start from Task 1, Step 1 (Implement).
```

Status values: `PENDING` `- [ ]` · `IN_PROGRESS` `- [ ] … (iteration X/2)` · `QA_PASSED` `- [x] … (QA_PASSED)` ·
`BLOCKED` `- [ ] … (BLOCKED: reason)`.

## Step 4: Validate
```
validate_spec_refs.sh {folder}/{feature}_tasks.md
```
Every cited path must exist and every `**Agent:**` must be declared in `routing.md` (or exist in `.claude/agents/`).
Then check: one session per task, contract-first ordering, one layer per task, the checkpoint format, dependencies
ordered foundation → features.

## Step 5: Report
The task count, whether contract-first applies, the two files created, and the next step:
`/dev-pipeline:implement <spec path>`.
