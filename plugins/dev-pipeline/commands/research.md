---
description: Research a technical question and save a cited, confidence-tagged report — classified by cost tier, delegating to research-tech only when it pays.
argument-hint: "<research question(s)>"
---

Research the question(s) in `$ARGUMENTS` for this project.

## Step 1 — Classify BEFORE researching (this decides the bill)

Most questions here do not need an agent. Multi-agent research costs roughly **3–10× a single agent and
~15× a chat turn**, and Anthropic's own guidance is to default to one agent and to embed an explicit
budget so trivial questions don't get over-researched. Pick the cheapest tier that can actually answer.

| Tier | Signal | Spend | Example |
|---|---|---|---|
| **Repo-first** | The answer is in this repo — code, spec, lockfile, guide | **0 agents.** `Grep`/`Read`/`Glob` yourself | "Which version of library X is pinned? What is the current value of setting Y?" |
| **API lookup** | A named package/SDK's current API | **0 agents.** `context7`, then verify against the installed source | "Is API Z deprecated in the SDK version we build against?" |
| **Simple factual** | One external fact needing a source | **0–1 agents**, 3–10 searches | "Does the app store still accept target SDK N?" |
| **Depth** | One mechanism, needs real understanding | **1 agent**, 10–15 searches | "Why does this image filter smear on folded pages?" |
| **Breadth** | **N genuinely independent sub-questions** | **N agents** — one per sub-question | "Compare three PDF libraries for in-memory encryption" |

**The test for Breadth is independence, not width.** Split only where the sub-questions can be answered
without each other's findings. If two briefs would search the same things, they are one brief — parallel
agents on an overlapping topic is the documented duplicated-work failure, and it pays 2–4× for one set of
results.

**Never fan out on a single topic "for different perspectives."** Diverse lenses are a *verification*
pattern, not an information-gathering one. Depth questions get **one** agent.

State the tier and the agent count in your first reply, so the cost is a visible choice.

## Step 2 — Brief each agent properly (vague briefs are why agents duplicate work)

Every `dev-pipeline:research-tech` brief MUST carry four things. A brief missing any of them gets rewritten, not sent:

1. **Objective** — the one question this agent owns, restated sharply.
2. **Output format** — the agent's structured report (Confirmed/Likely/Unverified · comparison table ·
   recommendation · risks · sources).
3. **Tool guidance** — `context7` for a named package's API; primary sources over blogs; official docs,
   the project's own repo/paper, standards/RFCs, regulator/vendor publications.
4. **Out of scope** — name what the *other* agents are covering, explicitly, so this one stays off it.

Prefix each brief with its budget: `Quick check:` (3–5 searches) · `Investigate:` (5–10) ·
`Deep dive:` (10–15).

## Step 3 — Escalate rather than under-answer

Classification happens when you know the least. If a tier's budget runs out without a `Confirmed` answer,
or sources contradict each other, **say what is still missing and escalate one tier** — do not quietly
return a thin answer at the assigned budget.

## Step 4 — Consolidate

1. **Dedupe by URL.** Parallel agents overlap by construction.
2. **On duplicate findings, keep the higher confidence tag** and the better source.
3. **On conflicting sources, present both** and say which is more authoritative and why — never silently
   pick one.
4. **Every URL must be one that was actually opened** (`WebFetch`) or that appeared verbatim in a
   `WebSearch` result. A URL recalled from memory is `[Unverified]` and must be labelled so — or dropped.

## Step 5 — Save, then check the citations mechanically

Write the consolidated answer to `<research dir>/{topic}_{YYYYMMDD}.md` (default `docs/research/`) with: question & context,
the tier you chose, options compared, recommendation + **what would reverse it**, risks/licensing/
perf-budget implications, sources with access dates, and the **Graduation** line.

Then run the checker on the saved file and paste its summary line:

```
validate_citations.sh <research dir>/{topic}_{YYYYMMDD}.md
```

Measured rates for research agents are **3–13% fabricated citation URLs** and **5–18% non-resolving** —
a machine-checkable property, so it gets checked by a script rather than trusted. `DEAD` (404/410/DNS)
exits 1 and blocks: delete the claim or re-research it, and **never repair a dead link by guessing a
plausible replacement** — guessing is how the fabrication got there. `NEEDS-EYES` (403/429/timeout) is
not proof of fabrication; confirm those in a browser, don't silently promote them.

## Step 6 — Graduate the finding

A dated report nobody re-reads means the next session re-researches it. If the answer settled a
constraint, a banned option, a defect class, or a chosen approach, land it where it will be seen —
the project instructions file, the governing spec, the pitfalls file, or a memory — and say which.
The research file stays as the evidence trail, not as the place the decision lives.

---

Always surface licence compatibility, data-locality rules and the project's hard constraints (budgets, size
limits, accuracy targets) in any recommendation. Reference the numbers where Part A of
`.claude/review-loop/review_brief.md` and the product spec keep them — don't restate them here.

> **Subagent policy.** The Repo-first, API-lookup and Simple-factual tiers run **inline** — they need no agent.
> Spawn `dev-pipeline:research-tech` only for Depth or Breadth questions, one agent per independent sub-question.
> When running inline the output contract is unchanged: same structure, confidence tags, citation rule and file.
