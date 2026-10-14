---
description: Create an implementation spec for a feature or bugfix, grounded in the project's own specs and code, with checkable acceptance criteria and mandatory non-goals.
argument-hint: "<feature-or-bugfix-description>"
---

# Create Specification

**Goal:** a spec that is the source of truth for `/dev-pipeline:task-decompose`.
**Input:** the feature description in `$ARGUMENTS`.
**Output:** `<features dir>/{feature-name}/spec_{feature-name}.md` — the features dir is `FEATURES_DIR` in
`.claude/review-loop/config.env` (default `docs/features`).

Enter plan mode first: explore thoroughly before writing, and get the user's approval before finalizing.

## Step 1: Requirement analysis

### 1.1 Parse the input
- Extract the feature name and scope.
- List the **layers** it touches, using the layout in `.claude/review-loop/review_brief.md` Part A.
- Flag **contract impact**: does it change an ABI, an encrypted or binary wire format, or a network API shape?
  If yes it is a **contract change** and needs contract-first sequencing (the contract owner in `routing.md`).

### 1.2 Ground in the project's source-of-truth documents
Read the normative specs Part A points to (product requirements, architecture, security spec) before inventing
anything. Cite the sections you rely on.

### 1.3 Find reference patterns (reference-first)
- **Symbol level:** a language server or serena (`get_symbols_overview`, `find_symbol`, `find_referencing_symbols`,
  `find_implementations`) to read the nearest existing implementation and its dependents.
- **Text level:** `Grep`/`Glob` for similar constructs, strings, assets, docs and config.
- **Library docs:** context7 for fast-moving APIs — then verify against the version the project actually pins
  (lockfile, manifest). Docs describe the newest release, not the one installed.
- **If serena or context7 is not installed:** use `Grep`/`Read` and the installed package source instead, and
  mark any API claim you could not check against a source as unverified. Do not stop because of it.

### 1.4 Contract, security and budget pre-check
- **Contract change** → the spec describes the contract change FIRST, then the per-side updates, then an interop test.
- **Security-sensitive** (crypto, keys, nonces, recovery, sync, data leaving the device) → the spec states which
  security properties are preserved and that the security gate reviews it.
- **Hot path** → the spec states the impact on the named budgets in Part A (reference them; do not restate numbers).
- Respect every dependency-licence and data-handling rule Part A lists.

## Step 2: Draft the spec

```markdown
# {Feature Title}

**Status:** Draft
**Date:** {YYYY-MM-DD}
**Layers affected:** {from Part A layout}
**Contract impact:** none | abi | wire | api
**Spec refs:** {source-of-truth sections}

## 1. Overview
{What and why, 3–4 sentences, tied to a requirement.}

## 2. Goals & Non-Goals
### Goals
| # | Goal | Acceptance criterion (how it is PROVEN) |
|---|------|------------------------------------------|
| G1 | {what becomes true} | {a named command, test, budget or invariant — checkable from the diff alone} |

### Non-Goals (REQUIRED)
- {explicitly out of scope}

## 3. Technical Design
### Data / contract model
{Models, tables, API shapes. For a contract change: the exact diff and the version decision.}
### Cross-stack / cross-platform parity
{What must stay identical across languages or platforms, and the interop vectors needed.}
### Security impact
{Properties preserved, key storage, what data goes where.}
### Layer behavior
- {layer}: {behavior}
### Performance / NFRs
{Cite the named budgets.}

## 4. Implementation Guide
### Reference patterns
| Aspect | Reference | Files |
|--------|-----------|-------|
### Key files to create/modify
| Layer | Files |
|-------|-------|
### Build / verify per layer
- {layer}: `{command from Part A}`

## 5. UI/UX (if applicable)

## 6. Open Questions
{Filled by Step 3.}
```

> **Every goal carries an acceptance criterion checkable from the diff alone** — a named command, test, budget or
> invariant. "Works correctly" is not one. Task-decompose turns these into each task's Definition of Done, and a
> vague DoD is the main source of round-2 review findings.
>
> **Non-Goals is mandatory.** Spec-validate checks scope creep *against* Non-Goals; without them that check passes
> while checking nothing.

## Step 3: Refine (open questions)
Generate 5–7 targeted questions across: clarification, contract safety, security, performance, scope (YAGNI) and
reuse. Ask them (at most 4 per question batch — ask the highest-stakes first), update the spec, then clear Open
Questions.

## Step 3b: Check the references mechanically
```
validate_spec_refs.sh <features dir>/{feature-name}/spec_{feature-name}.md
```
Every repo path the spec cites must exist. A file the feature will *create* is fine — write "to be created".

## Step 4: Save and exit plan mode
Save `spec_{feature-name}.md` (bugfix: `spec_fix_{brief}.md`), exit plan mode for approval, and report the file,
the layers, the contract impact and the next step: `/dev-pipeline:spec-validate <spec path>`.
