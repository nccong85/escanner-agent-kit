**English** · [Tiếng Việt](README.vi.md)

# flutter-native

Reference agents for Flutter apps with a C/C++ engine behind FFI and iOS/Android platform code. Requires
`review-gate`. Every agent reads `.claude/review-gate/review_brief.md` first, so your project's facts override the
illustrative defaults inside each agent.

| Agent | Role | Writes code? |
|---|---|---|
| `flutter-coder` | Flutter/Dart feature code | yes |
| `cpp-engine-expert` | C++ engine behind a C ABI: implements and reviews | yes |
| `ios-android-expert` | Swift/Kotlin platform-channel code: implements and reviews | yes |
| `contract-expert` | ABI headers, wire formats, API shapes, version negotiation | yes (contract files) |
| `build-release-expert` | CI, signing, store lanes, multi-toolchain builds | yes |
| `flutter-reviewer` | Dart/Flutter correctness, error contract, test quality | no |
| `security-checker` | Crypto, keys, privacy, telemetry leaks, supply chain | no |
| `performance-checker` | Budgets, hot paths, allocations, startup, measured numbers | no |

Name scheme: `<scope>-<role>` — `-coder` writes, `-expert` writes and reviews one layer, `-reviewer` and `-checker`
are read-only. Reviewers get only the read-only serena tools; agents default to `model: inherit`.

Use them as plugin agents (`flutter-native:<name>`) or copy one into `.claude/agents/` and adapt it.
