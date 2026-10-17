---
description: Implement a validated spec by orchestrating coder and reviewer agents through a review loop that terminates, checkpointed in execution_state.md.
argument-hint: "<path-to-spec-file> [--continuous]"
---

# Execute Specification

Implement the specification at: $ARGUMENTS (the first token is the spec path; `--continuous` is a flag, see
"Session boundary" below).

**Pre-2.0 project:** if `.claude/review-gate/` does not exist but `.claude/review-loop/` does, stop and ask the
user to run `/review-gate:init` first; it moves the folder and rewrites the old agent names.

## ⚠️ RULE: Read Pipeline State EVERY Turn (NON-NEGOTIABLE)

**BEFORE doing anything, ALWAYS read `execution_state.md` in the spec folder.**

The `## Pipeline State` section is the SINGLE SOURCE OF TRUTH — not your memory of the
conversation. If context was compressed, this file has your full recovery state.

1. Read `execution_state.md` → `## Pipeline State` → `Next Action`.
2. Execute that action immediately.
3. After the agent returns → update `## Pipeline State` → execute the next action.

**If `execution_state.md` not found** → run `/dev-pipeline:task-decompose` first.

**Renamed agents.** If `execution_state.md` or `{feature}_tasks.md` names an agent that no longer exists, look it
up in the "Legacy names" section of `.claude/review-gate/routing.md`, dispatch the new name, and update that line of
Pipeline State.

---

## Context Management
- Agents return a summary only; full reports go to file.
- Update Pipeline State BEFORE launching the next agent.
- **Compact prompts:** pass only spec path, task requirements, file list. No conversation history.
- **Compression recovery:** re-read `execution_state.md` → Pipeline State tells you where to resume.
- **Every agent prompt cites `.claude/review-gate/review_brief.md`** so the agent skips re-deriving the
  project's layout, commands and budgets. That orientation cost is otherwise paid again by every agent
  in every round.

## Session boundary: one task per session (default)

The main session re-sends its whole context on every turn, so its cost grows with its length, not with the work
left. A run that carries every task in one session ends up paying for all earlier tasks on each new turn. Measured
on a real project: the sessions that grew past 400k tokens of context were 92% of all tokens spent, and the
subagents were about 2%. Nothing the pipeline needs lives only in the conversation — `execution_state.md` holds
the state, the reports hold the findings — so a fresh session per task loses nothing.

So, unless `$ARGUMENTS` contains `--continuous`:
- When a task reaches Step 4 and its state is saved (task ticked, Pipeline State reset, `Next Action` naming the
  next task or Step 5), **stop** and print exactly:
  ```
  Task <n>/<total> done (<QA_PASSED | FINAL_QA_PARTIAL>, deferred=<d>). State saved in <path>/execution_state.md.
  Continue in a fresh session:  /clear  then  /dev-pipeline:implement <spec path>
  ```
- Never stop inside a task: its fix rounds resume the same coder by agent ID, and that ID lives in this session.
- Step 5 (the global audit) runs in its own session the same way, and the run ends after it.

With `--continuous`, skip the boundary and run Steps 1→4 for every task, then Step 5, in this session. Use it for
small features (two or three short tasks), where restarting costs more than it saves.

---

## ⚠️ CONVERGENCE RULES (the loop must terminate — these override everything below)

The failure mode this pipeline is built to avoid: *review → fix → review finds NEW issues → fix →
review finds NEW issues*, forever. Four rules make it terminate.

**C1 — Only Critical/High block.** Reviewers report `ACTION: … (blocking=<n>, deferred=<m>)` where
`blocking` counts **only Critical + High** (`review_brief.md` §B1). `blocking=0` is a PASS regardless of
how many Medium/Low were filed. Never launch a fix round for Medium/Low.

**C2 — Medium/Low go to `## Deferred Findings`, not to a coder.** Append them to that section of
`execution_state.md` (`file · severity · one-line summary · report path`). They are triaged **once**, at
the end of the feature, in Step 5 — not per task, not per round.

**C3 — Round ≥ 2 is a DELTA review.** The re-review prompt MUST carry the prior report path and the
list of findings the fix claims to close, and MUST instruct: *"Review only `git diff` of the fix. Verdict
each prior blocking finding CLOSED / NOT CLOSED. A new finding is blocking ONLY if the fix introduced it
(a regression). A pre-existing defect round 1 missed → Deferred, not blocking. Do not re-read files the
fix did not touch."*

**C4 — A brand-new blocking finding on round ≥ 2 that is NOT a regression means the SPEC is wrong, not
the code.** Do not spend a fix round on it. Save state, record it under `## Deferred Findings` as
`SPEC-DOUBT`, and stop to ask the owner (this is the one sanctioned exception to the no-stop rule below).

---

## Routing

**Route every coder/review dispatch by `.claude/review-gate/routing.md` (directory table + overlay gates).**
That file is authoritative; do not restate it here. It covers the coder agent, the review agent, the
contract-first / security / performance gates, and the mixed-directory (parallel-by-layer) rule. Apply the most-specific path prefix; apply EVERY overlay gate
that the changed files trigger, in addition to the base routing.

---

## Step 1: Implement

Launch the coder agent for the current task per the **routing.md (Coder column) + overlay gates**.

**Owner gate first.** A task marked `**Gate:** owner approval — <what>` in `{feature}_tasks.md` is not dispatched
until Pipeline State's **Owner approval** names that approval. Absent → Step=BLOCKED, save state, stop and ask the
owner for exactly `<what>` (sanctioned stop 3). When the owner says yes, record
`Owner approval: <what> — owner, <YYYY-MM-DD>` and put that line in the agent's brief, which is what an agent that
builds only on the owner's word (`device-e2e:device-tester`) looks for. The approval covers this task only: Step 4
clears it.

> **Prefer a packaged skill for standard setup work.** If the current task is a canonical, packaged
> procedure and the project has a skill for it (for example scaffolding a feature module, generating FFI
> bindings, or a coverage report), the skill encodes the maintained steps — use it instead of re-deriving them.
>
> **Only a coder that declares `Skill` in its `tools:` can invoke one itself.** For any other routed coder,
> **you** invoke the skill before dispatching and hand the result over in the brief; telling that agent to
> "invoke the skill" asks for a tool it does not have.
> A row whose coder column says **main session** is implemented by you directly — no dispatch.
> Skills assist; they do not replace the review gate — Step 2 still runs.

```yaml
Agent tool:
  subagent_type: <coder from routing.md, e.g. "my-plugin:dev-x">
  description: "Implement: [brief]"
  prompt: |
    Read `.claude/review-gate/review_brief.md` FIRST — Part A replaces your orientation step.
    Spec file: <SPEC_FILE_PATH>
    Implement: <TASK_REQUIREMENTS>
    If the task references "See spec Section X.Y", read the spec for full detail.
    Honor the contracts Part A names (ABI stability, byte-identical formats across platforms), its
    data-handling non-negotiables, and the named budgets — as amended by any `Exception to <rule>` line in the
    spec's §3 Performance / NFRs, within its scope only.
    SHIFT-LEFT — you are graded on exactly this list, so run it over your OWN diff before handing off:
      · review_brief.md Part A "Non-negotiables" (all 9)
      · .claude/review-gate/common_pitfalls.md — every entry that touches your layer
      · the task's own Definition of Done in {feature}_tasks.md
    Output MUST include, in this order:
      SELF-CHECK: one line per item above — ok / n/a / fixed <what> / open: <why>
      ACTION: REVIEW_REQUIRED
      FILES_TO_REVIEW: <list>
```

**Reject a hand-off with no `SELF-CHECK:` block** — re-prompt the same agent for it rather than paying a
review round to find what the coder could have caught itself.

**After agent returns:** record the coder's agent ID per layer as **Coder agent** in Pipeline State, then
update Pipeline State → route per the decision table below.

---

## Step 2: Code Review

Launch the review agent(s) per the **routing.md (Reviewer column) + overlay gates**. If the changed files span
multiple layers, or trigger an overlay gate, launch reviewers **in parallel**.

```yaml
Agent tool:
  subagent_type: <reviewer(s) from routing.md, plus every triggered gate>
  prompt: |
    Read `.claude/review-gate/review_brief.md` FIRST — Part A replaces your orientation step,
    Part B is the binding review protocol (severity gate, diff-only scope, ownership, report cap).
    Review these files: <FILES_TO_REVIEW>
    Round: 1 (full review of the diff).
    Acceptance criteria — the task's Definition of Done: <DOD_LINES>
    Approved budget exceptions (spec §3 Performance / NFRs, verbatim, or "none"): <EXCEPTION_LINES>
    Inside its scope an exception is the effective limit; beyond that limit it still blocks.
    Unresolved items the coder flagged: <OPEN_LINES_ONLY>
    Every finding MUST carry rule: <ID> from .claude/review-gate/review_rules.md, plus severity and
    confidence. No ID = the finding is dropped. Never file a MECHANIZED rule (§3).
    Focus: requirement fulfillment vs the Definition of Done, plus your own exclusive column
    per review_brief.md §B4. Do not file findings in another reviewer's column.
    Return COMPACT: blocking count + deferred count + report file path. Report ≤120 lines, ≤8 findings.
    Output MUST include: ACTION: QA_PASSED (blocking=0, deferred=<n>)
                      or ACTION: ISSUES_FOUND (blocking=<n>, deferred=<n>)
```

> **Give the reviewer the diff and the acceptance criteria — NOT the coder's reasoning.** Pass only the
> `open:` lines of the SELF-CHECK block; the orchestrator consumes the rest as a hand-off gate. A
> reviewer that reads *why* the coder believes the code is right anchors on that framing, and the
> independence of the second opinion is the entire source of its value.

**Round ≥ 2 uses the DELTA prompt instead (rule C3).** `<PRE_FIX_SNAPSHOT>` is the SHA from Pipeline State.
If it is `(none)`, the fix ran without a snapshot and there is no base to diff: do not build one from the coder's
own backups. Run a round-1 (full) review of `<FILES_IN_FIX>` instead, still passing the prior report and the
findings the fix claims to close so each gets its CLOSED / NOT CLOSED verdict, and write `no pre-fix snapshot` in
the Pipeline State's Last ACTION so the miss is on record. With no base, a new blocking finding cannot be shown to
predate the fix: route it as a regression (next fix round, iteration cap applies), never as C4 `SPEC-DOUBT`.

```yaml
Agent tool:
  subagent_type: <same reviewer as round 1>
  prompt: |
    Read `.claude/review-gate/review_brief.md` §B3 — this is a DELTA re-review, not a fresh review.
    Prior report: <PRIOR_REPORT_PATH>
    Blocking findings the fix claims to close: <LIST>
    Approved budget exceptions (same lines as round 1, or "none"): <EXCEPTION_LINES>
    Fix diff: `git diff <PRE_FIX_SNAPSHOT> -- <FILES_IN_FIX>` (working tree vs the pre-fix snapshot;
    NOT `<sha>..`, which compares commits and is empty in this never-committed tree). Files the fix
    created are untracked and absent from the snapshot — read them whole: <NEW_FILES>.
    Review ONLY these hunks plus their direct callers.
    1. Verdict each prior blocking finding: CLOSED / NOT CLOSED (with file:line).
    2. A NEW finding is blocking ONLY if this fix introduced it (a regression). A pre-existing defect
       round 1 missed → list under "Follow-up (out of diff)", deferred, NOT blocking.
    3. Do not re-read files the fix did not touch. Do not re-litigate anything already deferred/waived.
    Output MUST include: ACTION: QA_PASSED (blocking=0, deferred=<n>, regressions=<n>)
                      or ACTION: ISSUES_FOUND (blocking=<n>, deferred=<n>, regressions=<n>)
```

> `regressions=<n>` is required on **both** verdicts, not just the failing one. Rule C4 routes on
> whether a round-≥2 finding is a regression, so the orchestrator needs that count even when the delta
> review passes — otherwise a pass carries no record that zero regressions were looked for.

**Check the report file first** (every round, delta included). The hand-off must name a report path that exists.
A reviewer that returned its findings inline, or named a path that is not there, is re-prompted once (resume it
with `SendMessage`): "Write your report to the `review_brief.md` §B7 path with the Write tool and reply with the
path." Still no file → save its inline reply to the §B7 path yourself, note `report saved by orchestrator` in
Pipeline State, and go on. The Cost Ledger, Gate 1b and the next delta review all read that file.

**After agent returns:** run Step 2b, THEN update Pipeline State → route per the decision table.
`blocking=0` → treat as QA_PASSED and move on, however many `deferred` came back (rule C1).

---

## Step 2b: Validate + Filter the findings (it removes whole fix rounds)

Never route a raw reviewer verdict into a fix round. Three gates, in order:

**Gate 1 — rule IDs (deterministic, no model call).**
```
validate_rule_ids.sh <every rule ID in the report>
```
Exit 1 → drop the findings whose IDs printed `UNKNOWN`, and recount `blocking`. A finding that cannot
name a pre-existing rule is an invented one; it does not get a coder.
Exit 2 → the project's review files are broken (the `FATAL` line names the missing file), not the findings.
Drop **no** finding: save state with Step=BLOCKED, and stop and report the `FATAL` line to the owner.

**Gate 1b — cited code, deterministic, no model call.** Pass every blocking finding's `file:line` and `quote`:
```
validate_findings.sh --base <SNAP, or HEAD on round 1> <file:line> '<quote>' [<file:line> '<quote>' ...]
```
`NO_FILE` / `NO_LINE` / `NO_QUOTE` → drop the finding: it points at code that is not there.
`MISSING_QUOTE` → never drop on that alone: re-prompt the same reviewer once for the quote (resume it),
then re-run this gate; still missing → treat it as `NO_QUOTE`.
`OUT_OF_DIFF` → keep it and pass `scope: out-of-diff` to the filter (a cross-file contract finding is
legitimate there; scope drift is not); every other survivor gets `scope: in-diff`.

**Gate 2 — the precision filter.** For each surviving **blocking** finding, launch `review-gate:finding-checker`
**in parallel, one per finding**. **Run the filter on the strongest model you have** (a smaller-model pass once returned `NOT_REAL` on a true observation — deleting a true finding is the one error here that
cannot be recovered, so the tier buys correctness where it matters most).

> **What that costs, stated honestly.** The stage is no longer cheap *because of the model*. It is
> cheap **because of the context**: one filter call sees a single claim plus its hunk — a fraction of
> what a reviewer or a coder loads. Compare against what it prevents: a fix round is a coder run **plus**
> a delta re-review, i.e. two full-context runs, plus the measured risk that editing otherwise-clean code
> introduces new defects. First live run: 9 filter passes removed or downgraded 4 findings, so 4
> fix-round items never happened. Keep the funnel numbers in the Cost Ledger — the day filtering stops
> paying for itself, that table is where it will show.

```yaml
Agent tool:
  subagent_type: "review-gate:finding-checker"
  prompt: |
    rule:       <ID>
    severity:   <Critical|High>
    confidence: <high|medium|low>
    file:line:  <where>
    scope:      <in-diff | out-of-diff, from Gate 1b>
    claim:      <the one-sentence claim ONLY — not the reviewer's reasoning or report>
    hunk:       <the cited diff hunk + enclosing function>
```

- `NOT_REAL` → drop the finding; record it in `## Deferred Findings` with `outcome: rejected`.
- `NEEDS_EVIDENCE` → if the finding is Critical/High **and** the command the filter named runs on this
  machine without a build or a device (a unit test, a small probe, a host-side native bench), run it now
  and act on its output: it reproduces the defect → `REAL` (it enters the fix round); it does not →
  `## Deferred Findings` with the command and its output attached — never `NOT_REAL`, because a probe
  that misses can be a weak probe, and deleting a true finding is the one unrecoverable error here.
  Every other `NEEDS_EVIDENCE` → `## Deferred Findings` (it is not a blocker); if it names a bench or
  device run, surface that to the owner at Step 5.
- `REAL` → it enters the fix round, at the filter's severity (the filter may downgrade, never upgrade).

Recount `blocking` from the survivors. **If `blocking` reaches 0 here, the task passes** — the review
round cost one cheap filter pass instead of a coder round-trip plus a re-review.

Skip Gate 2 only when `blocking=0` already.

---

## Step 3: Fix Issues (max 2 iterations)

Before dispatching, split the report: **Critical/High → this fix round. Medium/Low → `## Deferred
Findings` in `execution_state.md`, and they are NOT sent to the coder** (rule C2).

**Take the pre-fix snapshot** — the tree is uncommitted, so `HEAD` does not move between tasks:
```
SNAP=$(git stash create); SNAP=${SNAP:-$(git rev-parse HEAD)}
git ls-files --others --exclude-standard > <scratchpad>/untracked_before_fix.txt
```
`git stash create` writes a commit object of the tracked working tree without touching the tree or the
stash list (the destructive-git hook allows it). Record `SNAP` as **Pre-fix snapshot** in Pipeline State;
the delta re-review and the out-of-scope revert both use it.

**No fix coder is dispatched while Pre-fix snapshot is `(none)`** — every fix round takes a fresh one, the
Step 5 audit fix included. A snapshot taken after the fix is useless: it already contains the fix.

**Resume the coder that wrote the code** — `SendMessage` to the **Coder agent** ID recorded for that layer,
with the prompt below minus the brief line. It keeps its own reads and reasoning, so the fix round skips
re-orientation. Dispatch a fresh coder only when no ID is recorded, the issue is in another layer, the
earlier run ended partial (turn cap or compaction), or the session was restarted.

```yaml
Agent tool:
  subagent_type: <coder agent per the directory of the issue files>
  prompt: |
    Read `.claude/review-gate/review_brief.md` FIRST (Part A replaces orientation).
    Fix ONLY these blocking findings from <REPORT_FILE_PATH>: <CRITICAL_AND_HIGH_LIST>
    Do NOT fix, refactor, or "while I'm here" anything else in the report or the file — the Medium/Low
    findings are deliberately deferred to the end-of-feature triage. Every extra line you touch buys
    another review round.
    Keep the fix minimal and local. If a finding is wrong, say so with evidence instead of complying.
    HARD CONSTRAINT: do not modify any file that has no blocking finding against it. Editing
    already-clean code is a measured source of NEW defects — the allowed file list is exactly:
    <FILES_WITH_BLOCKING_FINDINGS>
    Output MUST include: SELF-CHECK block, ACTION: REVIEW_REQUIRED, FILES_TO_REVIEW list.
```

**Verify the constraint after the coder returns** — `git diff --name-only <SNAP>` plus any untracked
file not in `untracked_before_fix.txt` must be a subset of the allowed list. A file outside it was touched
without a finding to justify it: restore it with `git show <SNAP>:<path> > <path>` (a file the fix newly
created: delete it), then re-prompt. **Never** `git checkout -- <path>` / `git restore`: they reset to
`HEAD` and erase the earlier tasks' uncommitted work in that file (the hook blocks them).

**Mixed directories:** launch coders in parallel, one per layer, each given only its issues.
**Iteration cap is 2, not 3** — a third round has historically produced new findings rather than
convergence. At iteration ≥ 2 still blocking: save state, set `FINAL_QA_PARTIAL`, report to the owner.

---

## Step 4: Mark Done

**DONE requires pasted evidence, never a claim.** For each command named in the task's Definition of
Done, paste the actual tail of its output — the pass/fail counts, the analyzer's issue count, the bench
number. "Builds", "analyze clean", "tests pass" as bare assertions do not close a task: a suite that
compiles but never executed proves nothing (this repo has been bitten — ~74 `RunnerTests` accumulated
over four review rounds without ever running). If a command could not be run, mark the DoD line
`UNVERIFIED: <why>` and say so in the completion report rather than implying it passed.

Update `execution_state.md`:
- Current task `- [ ]` → `- [x] ... (QA_PASSED, deferred=n)` **with the pasted counts beneath it**
- Append files to Accumulative File List
- Move any Medium/Low from `## Current Issues` into `## Deferred Findings` (they do not block DONE)
- Append the task's row to `## Cost Ledger`
- Reset Pipeline State for next task (Step = IMPLEMENT, Round = 1, Iteration = 0, clear files/report/snapshot/owner
  approval)

**Pending tasks remain** → the session boundary (stop and print the resume line), or with `--continuous` Step 1
for the next task. **All done** → the session boundary, then Step 5 in the next session (`--continuous`: Step 5 now).

> Contract-impact gate: a task that changed an ABI header may only be marked DONE
> after the FFI roundtrip test passes; a task that changed the encrypted wire format may only be
> marked DONE after the cross-platform CP-vectors + negative tests pass. If not run, run them first.

---

## Step 5: Global Feature Audit (ONE fix iteration)

Every file here already passed a per-task review. The audit exists to catch what **per-task review
structurally cannot see: interactions between tasks.** Re-reviewing everything is pure duplicated cost.

1. **Narrow the audit set** — from the Accumulative File List, take only:
   - files touched by **≥ 2 different tasks** (the integration surface), plus
   - contract / interface files (ABI headers and bindings, wire formats, API
     shapes, shared `core/`/`shared/` APIs), plus
   - any file listed in `## Deferred Findings`.
   State the count you audited vs the full list, so the narrowing is visible and not silent.
2. Launch review agents **in parallel by layer** per routing.md + overlay gates, with
   the audit prompt scoped to *cross-task* concerns: contradictory assumptions between tasks, a
   contract one task changed and another still assumes, duplicated logic, dead code left by a later task.
3. **Triage `## Deferred Findings` here — once.** Present them to the owner grouped by severity with a
   recommendation (fix now / file as tech debt / drop). Do not silently fix them all.
4. `blocking > 0` → take the pre-fix snapshot exactly as in Step 3 (`SNAP` + the untracked list, recorded in
   Pipeline State) → **one** fix round (route by layer, parallel if mixed) → one delta re-review against that
   `SNAP`.
   Still blocking after that → save, status `FINAL_QA_PARTIAL`, notify owner.
5. `blocking = 0` → status `FINAL_QA_PASSED` → notify owner (report the deferred count, don't hide it).

---

## Checkpoint Format

```markdown
# Execution State: {Feature Name}
**Status:** IN_PROGRESS | COMPLETE | FINAL_QA_PASSED
**Last Updated:** {YYYY-MM-DD HH:mm}
**Spec:** {path}  |  **Tasks:** {feature}_tasks.md
**Contract impact:** none | abi | wire | api

## Pipeline State
- **Current Task:** Task 2: Image enhance filter
- **Step:** REVIEW (IMPLEMENT → REVIEW → FIX → DONE)
- **Fix Iteration:** 1/2
- **Review Round:** 1 (round ≥2 = DELTA review, rule C3)
- **Pre-fix snapshot:** (`git stash create` SHA, set before dispatching a fix; delta review + revert use it)
- **Owner approval:** (none) | <what> — owner, <YYYY-MM-DD> (only for a task marked `**Gate:** owner approval`)
- **Last ACTION:** REVIEW_REQUIRED
- **Files:** native/src/enhance.cpp
- **Report:** (none yet)
- **Next Action:** Launch my-plugin:cpp-engine-expert (review mode) to review the files above

## Progress
- [x] Task 1: enhance ABI + binding regen (QA_PASSED)
- [ ] Task 2: Image enhance filter

## Accumulative File List
- native/include/engine_api.h
- native/src/enhance.cpp

## Current Issues (BLOCKING only — Critical/High, being fixed this round)
| File | Issue | Severity |
|------|-------|----------|
| ... | ... | ... |

## Deferred Findings (Medium/Low + filtered-out + out-of-diff — triaged ONCE in Step 5)
| Rule | File | Severity | Summary | From report | Task | Outcome |
|------|------|----------|---------|-------------|------|---------|
| R-PIT-9.3 | ... | Medium | ... | review_..._20260812_1030.md | Task 2 | pending |
| R-BUD-enhance | ... | High | ... | (filter: NEEDS_EVIDENCE) | Task 2 | pending |

`Outcome` is one of `pending` / `fixed` / `rejected` / `dropped`. It is the only signal that tells us
which rules earn their keep: a rule ID whose findings come back mostly `rejected`/`dropped` across
features is noise and gets deleted from `review_rules.md` (§4 there).

## Cost Ledger (what the pipeline actually cost — the original complaint was unmeasurable)
| Task | Review rounds | Raised | Dropped: rule IDs | Dropped: quotes | Survived filter | Fix rounds | Report lines |
|------|---------------|--------|-------------------|-----------------|-----------------|------------|--------------|
| Task 1 | 1 | 6 | 1 | 0 | 2 | 1 | 96 |

Report lines = the sum of the reviewer report lines for the task, across all rounds; the coder (agent or main
session) does not count. The two `Dropped` columns are the only evidence that the deterministic gates earn their place: a gate that drops
0 across 10 recorded tasks is a candidate for removal, the same as a rule nobody cites.

## Resume Instructions
Continue from Task 2, Step 2 (Review).
```

---

## If Blocked
1. Save Pipeline State immediately.
2. Report: "Saving progress. X completed, Y remaining."
3. Resume with `/dev-pipeline:implement <spec-path>` (reads Pipeline State to continue).

---

## ⚠️ ORCHESTRATOR: AUTO-ROUTING DECISION TABLE (MUST FOLLOW)

**YOU are the orchestrator. After EVERY agent returns:**
1. **UPDATE Pipeline State** in `execution_state.md`.
2. **EXECUTE the next action** immediately.

**DO NOT stop. DO NOT ask the user. DO NOT summarize and wait.**

| You received | Update Pipeline State to | Then IMMEDIATELY |
|---|---|---|
| Task whose coder column is **main session** | Step=IMPLEMENT | Implement it yourself (no dispatch), print your own `SELF-CHECK:` block, then continue exactly as if a coder had returned `ACTION: REVIEW_REQUIRED` with your file list. |
| `ACTION: REVIEW_REQUIRED` (+ SELF-CHECK) | Step=REVIEW, Files=list, Round=1 | Record the file list. Launch review agent(s) by directory + overlay gates (parallel if files span layers or trigger a gate), passing the SELF-CHECK block. |
| `ACTION: REVIEW_REQUIRED` with **no** SELF-CHECK | Step unchanged | Re-prompt the same coder for the SELF-CHECK block. Do not spend a review round on it. |
| `ACTION: QA_PASSED (blocking=0, …)` | Step=DONE | Append any `deferred` to `## Deferred Findings`. Run the interop test if a contract task; → Step 4, then the session boundary (`--continuous`: next task or Step 5). |
| `ACTION: ISSUES_FOUND (blocking=0, deferred=n)` | Step=DONE | **This is a PASS (rule C1).** Append the n findings to `## Deferred Findings` and move on. Do NOT launch a fix round. |
| `ACTION: ISSUES_FOUND (blocking≥1)`, round 1 | — (run Step 2b FIRST) | Validate rule IDs → drop `UNKNOWN`; filter each survivor via `review-gate:finding-checker`. Recount. `blocking=0` after filtering → treat as QA_PASSED. Otherwise Step=FIX, Iteration++, take the Step 3 snapshot, launch coder(s) with **only** the filtered C/H list and the allowed-file list. |
| `ACTION: ISSUES_FOUND (blocking≥1, regressions=0)`, round ≥2, with a **new** blocking finding | Step=BLOCKED | **Rule C4** — the new blocking finding is not a regression, so the spec is suspect. Save state, record as `SPEC-DOUBT`, **stop and ask the owner.** |
| `ACTION: ISSUES_FOUND (blocking≥1, regressions≥1)`, round ≥2 — or the only blocking findings are prior ones verdicted `NOT CLOSED` | Step=FIX, Iteration++ | Take a fresh Step 3 snapshot, then fix the regressions plus every prior finding verdicted `NOT CLOSED`, nothing else. At Iteration ≥ 2 → `FINAL_QA_PARTIAL`, report to owner. |
| An agent reports `BLOCKED` with a reason (instead of an `ACTION:` or `E2E:` line) | Step=BLOCKED | Save state with the reason, **stop and report it to the owner** (sanctioned stop 3). Do not retry or re-route: the agent stopped on purpose, e.g. no owner approval, a phone in use, or a missing project file. |
| No recognized ACTION | Analyze output | ① Extract file paths → FILES. ② "no issues"/"passed"/blocking=0 → treat as QA_PASSED. ③ blocking issues + report path → ISSUES_FOUND. ④ files but no result → REVIEW_REQUIRED. ⑤ still unclear → save state, report to owner. |

**VIOLATION: Returning to the user after an ACTION without launching the next agent is FORBIDDEN** —
except for the six sanctioned stops below.
**VIOLATION: Asking "should I proceed?" is FORBIDDEN. The answer is always YES** — except at those stops.

**The six sanctioned stops** (1–5 are signals the loop cannot fix by iterating; 6 is planned):
1. **Rule C4** — a new non-regression blocking finding on round ≥ 2 (the spec, not the code, is wrong).
2. Fix iteration cap reached with blocking issues open → `FINAL_QA_PARTIAL`.
3. **A gate the pipeline cannot pass on its own:** a contract/crypto gate that needs a device or an interop run it
   cannot perform; a task marked `**Gate:** owner approval` with no approval recorded; or an agent that reported
   `BLOCKED` with a reason.
4. Two reviewers filing **contradictory** blocking findings on the same line — iterating just alternates
   between them. Report both and let the owner pick.
5. A deterministic validator exits 2 (`FATAL`): the project's review files are missing or a symlink is broken.
   Iterating cannot fix that, and dropping findings over it would hide them.
6. **Session boundary** — a task just reached DONE and its state is saved (not with `--continuous`). Print the
   resume line and stop; do not ask whether to continue.

Otherwise this is a fully autonomous pipeline within a task: Steps 1→2→3→4 run without stopping, then the
session boundary hands the next task to a fresh session (with `--continuous`, every task and Step 5 run here).
An ABI/wire change is not DONE until its interop test passes, and the data-handling non-negotiables in Part A
are never traded away.

## Pipeline
```
/dev-pipeline:spec-create → spec-validate → task-decompose → implement
```
