# Routing — directory → agent (example: a Flutter notes app with a C++ image engine)

| Path prefix | Coder | Reviewer |
|---|---|---|
| `lib/core/ffi/**` | main session | `flutter-native-agents:review-flutter` (+ `flutter-native-agents:owner-contract`) |
| `lib/**`, `test/**` | `flutter-native-agents:dev-flutter` | `flutter-native-agents:review-flutter` |
| `native/include/**` | `flutter-native-agents:owner-contract` | `flutter-native-agents:owner-contract` |
| `native/**` | `flutter-native-agents:owner-native-engine` | `flutter-native-agents:owner-native-engine` |
| `ios/**`, `android/**` | `flutter-native-agents:owner-platform` | `flutter-native-agents:owner-platform` |
| `fastlane/**`, `.github/**` | `flutter-native-agents:owner-build-release` | `flutter-native-agents:owner-build-release` |

| Trigger | Before coding | After coding |
|---|---|---|
| `native/include/**`, `lib/core/ffi/**` | `flutter-native-agents:owner-contract` first | also `flutter-native-agents:owner-contract`; FFI round-trip test passes |
| `lib/core/crypto/**`, logging, upload | — | also `flutter-native-agents:gate-security` |
| `native/**`, image pipeline, startup, DB queries | — | also `flutter-native-agents:gate-performance` |

| Dimension | Owner |
|---|---|
| Performance budgets | `flutter-native-agents:gate-performance` |
| Security, keys, telemetry leaks | `flutter-native-agents:gate-security` |
| ABI layout, wire bytes | `flutter-native-agents:owner-contract` |
| Dart state, routing, boundaries, tests | `flutter-native-agents:review-flutter` |
