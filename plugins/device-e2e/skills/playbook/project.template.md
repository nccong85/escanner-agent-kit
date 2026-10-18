# Device e2e — project facts

`/device-e2e:init` copies this file to `.claude/device-e2e/project.md`; fill every slot in angle brackets. The `device-tester` agent and the
`device-e2e:playbook` skill read it before touching a device; nothing here is guessed.

## App

| Key | Value |
|---|---|
| iOS bundle id / Android application id (`E2E_APP_ID`) | `<com.example.app>` |
| Build + upgrade-install on iPhone (keeps app data) | `<build + install command, e.g. ./tool/run_ios.sh UDID>` |
| Build + upgrade-install on Android (keeps app data) | `<build + install command, e.g. ./tool/run_android.sh SERIAL>` |
| Who approves a build | `<the owner; the agent builds only when the brief says so>` |

## Devices

| Phone | UDID / serial | Passcode? | Notes |
|---|---|---|---|
| `<iPhone model>` | `<UDID>` (`E2E_IOS_UDID`) | `<yes/no>` | WDA derived data `<path>`, log `<path>` |
| `<Android model>` | `<serial>` (`E2E_ANDROID_SERIAL`) | `<yes/no>` | `<OS skin, screen size>` |

WebDriverAgent checkout: `<path>`. adb: `<path, or "on PATH">` (`E2E_ADB`).

## Harness

| Piece | Path |
|---|---|
| Drivers | the skill's `harness/wda_driver.py` and `harness/adb_driver.py`, or a copy in `<path>` |
| App flows | `<path to the project's app-flows module>` |
| Suite | `<path>` — run as `python3 -u <path> ios|android <case ids>` |
| Fixtures | generator `<path>`, output `<folder>`; Android device folder `E2E_ANDROID_FIXTURE_DIR=<path>` |
| iOS fixture HTTP server | `<command and port>` |

Optional environment: `E2E_BACK_LABELS=<Back,…>` (localized back-button labels), `E2E_IOS_DIAG_PATH=<path in the
app container>`, `E2E_ANDROID_DIAG_PATH=<path on the device>`.

## Plans and results

- Test plans: `<e.g. docs/features/FEATURE/e2e_test_plan_*.md>` (from the playbook's `e2e_test_plan.template.md`)
- Results summary: `<e.g. docs/features/FEATURE/e2e_results_summary_YYYYMMDD.md>` (with the template's results table)

## Cleanup specific to this app

Restore settings to what `READY` recorded, never to a fixed value.

- `<delete test documents, empty trash, reset language, …>`
