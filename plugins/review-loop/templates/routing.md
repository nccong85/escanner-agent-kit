# Routing — directory → agent (single source of truth)

Every command that dispatches agents (`/review-loop:review`, `/dev-pipeline:implement`,
`/dev-pipeline:task-decompose`) routes by this file. Change an agent name, an area or a new directory **here only**.

Agent names from a plugin are namespaced: `<plugin>:<agent>`, e.g. `flutter-native-agents:review-flutter`.
A coder column that says **main session** means the orchestrating session implements it itself.

## Directory routing (most-specific prefix wins)

| Path prefix | Coder | Reviewer |
|---|---|---|
| `<src/feature/**>` | `<plugin:dev-…>` or main session | `<plugin:review-…>` |
| `<native/**>` | `<plugin:owner-…>` | `<plugin:owner-…>` (review mode) |
| `<build / release files>` | `<plugin:owner-build-release>` | `<plugin:owner-build-release>` |

## Overlay gates (always added on top of the table)

| Trigger | Before coding | After coding |
|---|---|---|
| ABI / wire format / API contract change | `<plugin:owner-contract>` first | also `<plugin:owner-contract>`; interop test must pass |
| Crypto, keys, logging of user data, upload/storage | — | also `<plugin:gate-security>` |
| Hot path (startup, render loop, native pipeline, DB query, new dependency) | — | also `<plugin:gate-performance>` |

**Mixed directories:** one agent per layer, in parallel.

## Exclusive ownership (review_brief §B4)

| Dimension | Owner | Everyone else |
|---|---|---|
| Performance budgets, bench demands, allocation cost | `<plugin:gate-performance>` | mention in one line, no finding |
| Security, keys, plaintext/telemetry leaks | `<plugin:gate-security>` | mention in one line, no finding |
| ABI layout, wire bytes, version negotiation | `<plugin:owner-contract>` | — |
| <area correctness> | `<plugin:review-…>` | — |

## Legacy names (optional)
If you rename an agent, map the old name here so older plans still resolve: `old-name` → `new-name`.
