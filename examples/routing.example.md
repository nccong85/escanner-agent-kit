# Routing — directory → agent (example: a Flutter notes app with a C++ image engine)

| Path prefix | Coder | Reviewer |
|---|---|---|
| `lib/core/ffi/**` | main session | `flutter-native:flutter-reviewer` (+ `flutter-native:contract-expert`) |
| `lib/**`, `test/**` | `flutter-native:flutter-coder` | `flutter-native:flutter-reviewer` |
| `native/include/**` | `flutter-native:contract-expert` | `flutter-native:contract-expert` |
| `native/**` | `flutter-native:cpp-engine-expert` | `flutter-native:cpp-engine-expert` |
| `ios/**`, `android/**` | `flutter-native:ios-android-expert` | `flutter-native:ios-android-expert` |
| `fastlane/**`, `.github/**` | `flutter-native:build-release-expert` | `flutter-native:build-release-expert` |

| Trigger | Before coding | After coding |
|---|---|---|
| `native/include/**`, `lib/core/ffi/**` | `flutter-native:contract-expert` first | also `flutter-native:contract-expert`; FFI round-trip test passes |
| `lib/core/crypto/**`, logging, upload | — | also `flutter-native:security-checker` |
| `native/**`, image pipeline, startup, DB queries | — | also `flutter-native:performance-checker` |

| Dimension | Owner |
|---|---|
| Performance budgets | `flutter-native:performance-checker` |
| Security, keys, telemetry leaks | `flutter-native:security-checker` |
| ABI layout, wire bytes | `flutter-native:contract-expert` |
| Dart state, routing, boundaries, tests | `flutter-native:flutter-reviewer` |
