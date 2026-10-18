import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
BIN = HERE / "plugins/device-e2e/bin/validate_e2e_plan.py"
TEMPLATE = HERE / "plugins/device-e2e/skills/playbook/e2e_test_plan.template.md"

passed = 0
failed = 0


def check(name, cond, out=""):
    global passed, failed
    if cond:
        passed += 1
    else:
        failed += 1
        print(f"FAIL {name}")
        if out:
            print("  " + "\n  ".join(out.splitlines()[:6]))


WORK = Path(tempfile.mkdtemp(prefix="e2e_plan_"))
SPEC = WORK / "spec.md"
SPEC.write_text("""## 2. Goals & Non-Goals
| # | Goal | Acceptance criterion |
|---|------|------|
| G1 | indexing resumes after Home | coverage grows in background |
| G2 | results ranked | unit test |
""")

PLAN = """# E2E test plan: resume

**Device budget:** 120 min · **Approved by:** owner, 2026-10-18

## Test basis

| Ref | Source | Item | Risk | Why this risk |
|---|---|---|---|---|
| G1 | spec §2 | resumes after Home | H | every large import |
| G2 | spec §2 | ranking | L | pure Dart |
| BUD-1s | review_brief Part A | first result within 1 s | M | user waits |
| CH-1 | diff | Android Otsu fix | M | Android only |

## Factors

| Factor | Partitions | Why the code path depends on it |
|---|---|---|
| language | Latin, CJK | tokenizer |

## State × event

| State | Home | OS kill |
|---|---|---|
| running | E1 | E2 |
| done | below: index_test.dart::done stays done | n/a: nothing to resume |

## Run steps

| Step | What | Min |
|---|---|---|
| READY | unlocked, WDA up | 5 |
| DRY | one cheap case | 10 |
| DIAG | pull diagnostics | 5 |

## Cases

| ID | Traces to | Covers | Risk | Platforms | Min | Order | Precondition (proven by) | Steps | Expected (FAIL when) | How checked |
|---|---|---|---|---|---|---|---|---|---|---|
| E1 | G1, BUD-1s | ST-running×Home, BUD-1s | H | both | 15 | 1 | progress 10/40 read before Home | Home, wait 60 s, reopen | coverage on return > coverage before Home; first result ≤ 1 000 ms | diagnostics file |
| E2 | G1 | ST-running×OSkill | H | both | 15 | 2 | progress 10/40 read before kill | am kill, relaunch | 40/40 within 120 s of relaunch | UI tree |
| E3 | CH-1 | EP-scanned-image | M | android | 10 | 3 | scanned JPG staged | import, search a word | the word is found on page 1 | UI tree |

## Covered below e2e

| Ref or item | Test that proves it (file::name) |
|---|---|
| G2 | test/search/ranking_test.dart::exact match first |

## Not covered

| Ref or item | Why | Risk accepted by |
|---|---|---|
| E3 ios | Android-only code | owner, 2026-10-18 |
"""

RESULTS = """# Results

**Build:** 1.1.4 (57)
**Commit:** abc1234
**Devices:** iPhone 13, iOS 18.6 · Redmi 15C, Android 15
**Date:** 2026-10-18
**Plan:** docs/plan.md

| ID | Platform | Status | Evidence |
|---|---|---|---|
| READY | ios | PASS | unlocked, WDA 200 |
| READY | android | PASS | adb device |
| DRY | ios | PASS | E1 dry, assertion mutated → FAIL |
| DRY | android | PASS | same |
| DIAG | ios | PASS | 0 failure events |
| DIAG | android | PASS | 0 failure events |
| E1 | ios | PASS | 12/40 → 31/40, 640 ms, `evidence/E1_ios_1.png` |
| E1 | android | PASS | 9/40 → 28/40, 810 ms, evidence/E1_android_1.xml |
| E2 | ios | BLOCKED | indexing done before kill (40/40) |
| E2 | android | FAIL | BUG-1, 10/40 after 120 s, logs/e2.txt |
| E3 | android | NOT RUN | no scanned fixture on this phone |

## Defects

### BUG-1: indexing does not resume after OS kill
- **Case:** E2 android
- **Build:** 1.1.4 (57)
- **Device:** Redmi 15C, Android 15
- **Severity:** S2 feature broken
- **Steps:** 1. import 40 pages 2. Home at 10 3. am kill 4. relaunch
- **Expected:** 40/40 within 120 s
- **Actual:** 10/40 after 120 s
- **Evidence:** logs/e2.txt
- **Harness ruled out by:** logcat shows am_proc_died then wm_on_resume

E2E: ios pass=1 fail=0 blocked=1 not_run=0 · android pass=1 fail=1 blocked=0 not_run=1
"""


for f in ("evidence/E1_ios_1.png", "evidence/E1_android_1.xml", "logs/e2.txt"):
    (WORK / f).parent.mkdir(parents=True, exist_ok=True)
    (WORK / f).write_text("x")


def run(plan, *args):
    p = WORK / "docs" / "plan.md"; p.parent.mkdir(exist_ok=True)
    p.write_text(plan)
    extra = []
    for a in args:
        if a in ("--spec", "--results"):
            extra.append(a)
        elif isinstance(a, str) and a.startswith("RES:"):
            r = WORK / f"res{len(extra)}.md"
            r.write_text(a[4:])
            extra.append(str(r))
        else:
            extra.append(str(a))
    out = subprocess.run([sys.executable, str(BIN), str(p), *extra], capture_output=True, text=True)
    return out.returncode, out.stdout + out.stderr


def expect(name, want, plan, *args, pattern=None):
    code, out = run(plan, *args)
    check(f"{name}: want exit {want}, got {code}", code == want, out)
    if pattern:
        check(f"{name}: output lacks '{pattern}'", pattern in out, out)


expect("good plan", 0, PLAN, "--spec", SPEC, "--results", "RES:" + RESULTS)

# 1. a spec goal the plan never lists
expect("missing goal", 1, PLAN.replace("| G2 | spec §2 | ranking | L | pure Dart |\n", "")
       .replace("| G2 | test/search", "| X | test/search"), "--spec", SPEC, pattern="spec goal G2 is not in Test basis")
# 2. a basis Ref with no case, no lower test, no Not covered line
expect("orphan ref", 1, PLAN.replace("| G2 | test/search/ranking_test.dart::exact match first |\n", ""),
       pattern="Test basis G2 has no case")
expect("case traces outside basis", 1, PLAN.replace("| E3 | CH-1 |", "| E3 | CH-9 |"),
       pattern="traces to CH-9, which is not a Test basis Ref")
expect("pushed down without a test", 1, PLAN.replace("test/search/ranking_test.dart::exact match first", "unit tests"),
       pattern="Covered below e2e G2: name the test")
expect("pushed down to a file, no test name", 1, PLAN.replace("ranking_test.dart::exact match first", "ranking_test.dart (exact match)"),
       pattern="Covered below e2e G2: name the test")
expect("pushed down to a test not written yet", 1, PLAN.replace("::exact match first", "::exact match first (to be created)"),
       pattern="the test is not written yet")
expect("state cell below without file::name", 1, PLAN.replace("below: index_test.dart::done stays done", "below: index_test.dart"),
       pattern="'below:' must name a test that exists")
expect("not covered without reason", 1, PLAN.replace("| E3 ios | Android-only code |", "| E3 ios | |"),
       pattern="Not covered E3 ios: no reason")
# 3. case cells
expect("weak oracle", 1, PLAN.replace("40/40 within 120 s of relaunch", "indexing eventually finishes"),
       pattern="E2: Expected 'eventually' cannot fail")
expect("weak oracle >= before", 1, PLAN.replace("40/40 within 120 s of relaunch", "coverage ≥ before"),
       pattern="cannot fail")
expect("duplicate id", 1, PLAN.replace("| E3 | CH-1 |", "| E2 | CH-1 |"), pattern="case ID E2 used twice")
expect("bad platform", 1, PLAN.replace("| M | android | 10 |", "| M | web | 10 |"),
       pattern="E3: Platforms must be")
expect("unfilled slot", 1, PLAN.replace("| diagnostics file |", "| <how> |"), pattern="E1: 'how checked' is empty")
# 4. redundancy
expect("redundant case", 1, PLAN.replace("| E3 | CH-1 | EP-scanned-image |", "| E3 | CH-1 | ST-running×Home |"),
       pattern="E3 is redundant")
# 5. state × event
expect("empty state cell", 1, PLAN.replace("| running | E1 | E2 |", "| running | E1 | |"),
       pattern="[running × os kill] is empty")
expect("n/a without reason", 1, PLAN.replace("n/a: nothing to resume", "n/a"), pattern="needs ': <reason or test>'")
expect("state cell names no case", 1, PLAN.replace("| running | E1 | E2 |", "| running | E1 | E9 |"),
       pattern="E9 is not a case ID")
# 6. results
expect("planned id missing from results", 1, PLAN, "--results", "RES:" + RESULTS.replace("| E3 | android | NOT RUN | no scanned fixture on this phone |\n", ""),
       pattern="E3 android: planned but has no row")
expect("blocked without reason", 1, PLAN, "--results", "RES:" + RESULTS.replace("| BLOCKED | indexing done before kill (40/40) |", "| BLOCKED | |"),
       pattern="E2 ios: BLOCKED with no reason")
expect("result outside the plan", 1, PLAN, "--results", "RES:" + RESULTS.replace("\n\n## Defects", "\n| X1 | ios | PASS | found a bug |\n\n## Defects"),
       pattern="X1 is not in the plan")
expect("bad status", 1, PLAN, "--results", "RES:" + RESULTS.replace("| E1 | ios | PASS |", "| E1 | ios | PASS (quick) |"),
       pattern="is not PASS, FAIL, BLOCKED or NOT RUN")
expect("no results table", 1, PLAN, "--results", "RES:# nothing\n", pattern="no results table")
# 7. budget and run steps
expect("over budget", 1, PLAN.replace("**Device budget:** 120 min", "**Device budget:** 60 min"),
       pattern="planned device time 110 min exceeds the Device budget of 60 min")
expect("no budget line", 1, PLAN.replace("**Device budget:** 120 min · ", ""), pattern="no **Device budget:**")
expect("missing run step", 1, PLAN.replace("| DIAG | pull diagnostics | 5 |\n", ""), pattern="run step DIAG is not planned")
expect("min not a number", 1, PLAN.replace("| both | 15 | 2 |", "| both | ~15 | 2 |"), pattern="E2: Min must be a number")
expect("order not a number", 1, PLAN.replace("| both | 15 | 2 |", "| both | 15 | high |"), pattern="E2: Order must be")
# 8. results header, defects, hand-off counts
expect("header slot", 1, PLAN, "--results", "RES:" + RESULTS.replace("**Commit:** abc1234", "**Commit:** <sha>"),
       pattern="header **Commit:** is missing")
expect("results name another plan", 1, PLAN, "--results", "RES:" + RESULTS.replace("docs/plan.md", "docs/other_plan.md"),
       pattern="does not name plan.md")
expect("run step row missing", 1, PLAN, "--results", "RES:" + RESULTS.replace("| DIAG | android | PASS | 0 failure events |\n", ""),
       pattern="DIAG android: planned but has no row")
expect("FAIL without a bug", 1, PLAN, "--results", "RES:" + RESULTS.replace("| FAIL | BUG-1, ", "| FAIL | "),
       pattern="E2 android: FAIL cites no BUG-n")
expect("FAIL cites an unknown bug", 1, PLAN, "--results", "RES:" + RESULTS.replace("| FAIL | BUG-1, ", "| FAIL | BUG-7, "),
       pattern="BUG-7 has no entry under Defects")
expect("defect field empty", 1, PLAN, "--results", "RES:" + RESULTS.replace("- **Harness ruled out by:** logcat shows am_proc_died then wm_on_resume", "- **Harness ruled out by:**"),
       pattern="BUG-1: field **Harness ruled out by:** is missing")
expect("bad severity", 1, PLAN, "--results", "RES:" + RESULTS.replace("S2 feature broken", "high"), pattern="Severity must be S1 to S4")
expect("defect names another case", 1, PLAN, "--results", "RES:" + RESULTS.replace("- **Case:** E2 android", "- **Case:** E1 android"),
       pattern="BUG-1: **Case:** does not name E2 android")
expect("hand-off counts differ", 1, PLAN, "--results", "RES:" + RESULTS.replace("android pass=1 fail=1", "android pass=2 fail=0"),
       pattern="E2E: line android counts differ")
expect("PASS with only words", 1, PLAN, "--results", "RES:" + RESULTS.replace(", `evidence/E1_ios_1.png`", ""),
       pattern="E1 ios: PASS cites no evidence file")
expect("PASS cites a missing file", 1, PLAN, "--results", "RES:" + RESULTS.replace("E1_android_1.xml", "E1_android_9.xml"),
       pattern="evidence file evidence/E1_android_9.xml does not exist")
expect("defect cites a missing file", 1, PLAN, "--results", "RES:" + RESULTS.replace("- **Evidence:** logs/e2.txt", "- **Evidence:** logs/e9.txt"),
       pattern="BUG-1: evidence file logs/e9.txt does not exist")
expect("no hand-off line", 1, PLAN, "--results", "RES:" + RESULTS.replace("E2E: ios", "ios"), pattern="no E2E: hand-off line")

# usage and the shipped template
expect("usage", 2, PLAN, "--bogus")
code, out = subprocess.run([sys.executable, str(BIN), str(TEMPLATE)], capture_output=True, text=True).returncode, ""
check("the unfilled template is not accepted", code == 1)

print(f"e2e plan: pass={passed} fail={failed}")
sys.exit(1 if failed else 0)
