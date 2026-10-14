---
description: Gate a spec for implementation readiness with six objective conditions (four settled by commands), and save the verdict next to the spec.
argument-hint: "<path-to-spec-file>"
---

# Validate Specification

Analyze the spec at: `$ARGUMENTS`

## Step 0: Mechanical checks first
```
validate_spec_refs.sh <spec-path>
grep -n "Non-Goals" <spec-path>
grep -n "Open Questions" <spec-path>
```
- `validate_spec_refs.sh` exits 1 ⇒ **Not Ready**.
- No non-empty `Non-Goals` section ⇒ **Not Ready** (the YAGNI check below would be vacuous).
- A goal without an acceptance criterion checkable from the diff ⇒ **Not Ready**.

## Step 1: Codebase and contract alignment
| Check | Symbol level | Text level | Status |
|-------|--------------|------------|--------|
| Reference patterns exist | `find_symbol` | `Grep`/`Read` | [ ] |
| Layer idioms match existing code | `get_symbols_overview` | `Read` target files | [ ] |
| Dependents considered | `find_referencing_symbols` | `Grep` usages | [ ] |

**Red flags (automatic Not Ready):**
- A contract change (ABI, wire format, API) not sequenced contract-first with an interop test.
- A cross-platform format changed on one side only, or a header edited without regenerating its bindings.
- A dependency or model whose licence the project forbids (Part A).
- A violation of any data-handling non-negotiable in Part A (plaintext reaching a server, secrets or user content
  in logs, data leaving where it must stay).
- A named budget in Part A exceeded.
- Cited reference files that do not exist.

## Step 2: Section checks
- **Overview & goals:** what + why, tied to a requirement; goals measurable; non-goals honor the product scope.
- **Technical design:** contract diff + version decision when contracts change; parity and interop vectors
  described; security properties enumerated; budgets cited.
- **Implementation guide:** reference patterns, key files per layer, per-layer verify commands.
- **UI/UX and open questions:** UI states defined if applicable; Open Questions empty.

## Step 3: YAGNI
Compare scope against the non-goals and the product scope. Flag premature optimization, feature creep,
over-abstraction and gold plating. Cut what only a small minority of users need unless the spec is about it.

## Step 4: Quality checks (Pass / Fail / Partial each)
- **Contract safety (P1)** · **Security (P1)** · **Performance (P1)** · **Licence (P1)**
- Completeness and clarity · Implementability by the routed agent.

## Output
```markdown
## Validation Summary
**Status:** Ready | Not Ready

| # | Gate condition (ALL must hold for Ready) | Result |
|---|-------------------------------------------|--------|
| 1 | `validate_spec_refs.sh` exits 0 | ✓/✗ |
| 2 | `Non-Goals` present and non-empty | ✓/✗ |
| 3 | Every goal has a diff-checkable acceptance criterion | ✓/✗ |
| 4 | `Open Questions` empty or absent | ✓/✗ |
| 5 | Every P1 check is Pass | ✓/✗ |
| 6 | No red flag triggered | ✓/✗ |

## Critical Gaps (must fix)
## Missing Details
## Overengineering Found
## Essential Scope
## Recommendations
```

There is deliberately **no confidence score**: a self-assigned number cannot be wrong and therefore cannot gate
anything. Report *which* condition failed.

## Save the verdict
Write it next to the spec: `<spec folder>/validation_{feature}_{YYYYMMDD_HHmm}.md`. A "Not Ready" that exists only
in chat is lost when the session ends. On re-validation write a new timestamped file.

Next step when Ready: `/dev-pipeline:task-decompose <spec path>`.
