# Review Rules Index — the closed vocabulary every finding must cite

Every review finding MUST carry `rule: <ID>` from the namespaces below. **A finding whose ID does not resolve is
rejected by the orchestrator without a model call** — the plugin's `validate_rule_ids.sh` checks it:

```
validate_rule_ids.sh R-PIT-3.2 R-NN-1 R-BUD-cold-start
```

Why: structured output guarantees the *format* of a finding, not its *accuracy*. Forcing every finding to name
a pre-existing rule is what stops a reviewer inventing one, drifting out of the diff, or re-deriving the
project's conventions every round.

**A finding you cannot map to an ID is not a finding.** It goes under `## Follow-up (out of diff)` as prose, is
never counted in `blocking`, and — if it recurs — becomes a new rule via §4.

---

## 1. Namespaces

| Namespace | Means | Resolves against | Example |
|---|---|---|---|
| `R-PIT-<n>.<m>` | A documented pitfall | a `### <n>.<m>` heading in the pitfalls file | `R-PIT-3.2` |
| `R-PIT-<n>` | A whole pitfall section | a `## <n>.` heading in the pitfalls file | `R-PIT-3` |
| `R-NN-<n>` | A Part A non-negotiable | a line `<n>. ` in `review_brief.md` | `R-NN-1` |
| `R-BUD-<key>` | A named budget | a row in §2 below | `R-BUD-cold-start` |
| `R-SPEC-<file>§<sec>` | A normative spec section | a spec file under the specs or features dir | `R-SPEC-sync§4.2` |
| `R-DOD-<n>` | The task's Definition-of-Done line n | the current task's tasks file | `R-DOD-3` |
| `R-REQ` | The requirement itself is unmet | the spec section the task cites (quote it) | `R-REQ` |
| `R-<NS>-<n>` | A stack-specific rule set you add | a row in §2b below | `R-WEB-4` |

> **Verify a pitfall anchor before you cite it:** `grep -nE '^#{2,3} <n>' <pitfalls file>`. Sections that group
> entries under *named* headings have no numbered sub-entries — cite the section (`R-PIT-<n>`) and name the
> sub-heading in the finding text. Inventing an anchor that *looks* real is the most common way a true finding
> gets thrown away.

`R-DOD-*` and `R-REQ` are the only IDs for "this does not do what was asked". Everything else must point at a
written rule.

## 2. `R-BUD-*` — the closed budget set
| ID | Budget |
|---|---|
| `R-BUD-<key>` | <budget, unit, how it is measured> |

## 2b. Stack-specific rule sets (optional)
Add one table per stack. Each row is `| \`R-<NS>-<n>\` | <rule> | <default severity> |`.

| ID | Rule | Default severity |
|---|---|---|
| `R-<NS>-1` | <rule> | <High/Medium> |

## 3. MECHANIZED — never *speculate* about these
These are enforced by the analyzer or an executing guard test. Asserting that one *might* be violated is noise:
the machine already answers it.

| You did | File it as |
|---|---|
| Reasoned that the diff *might* violate a mechanized rule | **Nothing.** Run the check, or say nothing. |
| **Ran** the check and it **fails** | `R-DOD-<n>` with the pasted failure output — blocking, and the most valuable finding a reviewer can produce. |
| Believe the rule itself is wrong | `## Follow-up`, never blocking. |

| Enforced by | Covers |
|---|---|
| `<analyzer / lint rule>` | <what it rejects> |
| `<guard test>` | <what it rejects> |

## 4. Growing and pruning the index
- **A finding class that recurs in 2+ reviews must become a guard test / lint / analyzer error — or be deleted
  from this index.**
- A genuinely new class of defect: fix it, add a Symptom→Cause→Rule entry to the pitfalls file, and cite the new
  `R-PIT-<n>.<m>` from then on.
- **Prune on outcome.** Every deferred finding records `outcome:` (`fixed` / `rejected` / `dropped`). A rule ID
  whose findings are mostly `rejected`/`dropped` is noise — delete it.
