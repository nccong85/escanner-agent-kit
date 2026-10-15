# Routing — directory → agent (example: a Flutter notes app with a C++ image engine)

| Path prefix | Coder | Reviewer |
|---|---|---|
| `lib/core/ffi/**` | main session | `flutter-native-agents:flutter-reviewer` (+ `flutter-native-agents:contract-expert`) |
| `lib/**`, `test/**` | `flutter-native-agents:flutter-coder` | `flutter-native-agents:flutter-reviewer` |
| `native/include/**` | `flutter-native-agents:contract-expert` | `flutter-native-agents:contract-expert` |
| `native/**` | `flutter-native-agents:cpp-engine-expert` | `flutter-native-agents:cpp-engine-expert` |
| `ios/**`, `android/**` | `flutter-native-agents:ios-android-expert` | `flutter-native-agents:ios-android-expert` |
| `fastlane/**`, `.github/**` | `flutter-native-agents:build-release-expert` | `flutter-native-agents:build-release-expert` |

| Trigger | Before coding | After coding |
|---|---|---|
| `native/include/**`, `lib/core/ffi/**` | `flutter-native-agents:contract-expert` first | also `flutter-native-agents:contract-expert`; FFI round-trip test passes |
| `lib/core/crypto/**`, logging, upload | — | also `flutter-native-agents:security-checker` |
| `native/**`, image pipeline, startup, DB queries | — | also `flutter-native-agents:performance-checker` |

| Dimension | Owner |
|---|---|
| Performance budgets | `flutter-native-agents:performance-checker` |
| Security, keys, telemetry leaks | `flutter-native-agents:security-checker` |
| ABI layout, wire bytes | `flutter-native-agents:contract-expert` |
| Dart state, routing, boundaries, tests | `flutter-native-agents:flutter-reviewer` |
