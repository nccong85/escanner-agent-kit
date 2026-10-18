# Terms

One meaning each, used the same way in the plan, the results and the hand-off. Test-design terms follow the
ISTQB glossary (CTFL 4.0).

| Term | Meaning |
|---|---|
| Test basis | What the cases are derived from: spec goals, Part A budgets the change can break, the change list and diff, fixed bugs. Each item has a Ref. |
| Test condition | One testable aspect of a basis item ("indexing resumes after the app is backgrounded"). |
| Coverage item | One thing a technique says to exercise: a partition (`EP-`), a boundary (`BV-`), a decision-table column (`DT-`), a state × event cell (`ST-`), an error guess (`ER-`). |
| Test case | Preconditions, steps, expected result and how it is checked, for one or more coverage items. |
| Oracle | The check that decides PASS or FAIL. It names a number or a state, so it can fail. |
| Precondition (proven by) | The state the case needs, and the reading that shows it held when the case ran. |
| Run step | `READY` (devices usable), `DRY` (harness and assertions proven on one cheap case), `DIAG` (the whole run's diagnostics). Planned per platform, with a results row each. |
| PASS | The oracle held, the precondition was proven, and the evidence is cited. |
| FAIL | The oracle failed, triage ruled out the harness, and a `BUG-n` entry records it. |
| BLOCKED | The case started but could not be judged: precondition not met (the task had already finished), the plan's condition not met (shorter variant, other language, wrong build), a harness bug not fixed, or the device unusable. |
| NOT RUN | Not attempted: cut by the budget, not selected in the brief, or the run aborted before it. |
| Harness bug | The cause is in the drivers, app flows, fixtures or staging. Fix it and re-run; it is never a FAIL. |
| App bug | The app itself is wrong, with the harness ruled out. Reported as `BUG-n`; the agent does not fix it. |
| Confirmation test | Re-runs a fixed bug's case; it must have failed on the build before the fix. |
| Regression test | Re-tests an area the diff touches that was working. |
| Smoke test | One main path per area the change does not touch. |
| Evidence | A file in `evidence/` next to the results summary (screenshot, UI-tree dump, the app's file, a result file or log), cited by its path. A sentence is not evidence. |
| Severity | S1 data loss or crash · S2 feature broken · S3 degraded, with a workaround · S4 cosmetic. |
