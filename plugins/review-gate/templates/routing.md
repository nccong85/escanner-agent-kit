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

The kit's own agents were renamed in 1.1.0, and two plugins in 2.0.0 (`review-loop` → `review-gate`,
`flutter-native-agents` → `flutter-native`). Plans and logs written before 2.0.0 name the old ones:

| 1.0.x name | 1.1 name | 2.0 name |
|---|---|---|
| `review-loop:review-filter` | `review-loop:finding-checker` | `review-gate:finding-checker` |
| `dev-pipeline:research-tech` | `dev-pipeline:tech-researcher` | `dev-pipeline:tech-researcher` |
| `device-e2e:test-device-e2e` | `device-e2e:device-tester` | `device-e2e:device-tester` |
| `flutter-native-agents:dev-flutter` | `flutter-native-agents:flutter-coder` | `flutter-native:flutter-coder` |
| `flutter-native-agents:review-flutter` | `flutter-native-agents:flutter-reviewer` | `flutter-native:flutter-reviewer` |
| `flutter-native-agents:owner-native-engine` | `flutter-native-agents:cpp-engine-expert` | `flutter-native:cpp-engine-expert` |
| `flutter-native-agents:owner-platform` | `flutter-native-agents:ios-android-expert` | `flutter-native:ios-android-expert` |
| `flutter-native-agents:owner-contract` | `flutter-native-agents:contract-expert` | `flutter-native:contract-expert` |
| `flutter-native-agents:owner-build-release` | `flutter-native-agents:build-release-expert` | `flutter-native:build-release-expert` |
| `flutter-native-agents:gate-security` | `flutter-native-agents:security-checker` | `flutter-native:security-checker` |
| `flutter-native-agents:gate-performance` | `flutter-native-agents:performance-checker` | `flutter-native:performance-checker` |
