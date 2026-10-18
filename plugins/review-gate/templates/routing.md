# Routing — directory → agent (single source of truth)

Every command that dispatches agents (`/review-gate:review`, `/dev-pipeline:implement`,
`/dev-pipeline:task-decompose`) routes by this file. Change an agent name, an area or a new directory **here only**.

Agent names from a plugin are namespaced: `<plugin>:<agent>`, e.g. `flutter-native:flutter-reviewer`.
A coder column that says **main session** means the orchestrating session implements it itself.

## Directory routing (most-specific prefix wins)

| Path prefix | Coder | Reviewer |
|---|---|---|
| `<src/feature/**>` | `<plugin:…-coder>` or main session | `<plugin:…-reviewer>` |
| `<native/**>` | `<plugin:…-expert>` | `<plugin:…-expert>` (review mode) |
| `<build / release files>` | `<plugin:build-release-expert>` | `<plugin:build-release-expert>` |

## Overlay gates (always added on top of the table)

| Trigger | Before coding | After coding |
|---|---|---|
| ABI / wire format / API contract change | `<plugin:contract-expert>` first | also `<plugin:contract-expert>`; interop test must pass |
| Crypto, keys, logging of user data, upload/storage | — | also `<plugin:security-checker>` |
| Hot path (startup, render loop, native pipeline, DB query, new dependency) | — | also `<plugin:performance-checker>` |

**Mixed directories:** one agent per layer, in parallel.

## Exclusive ownership (review_brief §B4)

| Dimension | Owner | Everyone else |
|---|---|---|
| Performance budgets, bench demands, allocation cost | `<plugin:performance-checker>` | mention in one line, no finding |
| Security, keys, plaintext/telemetry leaks | `<plugin:security-checker>` | mention in one line, no finding |
| ABI layout, wire bytes, version negotiation | `<plugin:contract-expert>` | — |
| <area correctness> | `<plugin:…-reviewer>` | — |

## Legacy names (optional)
If you rename an agent, map the old name here so older plans still resolve: `old-name` → `new-name`.
