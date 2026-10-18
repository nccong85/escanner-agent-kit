# E2E test plan: <feature or release>

**Mode:** <feature | release> · **Spec:** <path> · **Build under test:** <version, commit>
**Device budget:** <minutes> min · **Approved by:** <owner, date: the plan and the device time>

The procedure is `references/test-design.md`. Check with `validate_e2e_plan.py <this file> --spec <spec>`.
No `|` inside a cell.

## Test basis

| Ref | Source | Item | Risk | Why this risk |
|---|---|---|---|---|
| G1 | spec §2 | <goal or acceptance criterion> | H | <what breaks, for whom> |
| BUD-<name> | review_brief Part A | <budget the changed code can break> | M | <why> |
| CH-1 | change list / diff | <user-visible change or changed area> | M | <why> |

## Factors

| Factor | Partitions | Why the code path depends on it |
|---|---|---|
| <language> | <Latin, CJK> | <tokenizer splits CJK by character> |

## State × event

<task, e.g. indexing>

| State | Home | Lock | OS kill | User swipe | Upgrade |
|---|---|---|---|---|---|
| running | <E1> | <E2> | <E3> | <E4> | <n/a: reason> |
| done | <below: file::name> | <n/a: reason> | <n/a: reason> | <n/a: reason> | <E5> |

## Run steps

Planned once per platform, outside the cases, with a results row each.

| Step | What | Min |
|---|---|---|
| READY | cable or tunnel up, phone unlocked, WDA authorized, no old suite process (`pgrep -fl <suite>`), owner reachable; record every phone setting the run will change (stay-awake, IME, language) so cleanup puts back what was there | <5> |
| DRY | one cheap case end to end, and each new assertion made to fail once (mutation check) | <15> |
| DIAG | pull the app's diagnostics for the whole run; count failure events by kind | <5> |

## Cases

`Min` is device minutes per platform; `Order` is run order (1 first, a cut run drops the highest). Cases that need
the same costly setup share it as one group (*Precondition* names the group), unless a failure in one would hide
the next. A shortened variant is its own row with its own Expected.

| ID | Traces to | Covers | Risk | Platforms | Min | Order | Precondition (proven by) | Steps | Expected (FAIL when) | How checked |
|---|---|---|---|---|---|---|---|---|---|---|
| E1 | G1 | ST-running×Home | H | both | <15> | <1> | <40-page fixture staged, progress < 50 % read before Home> | <import, Home at 10 pages, wait 60 s, reopen> | <coverage read on return > coverage read before Home; 40/40 within 120 s> | <diagnostics file count, UI tree> |

## Covered below e2e

| Ref or item | Test that proves it (file::name) |
|---|---|
| <G2> | <test/search/ranking_test.dart::ranks exact match first> |

## Not covered

| Ref or item | Why | Risk accepted by |
|---|---|---|
| <CH-3> | <no iPhone with a passcode-free setup> | <owner, date> |

## Review checklist

- [ ] Every basis Ref is in a case, in *Covered below e2e*, or in *Not covered*; every case traces to a Ref.
- [ ] Each diff change maps to a basis Ref (release: the change list and the diff were both read).
- [ ] Every factor changes the code path; partitions, not values.
- [ ] Every State × event cell is filled.
- [ ] Every Expected names the number or state that fails it; preconditions are proven, not assumed.
- [ ] Platforms follow the code: shared → both, one platform's layer → that platform.
- [ ] Release: confirmation cases ran red on the old build; one upgrade-over-data case.
- [ ] The total of Min fits the Device budget; Order puts High risk first; costly setup is shared, or the
      precondition says why a case needs its own.
- [ ] Every pushed-down test exists today (`file::name`), none "to be created".

## Results

The results summary (path in `project.md`) has this layout. `validate_e2e_plan.py <plan> --results <summary>`
checks it. Status words are defined in `references/glossary.md`. Evidence files go in `evidence/` next to the
summary, named `<ID>_<platform>_<n>.<ext>` (screenshot, UI-tree dump, the app's diagnostics file, a pulled result
file, a log). Every case PASS cites at least one of them by its path; a number read on the device goes in the cell
next to the file it was read from.

```markdown
# E2E results: <feature>, <YYYY-MM-DD>

**Build:** <version (build number)>
**Commit:** <sha>
**Devices:** <iPhone model, iOS x.y · Android model, Android x>
**Date:** <YYYY-MM-DD>
**Plan:** <path to this plan>

| ID | Platform | Status | Evidence |
|---|---|---|---|
| READY | ios | PASS | <what was checked> |
| E1 | ios | <PASS · FAIL · BLOCKED · NOT RUN> | <numbers and evidence/E1_ios_1.png; BUG-n for a FAIL; the reason for BLOCKED or NOT RUN> |

## Defects

### BUG-1: <title>
- **Case:** <E1 ios>
- **Build:** <version>
- **Device:** <model, OS>
- **Severity:** <S1 data loss or crash · S2 feature broken · S3 degraded · S4 cosmetic>
- **Steps:** <numbered, from a fresh state>
- **Expected:** <the plan's Expected>
- **Actual:** <numbers, what the screen showed>
- **Evidence:** <evidence/ paths: screenshot, logcat, diagnostics>
- **Harness ruled out by:** <screenshot at the failure, activity log, independent check of the file>

## Not verified
- <what the run could not show, and why>

## Result files
- <per-run result files; aborted runs deleted>

E2E: ios pass=<n> fail=<n> blocked=<n> not_run=<n> · android pass=<n> fail=<n> blocked=<n> not_run=<n>
```

The counts are over the cases, not the run steps.
