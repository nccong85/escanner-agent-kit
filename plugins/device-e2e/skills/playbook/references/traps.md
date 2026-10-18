# Traps seen on real devices, and their fixes

Read this before debugging a FAIL that "makes no sense". Every entry cost real device time once.

## Harness / environment

| Symptom | Cause | Fix in the harness |
|---|---|---|
| Android case BLOCKED, app on the launcher, no crash in logcat | Back pressed on the app's root screen (picker not open yet, or a blocking overlay hid the expected control) and the activity finished | `wait_foreground` for the picker; wait for overlays; never press Back when the foreground package is not the app |
| Two runs' results interleave, odd timings | Stopping the monitor does not stop the suite; an old python process kept driving the same phone | `pgrep -fl <suite>` before every restart; `pkill -f "<suite> <platform>"` |
| iOS cases all FAIL after regenerating fixtures | The iPhone still had the old files: Safari's replace prompt used a label the script did not know, and the old file stayed | Match every known label; raise if the prompt is still open; check thumbnails after staging |
| iOS element "not found" although it is on screen | It is reported with an unexpected element type (e.g. `StaticText`) and was filtered out | Accept the extra type when its label shape matches; de-duplicate by position |
| Names don't match | Grids truncate names with an ellipsis | Compare stem prefix and suffix around the ellipsis |
| iOS picker cell not found | Picker reopened in another folder, search text left over, or the grid does not scroll | Verify the folder; search by name after clearing |
| Android multi-select delete fails | A half-visible row over the nav bar was tapped → Back → left selection mode | Only tap rows fully above ~90 % of the height; loop select → delete |
| iOS run stuck for a long time | System picker left open by a killed run | Close stray pickers at the start of navigation |
| Every iOS case fails after a lock case | Passcode phone: `/wda/unlock` → HTTP 500 | Skip lock cases on passcode phones |
| Non-ASCII query typed as nothing on Android | `adb shell input text` is ASCII-only | ADB Keyboard + broadcast |
| Visual checks differ between two checkouts of the same commit | Unpinned dependency lockfile or stale cached test assets | Use the same lockfile; clear cached assets after a lock change |

## Probe design

| Symptom | Cause | Fix |
|---|---|---|
| "Resume after leaving the app" PASS, but the work had already finished before leaving | A slow linear probe took longer than the work itself | Binary-search probe; BLOCKED if progress is at or near the total before the interruption |
| Multi-interruption case BLOCKED on a fast phone | Re-probing between interruptions let the work finish | Probe once before, interrupt back-to-back, probe once after |
| An OCR token is never found on one platform | That engine misreads look-alike characters (`0` → `O`) | All-digit tokens; file the misread as a product limitation if users hit it too |
| Search "hit" for the wrong item | The user's real data contains matching words | Require the fixture's title in the result row |
| Assertion "line removed" can never fail | It looked for the deleted literal string | Assert on the icon or key that would return with it; mutation-check |

## Things that looked like bugs but were not

- Progress seemed to jump around an interruption: the probe itself takes minutes of foreground time. Compare
  before/after only for "did it restart from the beginning", not for speed.
- Crash-reporter process states (`BACKGROUND` while on screen) can be unreliable for non-fatal reports; check the
  OS logs before trusting them.
- Crash-reporter issues that appear right after an e2e night usually come from the test phones: check the device
  model and installation id before treating them as user reports.
