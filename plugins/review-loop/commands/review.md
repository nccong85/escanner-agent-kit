---
description: Review the current diff with the routed reviewers, validate every rule ID, filter blocking findings through review-filter, and aggregate one verdict.
argument-hint: "[optional: path or scope]"
---

Project files live in `.claude/review-loop/` (create them with `/review-loop:init`): `review_brief.md`,
`review_rules.md`, `routing.md`, the pitfalls file. Reports go to the reports directory named in
`review_brief.md` Part B §B7.

## Step 1 — Determine scope
Use `$ARGUMENTS` if given; otherwise review the working-tree diff (`git status`, `git diff`), including
untracked files.

## Step 2 — Route
Group the changed files by directory and pick reviewers from the **Reviewer** column of
`.claude/review-loop/routing.md`, **plus every overlay gate** the diff triggers. Do not restate the mapping
here — `routing.md` is authoritative.

## Step 3 — Launch concurrently
Launch the matched agents in parallel. Open every prompt with:

```
Read `.claude/review-loop/review_brief.md` FIRST — Part A replaces your orientation step, Part B is the
binding protocol: only Critical/High block, diff-only scope, stay in your column (§B4, see routing.md),
report ≤120 lines / ≤8 findings. Every finding MUST carry `rule: <ID>` from
`.claude/review-loop/review_rules.md`, plus `severity:` and `confidence:`. A finding with no resolvable ID
is dropped. Never file a MECHANIZED rule (§3).
End with: ACTION: QA_PASSED (blocking=0, deferred=<n>) or ACTION: ISSUES_FOUND (blocking=<n>, deferred=<n>).
```

## Step 4 — Validate + filter
**Gate 1 — rule IDs, deterministic, no model call:**
```
validate_rule_ids.sh <every rule ID in every report>
```
Drop the findings whose IDs print `UNKNOWN`, then recount `blocking`.

**Gate 2 — precision filter.** For each surviving blocking (Critical/High) finding, launch
`review-loop:review-filter` in parallel, one per finding, passing only `rule` · `severity` · `confidence` ·
`file:line` · the one-sentence `claim` · the cited hunk — **never the reviewer's reasoning or report**.
`NOT_REAL` → drop and record. `NEEDS_EVIDENCE` → defer; it is not a blocker. `REAL` → keep at the filter's
severity (it may downgrade, never upgrade).

Report the funnel — raised → survived validate → survived filter — so the cost of the review is visible.

## Step 5 — Aggregate
Summarize by severity (Critical → High → Medium → Low) across all reports and list the report paths.
Deduplicate: two reviewers describing the same defect is one finding — keep the owning column's version
(§B4). Report `blocking` and `deferred` as separate counts; never present a deferred finding as a blocker.
