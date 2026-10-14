# flutter-native-agents

Reference agents for Flutter apps with a C/C++ engine behind FFI and iOS/Android platform code. Requires
`review-loop`. Every agent reads `.claude/review-loop/review_brief.md` first, so your project's facts override the
illustrative defaults inside each agent.

| Agent | Role | Writes code? |
|---|---|---|
| `dev-flutter` | Flutter/Dart feature code | yes |
| `owner-native-engine` | C++ engine behind a C ABI: implements and reviews | yes |
| `owner-platform` | Swift/Kotlin platform-channel code: implements and reviews | yes |
| `owner-contract` | ABI headers, wire formats, API shapes, version negotiation | yes (contract files) |
| `owner-build-release` | CI, signing, store lanes, multi-toolchain builds | yes |
| `review-flutter` | Dart/Flutter correctness, error contract, test quality | no |
| `gate-security` | Crypto, keys, privacy, telemetry leaks, supply chain | no |
| `gate-performance` | Budgets, hot paths, allocations, startup, measured numbers | no |

Name scheme: `<role>-<scope>` — `dev-` writes, `owner-` writes and reviews one layer, `review-` and `gate-` are
read-only. Reviewers get only the read-only serena tools; agents default to `model: inherit`.

Use them as plugin agents (`flutter-native-agents:<name>`) or copy one into `.claude/agents/` and adapt it.
