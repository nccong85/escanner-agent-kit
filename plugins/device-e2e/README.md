**English** · [Tiếng Việt](README.vi.md)

# device-e2e

End-to-end testing of a mobile app on real devices from a Mac: an iPhone through WebDriverAgent and an Android
phone through adb + uiautomator. Built while testing e-Scanner on an iPhone 13 and a Redmi 15C; it records the
traps that cost device time there.

| Piece | What it does |
|---|---|
| `agents/device-tester.md` | Plans cases, drives the phones, triages every FAIL (harness bug or app bug), cleans up, reports PASS/FAIL/BLOCKED with evidence. Changes app code only if the brief says so. |
| `skills/playbook/` | The procedure: workflow, rules for cases that can actually fail, triage, device rules, cleanup, report. Plus `references/ios.md`, `references/android.md`, `references/traps.md`. |
| `skills/playbook/harness/` | `IosDriver` (WebDriverAgent HTTP) and `AndroidDriver` (adb + uiautomator) share method names and read environment variables: `WDA=http://<ip>:8100` for the iPhone, `E2E_*` for the rest. Python 3 standard library only. |
| `commands/init.md` | `/device-e2e:init`: creates `.claude/device-e2e/project.md` from the template and lists its unfilled slots. |
| `skills/playbook/project.template.md` | The project facts the agent needs: devices, app id, build commands, harness paths, cleanup. |

## Set up

1. `claude plugin install device-e2e@escanner-agent-kit` (depends on `review-gate`, whose hook stops the agent
   running destructive git commands).
2. Run `/device-e2e:init` in your project. It creates `.claude/device-e2e/project.md` from `project.template.md`
   (never over an existing one) and lists the slots left to fill.
3. Build WebDriverAgent once for your iPhone, enable Developer Mode and UI Automation on it, keep it unlocked and
   on the Mac's Wi-Fi, and make adb see the Android phone (`adb devices`). Steps:
   [`ios.md`](skills/playbook/references/ios.md), [`android.md`](skills/playbook/references/android.md).
4. Write your app-flows module and suite on top of the two drivers. The skill explains the shape.

Then ask in plain words, e.g. "run the import cases on both phones", or dispatch `device-tester`.

## What it will not do

- Build or reinstall the app unless the brief says the owner approved it. Uninstalling wipes app data.
- Use `xcodebuild test` or `flutter drive` on a phone whose data matters.
- Report a PASS without evidence read from the device, or for a case whose precondition was not proven.
