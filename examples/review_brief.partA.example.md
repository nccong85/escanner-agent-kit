# Part A — example (a Flutter notes app with a C++ image engine)

## Layout
| Concern | Path |
|---|---|
| Feature code | `lib/features/<f>/{data,domain,presentation}` |
| Shared code | `lib/core/**` |
| FFI bindings | `lib/core/ffi/**` (generated + typed wrappers) |
| Native engine | `native/include/engine_api.h` · `native/src/**` · `native/test/**` |
| Tests | `test/**` · `integration_test/**` |

## Stack
Flutter 3.x · Riverpod `Notifier` · Freezed + json_serializable · go_router · Drift · C++17 + OpenCV 4 · ffigen.

## Commands
| Step | Command |
|---|---|
| Analyze (0 issues) | `flutter analyze` |
| Unit tests | `flutter test <file> --plain-name "<case>"` |
| Codegen | `dart run build_runner build` |
| Native tests | `cmake --build native/build && ctest --test-dir native/build` |

## Budgets
| Key | Budget |
|---|---|
| `cold-start` | < 2 s on a mid-tier device, release build |
| `filter` | image filter < 300 ms per 12 MP page (native bench) |

## Non-negotiables
1. Every `catch` reports through `ErrorReporter.record` before setting user-facing state.
2. Logs and crash reports never contain note text, file paths or keys.
3. Heavy work (image filters, export, crypto) runs off the UI isolate.
4. Every native allocation is freed by its paired `engine_free_*` in `try/finally`.
5. Generated files are never edited by hand; the analyzer stays at zero.
