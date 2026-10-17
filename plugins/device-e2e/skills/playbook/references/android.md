# Android: adb + uiautomator

Device serial, screen size, OS flavour and install command come from `.claude/device-e2e/project.md`.
`AndroidDriver` finds adb through `E2E_ADB`, then `PATH`, then the default SDK folders. Keep the screen on during
a run with `keep_screen_on(True)`. Save the previous value with `current_stay_on()` at `READY` and put it back with
`restore_stay_on()`; `keep_screen_on(False)` turns it off even on a phone that had it on.

## Installing

Use the install command in `project.md`. Some OEM skins (HyperOS/MIUI) show a short "install via USB" dialog
that refuses by itself; poll `uiautomator dump` and confirm it. A store-signed install cannot be upgraded by a
local build, and uninstalling wipes the app's data — ask first.

## Reading the UI

`uiautomator dump` + XML parse (`AndroidDriver.elements()`), 1–2 s per read. Text comes from `text` or
`content-desc`. The system navigation bar sits at the bottom: never tap an element whose centre falls there (a
half-visible list row tapped over it pressed Back). Filter rows to those fully above about 90 % of the screen
height.

## Typing

`adb shell input text` only handles ASCII. For other scripts install **ADB Keyboard** (`senzhk/ADBKeyBoard`,
GPL-2.0, a test-only tool, never shipped) from its GitHub release APK; `use_adb_keyboard()` switches to it and
`type_text` sends `ADB_INPUT_TEXT` broadcasts. Save the previous IME with `current_ime()` and restore it with
`restore_ime()` at the end — a killed run leaves ADB Keyboard active, so restore it by hand if needed.

## Staging fixtures

`stage_fixtures(local_dir, names)` pushes to `E2E_ANDROID_FIXTURE_DIR` (default `/sdcard/Download/e2e`) and
broadcasts `MEDIA_SCANNER_SCAN_FILE`; without the scan the system picker does not list the files.
`remove_fixtures()` deletes the folder during cleanup.

## System file picker

- Wait until `com.google.android.documentsui` is the foreground package before touching anything
  (`wait_foreground`). Pressing Back while the picker is still opening lands on the app's root screen, and Back
  there can finish the activity — the app "closes" and the next case fails.
- Open the folder through its breadcrumb, then tap the row whose title equals the file name **exactly**; a
  substring match once hit a preview icon and opened an "Open with" chooser.
- OEM skins may ask which app or store to use for some intents; pick explicitly.

## Overlays

Long operations (large imports) can show a blocking overlay for tens of seconds. Wait for it to go away before
deciding the app is lost and pressing Back.

## Pulling app files and logs

`pull_file(device_path, dest)` uses `adb pull`; `pull_diagnostics` reads the path from `E2E_ANDROID_DIAG_PATH`.
For "why did the app close" use the event log:
`adb logcat -b events -d | grep -E "<app id>" | grep -E "wm_on_|am_proc_died|wm_finish_activity"`.
