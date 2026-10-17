# Designing the e2e cases: complete, and nothing twice

A device case costs minutes to hours; a missed case costs a field bug. So the plan is built from the test basis by
a fixed procedure, every item is traced both ways, and a script checks the result before any device time is spent.
The technique names follow ISTQB CTFL 4.0 §4 and the mobile conditions CT-MAT §2.

Terms (test basis, coverage item, oracle, BLOCKED vs NOT RUN, …) are defined in `glossary.md`. Write the plan from
`${CLAUDE_SKILL_DIR}/e2e_test_plan.template.md`, then run
`validate_e2e_plan.py <plan> --spec <spec>` (exit 0 = no finding). The owner approves the plan together with the
device time, before the run.

Contents: [Two modes](#two-modes) · [The procedure](#the-procedure) (1 basis, 2 risk, 3 factors, 4 state × event,
5 technique, 6 push down, 7 platforms, 8 write, 9 oracle, 10 dedupe, 11 budget, 12 close) ·
[Oracles that can fail](#oracles-that-can-fail) · [Results](#results)

## Two modes

- **Feature:** the basis is one spec. Depth follows risk.
- **Release:** the basis is the user-visible change list (what's-new, store notes) plus the diff since the last
  release. Cases come in three groups, in this order: **confirmation** (each fixed bug, reproduced on the old build
  first), **regression** of the areas the diff touches, and a **smoke** pass of everything else. A release plan
  always has one **upgrade over existing data** case: install the previous release, create data, upgrade, check it.

## The procedure

1. **Collect the basis, from three sources.** Every item gets a Ref in the plan's *Test basis* table:
   - the spec's goals and acceptance criteria (`G1`, `G2`, …);
   - the Part A budgets and non-negotiables of `.claude/review-gate/review_brief.md` that the changed code can
     break (a 1 s budget is a case even when no goal names it);
   - the change list: each user-visible change and each changed area of the diff (`CH-1`, …), and each fixed bug
     (`BUG-…`).
   Trace both ways: a diff change that maps to no goal and no case is a gap, not an unlisted extra.
2. **Rate the risk** of each item High / Medium / Low with one line of why (what breaks, for how many users).
   Risk sets the depth: High gets every state transition and 3-value boundaries; Low gets one main path.
3. **List the factors the code path varies on.** A factor enters the plan only when the code branches on it.
   Language is a factor for tokenizing and OCR, not for a cache or a scheduler. Write the partitions
   (`Latin`, `CJK`), not every value: one value per partition is enough ("each choice"). For two or more real
   factors, use pairwise, and all combinations only for a High item.
4. **Draw the state × event table** for every long-running or background task (import, indexing, sync, export).
   States: idle, running, paused, done, failed, as the task has them. Events: Home, lock, OS kills the process,
   user swipes the app away, camera or another app in front, phone call, upgrade, permission revoked, no network.
   Every cell holds a case ID, `below: <test>`, or `n/a: <reason>`. An empty cell is an untested transition.
   OS kill and user swipe are different events: Android keeps saved state after a system kill
   (`adb shell am kill <pkg>` from the background) and clears it after a swipe or force-stop; iOS drops restored
   state when the user force-quits.
5. **Pick a technique per item** and name its coverage items in the *Covers* column:
   `EP-<partition>`, `BV-<value>` (boundary and its neighbour; 0 pages, the size limit), `DT-<column>` for a
   decision table when conditions combine, `ST-<state>×<event>` from step 4, `ER-<guess>` for error guessing from
   past bugs. Add the failure inputs: a file the app must reject, a page that fails, a scanned image next to a PDF.
6. **Push down what a lower level proves.** Validation, parsing, ranking, empty states and layout belong in unit
   or widget tests. Keep on the device only what needs it: OS lifecycle, background execution, the platform's OCR
   and file picker, real file sizes, upgrade over real data, permissions. Each pushed-down item cites the test
   that proves it (`file::name`) in *Covered below e2e*, and the test exists today. No such test, or one "to be
   created" → keep it on the device. The same holds for `below:` cells in step 4.
7. **Choose platforms per case.** Shared code → `both`. Code in one platform's layer (a Kotlin-only fix) →
   that platform only. A platform skipped for any other reason goes to *Not covered*.
8. **Write the cases.** Chain steps that share a costly setup into one case, or one group of cases on one setup,
   each step with its own expected result. In e-Scanner every interruption case re-imported a 300-page fixture and
   waited for indexing, and the run took about 7 hours. When several cases list the same costly precondition
   ("fixture A imported fresh"), either share one setup or say in the precondition why each needs its own (for
   example, the event under test ends the task, so the next case cannot reuse it). Split wherever an early failure would hide the later
   checks, and keep one invalid transition per case. A shortened variant ("quick") is its own row with its own
   Expected; running a case shorter than planned makes it `BLOCKED`.
9. **Give every case an oracle that can fail** (rules below), and say in *Expected* what number or state makes it
   FAIL.
10. **Remove duplicates.** A case whose every coverage item is also covered by another case goes. The validator
    flags it.
11. **Budget the device time.** Give each case its `Min` (device minutes per platform, from the last run where
    there is one) and an `Order` that puts High risk first, and plan the run steps `READY`, `DRY` and `DIAG`.
    The total must fit the **Device budget**; cut by Order and list what was cut under *Not covered*. A run that
    runs out of time stops at a case boundary and marks the rest `NOT RUN: budget`. In e-Scanner the device work
    of a release took 50 minutes inside 11 hours of waiting for cable, unlock and the owner; `READY` checks that
    before the first case, and `DIAG` (the whole run's diagnostics) found the one real bug no case planned for.
12. **Close the plan.** Every basis Ref is in a case's *Traces to*, in *Covered below e2e*, or in *Not covered*
    with a reason and who accepted the risk. Run the validator; then the review checklist at the end of the
    template.

## Oracles that can fail

These rules come from cases that passed while proving nothing:

- **Write a number or a state.** "Coverage ≥ before", "eventually", "works", "a record exists" cannot fail.
  Write "coverage = 40/40 pages within 60 s", "timing record ≤ 1 000 ms", "the card shows page 3".
- **Observe during the interruption, not only after.** Read progress just before leaving, right after coming
  back, and at the end. Read after the return only, and you cannot tell background progress from progress made
  after the reopen.
- **Prove the precondition you mean to test.** "Leave the app mid-task" is only tested if the task was mid-way
  when you left. Measure progress *before* the interruption and mark the case BLOCKED (not PASS) if the work had
  already finished. A slow probe can finish the work for you. Prove staging the same way (the fixture is the
  regenerated one, on this phone), and, for a fix, that the old build fails the case.
- **Measure progress where it happens.** If the user-visible signal lags the work (search finds a page tens of
  seconds after OCR finished it), a probe of that signal says the task is mid-way when it is already done. Read
  progress from the app's own record (diagnostics, log, a progress field), and check in `DRY` that the record
  has what you need. In an e-Scanner trial the search probe said 22 to 27 of 48 pages at Home; the diagnostics
  showed all 48 OCR calls done 1 s before Home, so the case was BLOCKED.
- **Probe progress cheaply.** If the work is sequential, binary-search checkpoints (about 5 probes) instead of
  probing every one.
- **Use tokens the device reads reliably.** On-device OCR misreads look-alike characters (one engine read `0`
  after letters as `O`), so letter+digit tokens produce false FAILs on one platform only. All-digit tokens and
  real words are safer.
- **Match the right item.** Results can include the user's real data; check the fixture's own title too, and
  allow for truncated names in grids (`abc…xyz.pdf`).
- **Assert absence structurally.** "The removed thing is gone" must look for something that would come back with
  it (an icon, a key), not for the deleted literal string, and never on a page that is blank anyway: such a test
  can never fail. Mutation-check new assertions when cheap.
- **Read the app's own record.** After an interruption pull the app's diagnostics or log file and count the
  failure events it recorded.

## Results

Every planned ID gets one row per platform in the results table: `PASS`, `FAIL`, `BLOCKED` or `NOT RUN` with the
reason. A run that did not meet the plan's condition (a quick variant, another language, the wrong build) is
`BLOCKED`, never PASS. A bug found outside the plan gets a new case in the plan before it is reported, so the next
run repeats it. `validate_e2e_plan.py <plan> --results <summary>` checks all of this.
