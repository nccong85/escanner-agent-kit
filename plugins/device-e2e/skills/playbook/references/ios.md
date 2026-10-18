# iOS: WebDriverAgent on a physical iPhone

Devices, derived-data folders and log paths come from `.claude/device-e2e/project.md`. Re-check the device list
with `xcrun devicectl list devices` before quoting a UDID or an iOS version anywhere.

## Start WDA

Build WebDriverAgent once (`appium/WebDriverAgent`, signed with your team), then start it in the background on
each run — it runs as an XCTest that never ends:

```bash
cd <wda checkout> && xcodebuild -project WebDriverAgent.xcodeproj -scheme WebDriverAgentRunner \
  -destination 'id=<UDID>' -derivedDataPath <derived data> test-without-building > <wda log> 2>&1
```

- The phone must be unlocked, on the same Wi-Fi as the Mac, Developer Mode on, and **Settings → Developer →
  Enable UI Automation** confirmed once by the phone's owner.
- The first start on a phone may need an enrolled Touch ID/Face ID; a passcode alone is not always enough.
- The IP is usually DHCP and changes: read it from the log, `grep -o 'ServerURLHere->[^<]*' <wda log>`, and
  export `WDA=http://<ip>:8100`. Check with `curl -s $WDA/status`.
- The session id is cached in `E2E_WDA_SID_FILE` (default `~/.cache/device-e2e/wda_sid`, private to your user); a stale one is recreated.
- Stop WDA at the end by stopping the background xcodebuild task.

## Reading the UI

`GET /source?format=description` is the only tree read that is fast enough; `IosDriver.elements()` parses it.
Labels can span several lines — the parser joins continuation lines. Element types matter and are not always
what you expect (in a Flutter app, image-less tiles came back as `StaticText`, others as `Other`/`Button`). Each
read costs 1–3 s, so budget probes accordingly.

## Staging fixtures

If the phone's iCloud is a different Apple ID from the Mac, dropping files into the Mac's iCloud Drive does
nothing. Serve them over HTTP and save each through Safari:

1. Start a small HTTP server over the fixture folder in the background.
2. Open `http://<mac-ip>:<port>/<file>` in Safari, then More → Share → Save to Files → Save. When the file already
   exists, tap the **replace** button — its label changes between iOS versions and languages, so match every
   known label and fail loudly if the prompt is still open. Never fall through to "Keep Both", which leaves the
   stale file in place.
3. Verify by opening the app's file picker and checking the thumbnails or dates of the fixture cells.

## System file picker

- The picker remembers its last folder; verify the folder before picking and navigate there if needed.
- Cells below the fold do not scroll reliably with a drag in grid view; type the name into the picker's search
  field instead (clear old text first).
- The top-right cancel button closes the whole picker, not just the search.
- A picker left open by a killed run blocks the next run; close stray pickers at the start of navigation.

## Pulling app files

`IosDriver.pull_file(<path inside the app container>, dest)` uses
`xcrun devicectl device copy from --domain-type appDataContainer`. `pull_diagnostics` reads the container path
from `E2E_IOS_DIAG_PATH`.

## Locking

`/wda/lock` works; `/wda/unlock` fails with HTTP 500 when the phone has a passcode, and every later case then
fails on a locked screen. `IosDriver.locked()` tells you; skip lock cases on passcode phones.
