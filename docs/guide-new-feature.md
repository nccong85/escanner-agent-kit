**English** · [Tiếng Việt](guide-new-feature.vi.md)

# Guide: building a new feature with the agents

This walkthrough takes one feature, **"pin/unpin notes"**, through the whole pipeline. Every output quoted below
comes from a real run on a small test project (a Flutter notes app with a C++ engine). Use it as a map: your
project facts, agents and rules will differ.

## Before you start

> **This kit is a reference base, not a finished product.** It shows how to structure agents, rules and a review
> loop. Copy the patterns, then adapt the agents, the rule vocabulary and the routing to your project. The agents
> in `flutter-native` will not fit your codebase unchanged.

> **Running agents costs a lot of tokens.** One feature launches a coder, several reviewers, one filter call per
> blocking finding and possibly fix rounds, each a separate session on a strong model. Use a **Claude Max
> subscription** (Claude Code with a Max plan); on pay-per-token API billing the same run gets expensive quickly.
> For small changes, skip the pipeline (see the last section).

> **Most tokens go to long main sessions, not to the agents.** The main session re-sends its whole context on every
> turn. Measured over a month on e-Scanner, sessions that grew past 400k tokens of context were 92% of all tokens;
> all subagents together were about 2%. So:
> - `/clear` when you switch to an unrelated task. It costs nothing: the pipeline's state lives in
>   `execution_state.md`, not in the conversation.
> - Keep auto-compact well below the window (for example `/autocompact 200k`, or `"autoCompactWindow": 200000`
>   in `~/.claude/settings.json`), especially with a 1M-context model.
> - `implement` already stops after each task so the next one starts in a fresh session.

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
`claude plugin update <plugin>@escanner-agent-kit` (add `--scope local` for local installs). With local installs in
several projects, the update can report "already at the latest version" for a second project that still runs the
old copy. Check `claude plugin list` in that project; if the version is old, uninstall and reinstall the plugin
there. Local installs are recorded per project path, so a moved project folder needs the same reinstall.

Inside the project, run `/review-gate:init`. It creates `.claude/review-gate/` and drafts the project facts from
your code. Then **settle every `<VERIFY>` it leaves**. This step decides the quality of every later review:

| File | What you must check |
|---|---|
| `review_brief.md` Part A | Layout, commands that really run, budgets with units, non-negotiables you actually enforce |
| `routing.md` | Which agent codes and which reviews each directory; which gates fire on which paths |
| `review_rules.md` | Budget rows (`R-BUD-*`) and what your lints/tests already enforce (MECHANIZED) |
| `common_pitfalls.md` | Replace the example with your first real defect class |

In the test run, `init` found the real layout, drafted five non-negotiables from the existing code, and marked as
`<VERIFY>` everything it had to assume (budgets, test command, reports directory).

**Already have these files** (or symlinks to your own docs)? `init` copies only missing files and drafts only into
the files it just created; for the rest it prints suggestions. To check that a re-run left them alone:

```bash
shasum .claude/review-gate/* > /tmp/before.sha    # before /review-gate:init
shasum .claude/review-gate/* | diff /tmp/before.sha - && echo unchanged   # after
```

## 1. Write the spec: `/dev-pipeline:spec-create "<feature>"`

```
/dev-pipeline:spec-create Add pin/unpin for notes: a pinned note always sorts above unpinned ones,
the pinned flag persists through NotesRepository, and pinning failures go through ErrorReporter.
```

It works in plan mode, reads Part A and the nearest existing code, asks you 5–7 questions (contract, security,
performance, scope, reuse), and writes `docs/features/<feature>/spec_<feature>.md`.

> **About the demo run:** it was non-interactive, so the command answered its own questions with the most
> conservative option and recorded them as decisions. In normal use **you** answer them, and that is where most of
> this step's value comes from.

What a good spec looks like, from the test run:
- **7 goals, each with a proof**, e.g. *"G3 — a pinned note always sorts above every unpinned note … proven by
  the tests `pinnedFirst puts every pinned note before every unpinned note` and `… keeps relative order within
  each group`"*. "Works correctly" is never a criterion.
- **A Non-Goals section** (UI, a concrete repository, ordering by pin time, optimistic updates). It is mandatory:
  the validation step checks scope creep against it.
- **Decisions recorded** (12, made by the model in this demo, e.g. *persist first, update the list only after
  success*; *one error code `pin_failed`, fixed contexts `notes.pin` / `notes.unpin`*).
- **Budget exceptions written down.** An answer beyond a Part A budget goes into §3 as one line:
  `Exception to <rule name>: <accepted limit>, scoped to <path or operation>, approved by the owner <YYYY-MM-DD>`.

**Stop here and read the spec.** This is the human gate: answering the questions and correcting the spec is much
cheaper than correcting code later.

## 2. Gate the spec: `/dev-pipeline:spec-validate <spec>`

Six objective conditions. Commands settle three (the reference script and two greps); the model judges the other
three. Test run result:

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
- **A Definition of Done the reviewer can grade**: pasted `flutter analyze` (0 issues) and
  `flutter test test/features/notes/notes_controller_test.dart` output, named tests, and diff-checkable rules
  (mounted guard after `await`, `on Object catch` → `ErrorReporter.record`, literal contexts).
- **Contract-first ordering** when an ABI, wire format or API changes (not the case here).
- The validation gaps folded into the task (an extra required test, the known limitation written down).
- **`**Gate:** owner approval — <what>`** on a task that needs a build, a device run or a bench only you may
  approve. `implement` stops before that task until you say yes.
- **Device tasks** (routed to `device-e2e:device-tester`) run on real phones. The report warns if
  `.claude/device-e2e/project.md` is missing or unfilled; run `/device-e2e:init` and fill it.

## 4. Build it: `/dev-pipeline:implement <spec> [--continuous]`

The orchestrator reads `execution_state.md` on every turn, so you can stop and resume at any point. For each task
it dispatches the coder, then the reviewers from `routing.md` plus any gate the diff triggers. It validates every
rule ID, checks that each blocking finding's quote is really at its `file:line` (Gate 1b), sends each survivor
through `finding-checker`, and runs at most two fix rounds with delta reviews. Each fix round starts from a
`git stash create` snapshot, which the delta review diffs against.

By default it **stops after each task** and prints `/clear  then  /dev-pipeline:implement <spec>`. Run that: the
next task starts in a fresh session and loses nothing. `--continuous` runs every task in one session; use it for
two or three short tasks.

What happened in the test run:

| Step | Result |
|---|---|
| Coder (`flutter-coder`) | Changed exactly the three files the spec allows; wrote 11 tests |
| Its hand-off | `SELF-CHECK` block, then `ACTION: REVIEW_REQUIRED` with the file list |
| Reviewer (`flutter-reviewer`) | `QA_PASSED (blocking=0, deferred=1)`: round 1, so no fix round and no filter calls |
| Evidence re-run by the orchestrator | `flutter analyze` → *No issues found!* · `flutter test …` → *+11: All tests passed!* |
| Cost ledger in `execution_state.md` | 1 review round · 1 finding raised (+2 without a rule ID) · 0 fix rounds |

The one deferred finding shows what review is for. The reviewer showed that a "controller disposed during save"
test **could not fail** (it removed the `mounted` guard and every test still passed) and filed it as `R-DOD-3`,
Medium, so it did not block. The orchestrator then listed it for triage with a one-line fix.

Things to watch in your own runs:
- **Read the deferred list.** Medium/Low findings never block, so nobody fixes them unless you decide to.
- **Reviewers can edit through `Bash`, and must not.** In this run the reviewer removed a line to prove its point
  and put it back. That breaks §B2 of the brief (reviewers never modify files, not even temporarily): the reviewer
  should describe the mutation check in the finding and let the coder run it. Run `git diff --stat` after a review.
- **Findings without a rule ID are discarded** by design. If the same kind keeps coming up, add a rule or a
  pitfall entry.
- **Tool installation matters.** The coder could paste real test output only because Flutter was on `PATH`. If a
  command cannot run, the Definition of Done line must say `UNVERIFIED`, never "passed".

## 5. Close the feature

- **Run `implement` once more after the last task.** This run is the feature-wide audit (Step 5): it reviews only
  what crosses tasks (files touched by two or more tasks, contracts, files with deferred findings), lists the
  deferred findings for triage, and allows one fix round.
- **Triage the deferred findings once.** Medium/Low findings never caused a fix round; at the end, decide for each:
  fix now, file as tech debt, or drop. Record the outcome. Rules whose findings keep getting dropped are noise;
  delete them from `review_rules.md`.
- **Graduate repeats into tests.** A finding class seen twice becomes a guard test or a lint, and a new defect
  class becomes a `common_pitfalls.md` entry.
- **Commit yourself.** The pipeline never commits.

## If the run stops

| Stop | Meaning | What you do |
|---|---|---|
| `Task n/N done … Continue in a fresh session` | The planned session boundary: one task per session keeps the context, and so the token cost, small | `/clear`, then `/dev-pipeline:implement <spec>`. Add `--continuous` for a small feature you want in one go |
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
- **Exploration or a prototype:** the loop optimizes a finished change, not discovery.
- **Research questions:** `/dev-pipeline:research "<question>"` answers inline when it can and spawns
  `tech-researcher` only for depth or breadth questions.
