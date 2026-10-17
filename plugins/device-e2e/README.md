**English** · [Tiếng Việt](README.vi.md)

# device-e2e

Real-device end-to-end testing of a mobile app from a Mac: a physical iPhone through WebDriverAgent and an
Android phone through adb + uiautomator. It was built while testing e-Scanner on an iPhone 13 and a Redmi 15C,
and keeps the traps that cost real device time there.

| Piece | What it does |
|---|---|
| `agents/device-tester.md` | Plans cases, drives the phones, triages every FAIL (harness bug or app bug), cleans up, reports PASS/FAIL/BLOCKED with evidence. Never fixes app code. |
| `skills/playbook/` | The procedure: workflow, rules for cases that can actually fail, triage, device rules, cleanup, report — plus `references/ios.md`, `references/android.md`, `references/traps.md`. |
| `skills/playbook/harness/` | `IosDriver` (WebDriverAgent HTTP) and `AndroidDriver` (adb + uiautomator) with the same method names, configured by `E2E_*` environment variables. Python 3 standard library only. |
| `commands/init.md` | `/device-e2e:init`: creates `.claude/device-e2e/project.md` from the template and lists its unfilled slots. |
| `skills/playbook/project.template.md` | The project facts the agent needs: devices, app id, build commands, harness paths, cleanup. |

## Set up

1. `claude plugin install device-e2e@escanner-agent-kit` (it depends on `review-gate`, whose hook keeps the agent
   from running destructive git commands).
2. Run `/device-e2e:init` in your project. It creates `.claude/device-e2e/project.md` from `project.template.md`
   (never over an existing one) and lists the slots you still have to fill.
3. Build WebDriverAgent once for your iPhone, enable Developer Mode and UI Automation on it, and make adb see the
   Android phone (`adb devices`).
4. Write your app-flows module and suite on top of the two drivers — the skill explains the shape.

Then ask for it in plain words, e.g. "run the import cases on both phones", or dispatch `device-tester`.

## What it will not do

- Build or reinstall the app unless the brief says the owner approved it — uninstalling wipes app data.
- Use `xcodebuild test` or `flutter drive` on a phone whose data matters.
- Report a PASS without evidence read from the device, or a PASS for a case whose precondition was not proven.
