**English** · [Tiếng Việt](guide-new-feature.vi.md)

# Guide: building a new feature with the agents

This walkthrough takes one example, **"pin/unpin notes"**, through the whole pipeline. Every output quoted below
comes from a real run on a small test project (a Flutter notes app with a C++ engine).
Use it as a reference: your project facts, agents and rules will differ.

## Before you start

> **This kit is a reference base, not a finished product.** It shows how to structure agents, rules and the review
> process. Copy the patterns, then adapt the agents, the rule vocabulary and the routing to your project. The agents
> in `flutter-native` will not fit your codebase unchanged.

> **Running agents costs a lot of tokens.** One feature launches a coder, several reviewers, one filter call per
> finding and possibly fix rounds. Use a **Claude Code Max plan**; do not run the kit on pay-per-token API billing.

## 0. One-time setup per project

```bash
claude plugin marketplace add nccong85/escanner-agent-kit
claude plugin install review-gate@escanner-agent-kit
claude plugin install dev-pipeline@escanner-agent-kit
claude plugin install flutter-native@escanner-agent-kit   # or your own stack plugin
```
Add `--scope local` to keep the plugins to one project. For tests on real phones, also install
`device-e2e@escanner-agent-kit` and run `/device-e2e:init` in the project.

**Updating later:** run `claude plugin marketplace update escanner-agent-kit`, then
`claude plugin update <plugin>@escanner-agent-kit` (add `--scope local` for local installs).
Check `claude plugin list` in that project; if the version is still old, uninstall and reinstall the plugin
there.

Inside the project, run `/review-gate:init`. It creates `.claude/review-gate/` and drafts the project facts from
your code. Then **settle every `<VERIFY>`**. This step decides the quality of every later review:

| File | What you must check |
|---|---|
| `review_brief.md` Part A | Layout, commands that really run, budgets with units, non-negotiables you actually enforce |
| `routing.md` | Which agent codes and which reviews each directory; which gates fire on which paths |
| `review_rules.md` | Budget rows (`R-BUD-*`) and what your lints/tests already enforce (MECHANIZED) |
| `common_pitfalls.md` | Replace the example with your first real defect class |

`init` finds the real layout and marks as `<VERIFY>` everything it had to assume.

## 1. Write the spec: `/dev-pipeline:spec-create "<feature>"`

```
/dev-pipeline:spec-create Add pin/unpin for notes: a pinned note always sorts above unpinned ones,
the pinned flag persists through NotesRepository, and pinning failures go through ErrorReporter.
```

It works in plan mode, reads Part A and the nearest existing code, asks you 5–7 questions (contract, i.e. the
interface between parts; security; performance; scope; reuse), and writes `docs/features/<feature>/spec_<feature>.md`.

> **About the demo run:** it was non-interactive, so the command answered its own questions with the most
> conservative option and recorded them as decisions. In normal use **you** answer them, and that is where most of
> this step's value comes from.

What a good spec looks like:
- **7 goals, each with a proof**, e.g. *"G3 — a pinned note always sorts above every unpinned
  note … proven by the tests `pinnedFirst puts every pinned note before every unpinned note` and `… keeps relative
  order within each group`"*.
- **A Non-Goals section** (UI, a concrete repository, ordering by pin time, optimistic updates). It is mandatory:
  the validation step checks scope creep against it.
- **Decisions recorded** (12, made by the model in this demo, e.g. *persist first, update the list only after
  success*; *one error code `pin_failed`, fixed contexts `notes.pin` / `notes.unpin`*).
- **Budget exceptions written down.** An answer beyond a Part A budget goes into §3 as one line:
  `Exception to <rule name>: <accepted limit>, scoped to <path or operation>, approved by the owner <YYYY-MM-DD>`.

**Confirm the spec.** This is the human gate.

## 2. Gate the spec: `/dev-pipeline:spec-validate <spec>`

The six conditions:

| # | Gate | Result |
|---|---|---|
| 1 | `validate_spec_refs.sh` exits 0 (14 paths checked) | ✓ |
| 2 | Non-Goals present and non-empty | ✓ |
| 3 | Every goal has a diff-checkable acceptance criterion | ✓ |
| 4 | Open Questions empty | ✓ |
| 5 | Contract, security, performance, licence checks pass | ✓ |
| 6 | No red flags | ✓ |

It also reported four non-blocking gaps worth reading: a missing test for one decision, an unhandled
`load()`/`setPinned` race to document as a known limitation, Flutter not on `PATH`, and a wrong fact in Part A.
The verdict is saved next to the spec (`validation_<feature>_<timestamp>.md`). **Not Ready names the exact
condition that failed**; fix it and re-run.

## 3. Break it into tasks: `/dev-pipeline:task-decompose <spec>`

It writes `<feature>_tasks.md` and `execution_state.md` (the checkpoint `implement` resumes from). Check:
- **One task, one layer, one agent** from `routing.md`. The test run produced one task for
  `flutter-native:flutter-coder` and explained why: code and tests route to the same coder and reviewer, and the
  tests are the proof of five goals.
- **A Definition of Done (DoD) the reviewer can grade**: pasted `flutter analyze` and
  `flutter test test/features/notes/notes_controller_test.dart` output, named tests, and diff-checkable rules.
- **Contract-first ordering** when an ABI, wire format or API changes.
- The validation gaps folded into the task.
- **`**Gate:** owner approval — <what>`** on a task that needs a build, a device run or a bench only you may
  approve. `implement` stops before that task until you say yes.
- **Device tasks** (routed to `device-e2e:device-tester`) run on real phones. The report warns if
  `.claude/device-e2e/project.md` is missing or unfilled.

## 4. Build it: `/dev-pipeline:implement <spec> [--per-task]`

The orchestrator reads `execution_state.md` on every turn, so you can stop and resume at any point. For each task
it dispatches the coder, then the reviewers from `routing.md` plus any gate the diff triggers. It validates every
rule ID and runs at most two fix rounds with a review of the changes (delta review).

Add `--per-task` to stop after each task, so the next task runs in a fresh session.

What happened in the test run:

| Step | Result |
|---|---|
| Coder (`flutter-coder`) | Changed exactly the three files the spec allows; wrote 11 tests |
| Its hand-off | `SELF-CHECK` block, then `ACTION: REVIEW_REQUIRED` with the file list |
| Reviewer (`flutter-reviewer`) | `QA_PASSED (blocking=0, deferred=1)`: round 1, so no fix round and no filter calls |
| Evidence re-run by the orchestrator | `flutter analyze` → *No issues found!* · `flutter test …` → *+11: All tests passed!* |
| Cost ledger in `execution_state.md` | 1 review round · 1 finding raised (+2 without a rule ID) · 0 fix rounds |

Things to watch in your own runs:
- **Read the deferred list.** Medium/Low findings never block, so nobody fixes them unless you decide to.
- **Findings without a rule ID are discarded.** If the same kind keeps coming up, add a rule or a
  pitfall entry.

## 5. Finish the feature

- **Step 5 is the feature-wide audit** (with `--per-task`, run `implement` once more after the last task): it reviews only
  what crosses tasks (files touched by two or more tasks, contracts, files with deferred findings), lists the
  deferred findings for triage, and allows one fix round.
- **Triage the unfixed findings.** Medium/Low findings are not fixed; at the end, decide for each:
  fix now, file as tech debt, or drop. Record the outcome. Rules whose findings are noise: delete them from
  `review_rules.md`.
- **Handle repeated defects.**
  - If a defect keeps recurring, record it in `common_pitfalls.md`.
  - If a defect already in `common_pitfalls.md` still occurs, add a test (or turn on a lint) so
    `flutter test`/`analyze` reports it.
- **Commit yourself.** The pipeline never commits.

## If the run stops

| Stop | Meaning | What you do |
|---|---|---|
| `Task n/N done … Continue in a fresh session` | Only with `--per-task`: one task per session keeps the context, and so the token cost, small | `/clear`, then `/dev-pipeline:implement <spec> --per-task` |
| `SPEC-DOUBT` (rule C4) | A new blocking finding on round ≥ 2 that the fix did not cause | The spec is wrong or incomplete. Fix the spec, then resume |
| `FINAL_QA_PARTIAL` | Two fix rounds and still blocking | Read the open findings; fix by hand or change the spec |
| Contradictory reviewers | Two reviewers want opposite changes on the same line | Decide which column owns it (`routing.md`) |
| Waiting for owner approval | The next task has `**Gate:** owner approval` and none is recorded | Say yes (or no); the approval is recorded in Pipeline State for that task only |
| An agent reported `BLOCKED` | It stopped on purpose (no approval, a phone in use, a missing project file) | Fix the reason it names, then resume |
| `FATAL` (validator exit 2) | A review file is missing or a symlink is broken | Fix the file or link (or re-run `/review-gate:init`), then resume |
| Needs a device or interop run | The pipeline cannot run it | Run it yourself and paste the output, or for a device run route the task to `device-e2e:device-tester` (`/device-e2e:init`) |
| Session ended / context lost | — | Run `/dev-pipeline:implement <spec>` again; it reads `execution_state.md` |

## When to skip the pipeline

- **A small fix or one-file change:** make it in the main session, run the analyzer and the scoped tests, then
  `/review-gate:review` on the diff. That gives the same validator and filter without spec and tasks.
- **Research or a prototype:** the loop optimizes a finished change, not discovery.
