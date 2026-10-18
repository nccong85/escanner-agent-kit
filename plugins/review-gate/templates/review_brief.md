# Review Brief — <PROJECT NAME> (BINDING for every reviewer and coder agent)

Read this file FIRST, before any orientation grep.

- **Part A** replaces the "orient / discover the project" step. Everything in it is already verified — do not
  re-derive it from the manifest, lint config or docs. Grep only for what Part A does not answer, and only for
  the files in the diff.
- **Part B** is the protocol. Where it conflicts with anything in your own agent file, **Part B wins.**

> Fill every `<…>` below with facts you have checked against the code. A wrong fact here is worse than a
> missing one: every agent will trust it. Keep Part A short; link to longer documents instead of copying them.

---

# Part A — Project facts (do not re-derive)

## Layout
| Concern | Path |
|---|---|
| <feature code> | `<path/**>` |
| <shared code> | `<path/**>` |
| <tests> | `<path/**>` |

## Stack (already chosen — never propose alternatives)
<Languages, frameworks, state management, persistence, build tools — with the versions you pin.>

## Commands
| Step | Command |
|---|---|
| Analyze / lint (must be 0 issues) | `<command>` |
| Unit tests (scope to the touched files) | `<command>` |
| Codegen (if any) | `<command>` |
| Other suites | `<command>` |

## Budgets (cite these, do not re-derive)
<Named performance / size / memory budgets, each with its unit and how it is measured. Give each a key
that `review_rules.md` §2 lists as `R-BUD-<key>`.>

## Non-negotiables (all layers)
1. <Rule. Keep each one testable: someone must be able to point at a line that breaks it.>
2. <Rule.>
3. <Rule.>

## Defect corpus and evidence
- **`<pitfalls file>`** holds Symptom → Cause → Rule entries. Read the ones for the diff's layer and cite them as
  `R-PIT-<n>` or `R-PIT-<n>.<m>`. Add a new entry when you fix a novel class of defect.
- **Verify API claims against the installed source** (package cache, SDK, vendored headers, lockfile pin), never
  from memory. If you cannot reach the source, mark the claim unverified.

Rule vocabulary: `review_rules.md`. Agent ownership and routing: `routing.md`.

---

# Part B — Protocol: review + hand-off (overrides your agent file on conflict)

## B0. Every finding cites a rule ID — no ID, no finding
`review_rules.md` is the closed vocabulary. Each finding MUST carry `rule: <ID>` from it. The orchestrator runs
the plugin's `validate_rule_ids.sh` on every ID and **drops** the ones that do not resolve — deterministically,
without a model call. A concern you cannot map to an ID goes under `## Follow-up (out of diff)` as prose; it
never counts as `blocking`.

- **Never file a MECHANIZED rule** (`review_rules.md` §3). Those are analyzer errors or executing guard tests —
  they cannot regress silently, so a finding about them is noise.
- **Spend findings on global properties** that only a reader of the whole system can catch: cross-module
  contracts, ABI/wire parity, key lifecycle, async ordering, cross-task assumptions, whether the requirement is met.

Each finding also carries `confidence: high | medium | low`. The bar is asymmetric: recall-first for data-loss,
privacy and crash-class rules and anything Critical (report even at low confidence); evidence-first for
`R-BUD-*` (a number and a run frequency, or the marker `needs a bench`); precision-first for everything else
(drop it unless you can point at the line).

## B1. Severity gate — only Critical/High block
| Severity | Meaning | Effect |
|---|---|---|
| **Critical** | data loss · secret/plaintext leak · memory unsafety · crash · provable budget violation · broken security invariant | blocks |
| **High** | incorrect lifecycle · module-boundary break · missing dispose/free · budget risk on a hot path with no measurement | blocks |
| **Medium** | maintainability, weak typing, avoidable cost within budget, missing coverage on a non-critical path | deferred |
| **Low** | style, naming, citation drift, cleanups | deferred |

`QA_PASSED` is the **expected** outcome when no Critical/High survives. Never inflate a severity to force a round.

## B2. Scope — the diff, and nothing else
- Review only the diff. A defect that pre-dates it, or lives in an untouched file, goes under
  `## Follow-up (out of diff)` and never counts in `blocking`.
- Do not propose refactors, extra tests or hardening the task did not ask for.
- **Reviewers never modify files**, not even temporarily to prove a point. If a claim needs a mutation or compiler
  check, describe the check in the finding; the coder or the orchestrator runs it.
- On ambiguity: state it and name the evidence that would settle it. Block only on a provable violation.

## B3. Round ≥ 2 is a DELTA review
When the orchestrator gives you a prior report, you are re-reviewing a **fix**:
1. Verdict each prior blocking finding `CLOSED` / `NOT CLOSED` (with file:line).
2. Review only the fix's hunks plus their direct callers (the orchestrator gives you the diff against its
   pre-fix snapshot and the list of files the fix created).
3. A new finding blocks **only if the fix introduced it**. A defect round 1 missed goes to Follow-up.
4. Do not re-litigate anything already accepted, deferred or waived.

## B4. Exclusive ownership — stay in your column
`routing.md` lists which agent owns each dimension. Outside your column, mention a concern in one line and
file no finding. Two reviewers filing the same finding is a defect of this protocol.

## B5. Report budget
Max **120 lines**, max **8 findings**, highest severity first (state how many you dropped). Each finding is
≤ 6 lines with exactly: `rule:` · `severity:` · `confidence:` · `file:line` · `quote:` (≤ 80 chars copied verbatim
from the cited lines — checked by `validate_findings.sh`) · why it is wrong · the one-line fix.
Cite `file:line`; never paste code back. The report file is the deliverable; the chat reply is the verdict line
plus ≤ 5 lines of summary.

## B6. Findings graduate into tests, or they get deleted
A finding class that recurs across 2+ reviews must become a guard test, lint or analyzer error — or be removed
from `review_rules.md`. A rule in a test is deterministic and free forever; a rule in a prompt is re-argued on
every diff.

## B7. Hand-off format (every agent ends with exactly this)
**Implementing:**
```
SELF-CHECK:            one line per Part A non-negotiable + each pitfalls entry for your layer
                       + each Definition-of-Done line: ok / n/a / fixed <what> / open: <why>
ACTION: REVIEW_REQUIRED
FILES_TO_REVIEW:
- <every file you created or modified>
```
An item you cannot satisfy is `open: <why>`. A hand-off without `SELF-CHECK:` is rejected.

**Reviewing:** write the report with the Write tool (never `echo`/redirection) to
`docs/reviews/review_{scope}_{agent}_{YYYYMMDD_HHmm}.md` (change the directory here if your project keeps reports elsewhere) — `{agent}` is your own name, so parallel reviewers
never overwrite each other. A read-only reviewer writes this one file and nothing else; the report is required even
when a harness default or the agent's own instructions discourage creating `.md` files. Then end with exactly one of:
```
ACTION: QA_PASSED (blocking=0, deferred=<n>)
ACTION: ISSUES_FOUND (blocking=<n>, deferred=<n>)
```
