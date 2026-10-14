---
name: playbook
description: Real-device end-to-end testing of a mobile app on a physical iPhone (WebDriverAgent over Wi-Fi) and an Android phone (adb + uiautomator), driven from the Mac by a small Python harness. Use whenever someone asks to test on a real phone, run e2e or regression on device, verify a fix on hardware before a release, import large files on device, leave the app mid-task (Home, lock, kill, camera) and check it resumes, or check search/OCR in several languages on real hardware. Not for unit or widget tests, cloud device farms, emulators, or perf benches.
---

# Real-device e2e testing (iPhone + Android)

You drive the **release** app on physical phones from the Mac and judge it only by what the device shows and
records. The value of this work is evidence the app behaves on real hardware; the cost is hours of device time.
In the project this came from, most lost time came from harness bugs, not app bugs — so verify the harness
before you trust a FAIL, and verify the probe before you trust a PASS.

## Project facts live in one file

Read **`.claude/device-e2e/project.md`** first: devices (UDID, serial, passcode or not), app id, build and
install commands, harness location, fixture folder, diagnostics paths, cleanup steps. If it is missing, stop and
say so; `${CLAUDE_SKILL_DIR}/project.template.md` is the starting point. Never guess a UDID or an install command.

## Harness

The skill ships two drivers with the same method names, so app flows are written once. Import them with
`sys.path.insert(0, "${CLAUDE_SKILL_DIR}/harness")`, or copy them into the project once and record the path in
`project.md`:

| File | Role |
|---|---|
| `${CLAUDE_SKILL_DIR}/harness/wda_driver.py` | `IosDriver`: WebDriverAgent HTTP client (tap, type, drag, source tree, screenshot, file pull) |
| `${CLAUDE_SKILL_DIR}/harness/adb_driver.py` | `AndroidDriver`: adb + uiautomator dump (same methods, plus fixture staging and IME helpers) |

They read `E2E_APP_ID`, `WDA`, `E2E_IOS_UDID`, `E2E_ANDROID_SERIAL` and the optional variables listed in
`project.md` from the environment. On top of them the project keeps its own files (paths in `project.md`):

- an **app-flows** module — navigation, import through the system picker, search, delete, empty trash, language
  switch, diagnostics export — written against the driver interface, never against one platform;
- a **suite** — test cases plus a result-file writer, run as `python3 -u <suite> ios|android <case ids>`;
- optional **fixture** generation and a tiny HTTP server so the iPhone can download fixtures through Safari.

## Workflow

1. **Plan the cases first.** Write them into the feature's e2e test plan (ID, steps, expected, how it is checked).
   Each expected result must be observable from the UI or a file the app writes — "works" is not a check.
2. **Build and install the code under test** only with the commands in `project.md`, and only when the brief
   says the owner approved a build. Otherwise test the build already installed and say which one it is.
3. **Bring up the drivers** — iOS: `references/ios.md`; Android: `references/android.md`.
4. **Stage fixtures on each device.** Regenerating fixtures means re-staging them on **every** device — a stale
   copy on one phone silently tests old content.
5. **Calibrate on a dry run** of one cheap case per platform before the long run (for example import → search →
   delete → empty trash → diagnostics pull). Fix the harness until this passes cleanly.
6. **Run long suites in the background** and watch them with a monitor that greps
   `^\[(PASS|FAIL|BLOCKED)\]|progress|Traceback`. Monitors expire; re-arm them. One suite per device at a time;
   before restarting, make sure the old python process is really gone (`pgrep -fl <suite name>`), because
   stopping the monitor does not stop the suite.
7. **Triage every FAIL/BLOCKED before reporting it** (below). Fix harness bugs and re-run the case. For an app
   bug, collect the evidence and report it; when you run as the `test-device-e2e` agent you do not fix the app.
8. **Clean up** (below) and report with the result files.

## Writing cases that can actually fail

These rules come from cases that passed while proving nothing:

- **Prove the precondition you mean to test.** "Leave the app mid-task" is only tested if the task was mid-way
  when you left. Measure progress *before* the interruption and mark the case BLOCKED (not PASS) if the work had
  already finished. A slow probe can finish the work for you.
- **Probe progress cheaply.** If the work is sequential, binary-search checkpoints (about 5 probes) instead of
  probing every one.
- **Use tokens the device reads reliably.** On-device OCR misreads look-alike characters (one engine read `0`
  after letters as `O`), so letter+digit tokens produce false FAILs on one platform only. All-digit tokens and
  real words are safer.
- **Match the right item.** Results can include the user's real data; check the fixture's own title too, and
  allow for truncated names in grids (`abc…xyz.pdf`).
- **Assert absence structurally.** "The removed thing is gone" must look for something that would come back with
  it (an icon, a key), not for the deleted literal string — a deleted string can never be found, so the test can
  never fail. Mutation-check new assertions when cheap.
- **Read the app's own record.** After an interruption pull the app's diagnostics or log file and count the
  failure events it recorded.

## Triage: harness bug or app bug?

Before calling anything an app bug, look at a screenshot taken at the failure and, on Android, the activity log:
`adb logcat -b events -d | grep -E "wm_on_(resume|paused|stop|destroy)|am_proc_died|wm_finish"`.
`wm_finish_activity … app-request` right after a Back press means the harness closed the app, not a crash.

Typical harness bugs: Back pressed on the app's root screen while a system picker or an overlay was still
opening; a picker that reopened in a different folder; a UI element reported with an unexpected type; a stale
fixture on one phone; a second copy of the suite still driving the same phone. The full list with fixes is in
`references/traps.md` — read it before debugging a FAIL that makes no sense.

To tell "the file is bad" from "the app is wrong", cross-check inputs and outputs with independent tools on the
Mac (for PDFs: PyMuPDF, `qpdf`, `pypdfium2`).

## Device rules

- Cases that lock the screen need a passcode-free phone: WDA cannot unlock a phone with a passcode, and a locked
  phone blocks every later case. Skip those cases on passcode phones, or stop and ask for the phone to be unlocked.
- One device, one session: another session may be building or testing on the same phone. Check first.
- `xcodebuild test` and `flutter drive` can uninstall or overwrite the app — never use them on a phone whose data
  matters. WDA's own `test-without-building` runner is the exception.

## Cleanup (always, even after a failed run)

1. Delete the test documents and empty the app's trash on each device.
2. Switch the app back to the user's language if a case changed it.
3. Android: restore the keyboard, uninstall ADB Keyboard if you installed it, `svc power stayon false`, remove the
   staged fixture folder.
4. Stop the background WDA and the fixture HTTP server.
5. Anything else `project.md` lists under cleanup.

## Report

Write the results summary where `project.md` says (one row per case per device with the evidence — numbers, not
adjectives — the app bugs found, and what was **not** verified). Delete the result files of aborted runs so
they do not read as results.
