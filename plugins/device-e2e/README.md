**English** · [Tiếng Việt](README.vi.md) · [日本語](README.ja.md)

# device-e2e

End-to-end testing of a mobile app on real devices from a Mac: an iPhone through WebDriverAgent and an Android
phone through adb + uiautomator. Built while testing e-Scanner on an iPhone 13 and a Redmi 15C; it records the
traps that cost device time there.

| Piece | What it does |
|---|---|
| `agents/device-tester.md` | Plans cases, drives the phones, triages every FAIL (harness bug or app bug), cleans up, reports PASS/FAIL/BLOCKED with evidence. Changes app code only if the brief says so. |
| `skills/playbook/` | The procedure: workflow, triage, device rules, cleanup, report. Plus `references/test-design.md` (how to derive cases from the spec so none is missing and none repeats, oracles that can fail, the device-time budget), `references/glossary.md` (one meaning per term, PASS/FAIL/BLOCKED/NOT RUN), `references/ios.md`, `references/android.md`, `references/traps.md`. |
| `skills/playbook/e2e_test_plan.template.md` | The plan: test basis with risk, factors, State × event table, run steps (`READY`, `DRY`, `DIAG`), cases with device minutes and run order, *Covered below e2e*, *Not covered*; and the results layout: header, table, `BUG-n` defect entries, the `E2E:` line. |
| `bin/validate_e2e_plan.py` | Checks a plan without a model: every spec goal and basis item has a case, a named lower-level test or a *Not covered* reason; no redundant case; no empty State × event cell; no Expected that cannot fail. The total device time fits the budget. With `--results`: the header names the build and this plan, every planned case and run step has a PASS/FAIL/BLOCKED/NOT RUN row per platform, every case PASS cites an evidence file that exists, every FAIL has a complete `BUG-n`, and the `E2E:` counts match. |
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

The agent's brief has fixed lines (`SPEC`, `PLAN`, `PLATFORMS`, `BUDGET`, …), listed in `agents/device-tester.md`.
Then ask in plain words, e.g. "run the import cases on both phones", or dispatch `device-tester`.

## What it will not do

- Build or reinstall the app unless the brief says the owner approved it. Uninstalling wipes app data.
- Use `xcodebuild test` or `flutter drive` on a phone whose data matters.
- Report a PASS without evidence read from the device, or for a case whose precondition was not proven.
- Run the device before the owner approved the test plan, or drop a planned case from the results.
