#!/usr/bin/env python3
"""Deterministic checker for a device e2e test plan and its results.

Usage:
  validate_e2e_plan.py <plan.md> [--spec <spec.md>] [--results <summary.md>]...

The plan follows skills/playbook/e2e_test_plan.template.md. Checks what a model should not be trusted to
eyeball on its own plan:
  1. Every spec goal (a `| G<n> |` row of --spec) is a Ref in *Test basis*.
  2. Every basis Ref is traced by a case, cited in *Covered below e2e*, or listed in *Not covered* with a reason;
     every case traces only to basis Refs.
  3. Cases have unique IDs, filled cells, valid platforms, and an Expected that can fail
     ("works", "eventually", "≥ before" cannot).
  4. No case is redundant: one whose every Covers item is covered by other cases.
  5. Every State × event cell holds a case ID, `below: <test>` or `n/a: <reason>`.
  6. The run steps READY, DRY and DIAG are planned; every case has Min and Order; the device time
     (Min × platforms, run steps included) fits the plan's **Device budget**.
  7. With --results: the header names the build, commit, devices, date and this plan; every case and run step has
     exactly one row per planned platform with PASS, FAIL, BLOCKED or NOT RUN, a reason for BLOCKED / NOT RUN, and
     no row for an ID the plan does not have; every case PASS cites an evidence file; every evidence file cited
     (a path with a directory, e.g. `evidence/E1_ios_1.png`, relative to the summary) exists; every FAIL cites a
     BUG-n whose defect entry is complete; the `E2E:` line's counts equal the table's.

Exit 0 = no finding. Exit 1 = at least one finding. Exit 2 = usage error or unreadable file.
A cell is one `|`-separated field; a cell that is a whole `<…>` slot is unfilled.
"""
import re
import sys
from pathlib import Path

WEAK = re.compile(
    r"\bworks?\b|\bcorrectly\b|\bproperly\b|\bas expected\b|\beventually\b|(>=|≥)\s*(the\s+)?(before|previous)",
    re.I,
)
PLATFORMS = {"ios", "android"}
STATUSES = {"PASS", "FAIL", "BLOCKED", "NOT RUN"}
RUN_STEPS = ("READY", "DRY", "DIAG")
NUM = re.compile(r"\d+(\.\d+)?")
HEADER = ("Build", "Commit", "Devices", "Date", "Plan")
DEFECT_FIELDS = ("Case", "Build", "Device", "Severity", "Steps", "Expected", "Actual", "Evidence", "Harness ruled out by")
TEST_REF = re.compile(r"\S\.[A-Za-z]{1,5}::\s*\S")
EVIDENCE_FILE = re.compile(r"[\w.~/-]*/[\w.-]+\.(?:png|jpe?g|xml|json|txt|log|csv)\b", re.I)
UNWRITTEN = re.compile(r"\bto be (created|written|added)\b|\bTODO\b|\bTBD\b|\bnot yet\b|\bplanned\b|\bmissing\b", re.I)

findings = []


def find(where, msg):
    findings.append(f"{where}: {msg}")


def clean(cell):
    return cell.strip().replace("`", "").replace("**", "").strip()


def tokens(cell):
    return [t for t in re.split(r"[,;\s]+", clean(cell)) if t]


def unfilled(cell):
    c = clean(cell)
    return not c or c in {"-", "?", "TBD"} or (c.startswith("<") and c.endswith(">"))


def tables(lines):
    """Yield (header, rows) for each markdown table in lines; rows are lists of cells."""
    i = 0
    while i < len(lines):
        if lines[i].lstrip().startswith("|") and i + 1 < len(lines) and re.match(r"^\s*\|[\s:|-]+\|\s*$", lines[i + 1]):
            header = [clean(c).lower() for c in lines[i].strip().strip("|").split("|")]
            rows = []
            i += 2
            while i < len(lines) and lines[i].lstrip().startswith("|"):
                rows.append([c.strip() for c in lines[i].strip().strip("|").split("|")])
                i += 1
            yield header, rows
        else:
            i += 1


def sections(text):
    out, name, fence = {}, "", False
    for line in text.splitlines():
        if line.startswith("```"):
            fence = not fence
        if fence or line.startswith("```"):
            continue
        if line.startswith("## "):
            name = line[3:].strip().lower()
            out[name] = []
        elif name:
            out[name].append(line)
    return out


def section(secs, prefix):
    for name, lines in secs.items():
        if name.startswith(prefix):
            return lines
    return None


def col(header, *names):
    for n in names:
        for i, h in enumerate(header):
            if h.startswith(n):
                return i
    return None


def cell(row, i):
    return row[i] if i is not None and i < len(row) else ""


def read(path):
    try:
        return Path(path).read_text(encoding="utf-8")
    except OSError as e:
        print(f"FATAL: cannot read {path}: {e}")
        sys.exit(2)


def main(argv):
    if not argv or argv[0].startswith("-"):
        print(__doc__.strip().splitlines()[2])
        return 2
    plan_path, spec, results = argv[0], None, []
    rest = argv[1:]
    while rest:
        flag = rest.pop(0)
        if flag not in ("--spec", "--results") or not rest:
            print(f"usage error near {flag!r}")
            return 2
        if flag == "--spec":
            spec = rest.pop(0)
        else:
            results.append(rest.pop(0))

    plan_text = read(plan_path)
    secs = sections(plan_text)
    P = Path(plan_path).name

    # ---- test basis ----------------------------------------------------------
    basis_lines = section(secs, "test basis")
    refs = []
    if basis_lines is None:
        find(P, "no '## Test basis' section")
    else:
        for header, rows in tables(basis_lines):
            ri, rk = col(header, "ref"), col(header, "risk")
            for row in rows:
                ref = clean(cell(row, ri))
                if unfilled(ref):
                    find(P, f"Test basis row with no Ref: {'|'.join(row)}")
                    continue
                if ref in refs:
                    find(P, f"Test basis Ref {ref} listed twice")
                refs.append(ref)
                if clean(cell(row, rk)).upper()[:1] not in ("H", "M", "L"):
                    find(P, f"Test basis {ref}: Risk must be H, M or L")

    if spec:
        goals = re.findall(r"^\|\s*`?(G\d+)`?\s*\|", read(spec), re.M)
        if not goals:
            find(Path(spec).name, "no goal rows (| G1 | …) found")
        for g in dict.fromkeys(goals):
            if g not in refs:
                find(P, f"spec goal {g} is not in Test basis")

    # ---- cases ---------------------------------------------------------------
    case_lines = section(secs, "cases")
    cases = {}  # id -> (traces, covers, platforms)
    minutes = {}
    if case_lines is None:
        find(P, "no '## Cases' section")
    else:
        for header, rows in tables(case_lines):
            idx = {k: col(header, k) for k in ("id", "traces", "covers", "platform", "expected", "how checked", "min", "order")}
            for k, v in idx.items():
                if v is None:
                    find(P, f"Cases table has no '{k}' column")
            if None in idx.values():
                continue
            for row in rows:
                cid = clean(cell(row, idx["id"]))
                if unfilled(cid):
                    find(P, f"case row with no ID: {'|'.join(row)}")
                    continue
                if cid in cases:
                    find(P, f"case ID {cid} used twice")
                for k in ("traces", "covers", "platform", "expected", "how checked"):
                    if unfilled(cell(row, idx[k])):
                        find(P, f"{cid}: '{k}' is empty or still a slot")
                traces = tokens(cell(row, idx["traces"]))
                for t in traces:
                    if t not in refs:
                        find(P, f"{cid}: traces to {t}, which is not a Test basis Ref")
                plats = {t.lower() for t in tokens(cell(row, idx["platform"]))}
                if "both" in plats:
                    plats = (plats - {"both"}) | PLATFORMS
                if plats - PLATFORMS or not plats:
                    find(P, f"{cid}: Platforms must be ios, android or both")
                expected = clean(cell(row, idx["expected"]))
                m = WEAK.search(expected)
                if m:
                    find(P, f"{cid}: Expected '{m.group(0)}' cannot fail; name the number or state that fails it")
                mins = clean(cell(row, idx["min"]))
                if not NUM.fullmatch(mins):
                    find(P, f"{cid}: Min must be a number of device minutes per platform")
                if not re.fullmatch(r"\d+", clean(cell(row, idx["order"]))):
                    find(P, f"{cid}: Order must be a whole number (1 runs first; a cut run drops the highest)")
                cases[cid] = (traces, set(tokens(cell(row, idx["covers"]))), plats & PLATFORMS)
                minutes[cid] = float(mins) if NUM.fullmatch(mins) else 0

    # ---- run steps and budget ----------------------------------------------
    all_plats = set().union(*[c[2] for c in cases.values()]) if cases else set()
    steps = {}
    for header, rows in tables(section(secs, "run steps") or []):
        si, mi = col(header, "step", "id"), col(header, "min")
        for row in rows:
            sid = clean(cell(row, si))
            m = clean(cell(row, mi))
            if sid in RUN_STEPS:
                steps[sid] = float(m) if NUM.fullmatch(m) else None
                if steps[sid] is None:
                    find(P, f"run step {sid}: Min must be a number")
    for sid in RUN_STEPS:
        if sid not in steps:
            find(P, f"run step {sid} is not planned (## Run steps)")
    total = sum(minutes[c] * len(cases[c][2]) for c in cases) + sum((v or 0) * len(all_plats) for v in steps.values())
    m = re.search(r"\*\*Device budget:\*\*\s*(\d+(?:\.\d+)?)", plan_text)
    if not m:
        find(P, "no **Device budget:** <minutes> line")
    elif total > float(m.group(1)):
        find(P, f"planned device time {total:g} min exceeds the Device budget of {m.group(1)} min; cut by Order")

    # ---- redundancy ----------------------------------------------------------
    for cid, (_, covers, _) in cases.items():
        others = set().union(*[c[1] for k, c in cases.items() if k != cid]) if len(cases) > 1 else set()
        if covers and covers <= others:
            find(P, f"{cid} is redundant: every item it covers ({', '.join(sorted(covers))}) is covered by another case")

    # ---- state × event -------------------------------------------------------
    st_lines = section(secs, "state")
    for header, rows in tables(st_lines or []):
        for row in rows:
            state = clean(cell(row, 0))
            for j in range(1, len(header)):
                c = clean(cell(row, j))
                where = f"State × event [{state} × {header[j]}]"
                if unfilled(c):
                    find(P, f"{where} is empty; write a case ID, 'below: <test>' or 'n/a: <reason>'")
                elif c.lower().startswith(("n/a", "below")):
                    if not re.match(r"^(n/a|below)\s*:\s*\S", c, re.I):
                        find(P, f"{where}: '{c}' needs ': <reason or test>'")
                    elif c.lower().startswith("below") and (not TEST_REF.search(c) or UNWRITTEN.search(c)):
                        find(P, f"{where}: 'below:' must name a test that exists (file::name)")
                else:
                    for t in tokens(c):
                        if t not in cases:
                            find(P, f"{where}: {t} is not a case ID")

    # ---- covered below / not covered ----------------------------------------
    accounted = {t for c in cases.values() for t in c[0]}
    below = section(secs, "covered below")
    for header, rows in tables(below or []):
        ti = col(header, "test")
        for row in rows:
            item = clean(cell(row, 0))
            if unfilled(item):
                continue
            test = clean(cell(row, ti if ti is not None else 1))
            if unfilled(test) or not TEST_REF.search(test):
                find(P, f"Covered below e2e {item}: name the test (file::name), or keep it on the device")
            elif UNWRITTEN.search(test):
                find(P, f"Covered below e2e {item}: the test is not written yet; keep it on the device or in Not covered")
            else:
                accounted.update(tokens(item))
    notcov = section(secs, "not covered")
    for header, rows in tables(notcov or []):
        wi, ai = col(header, "why"), col(header, "risk accepted", "accepted")
        for row in rows:
            item = clean(cell(row, 0))
            if unfilled(item):
                continue
            if unfilled(cell(row, wi if wi is not None else 1)):
                find(P, f"Not covered {item}: no reason")
            if ai is not None and unfilled(cell(row, ai)):
                find(P, f"Not covered {item}: nobody accepted the risk")
            accounted.update(tokens(item))
    for r in refs:
        if r not in accounted:
            find(P, f"Test basis {r} has no case, no lower-level test and no Not covered line")

    # ---- results -------------------------------------------------------------
    known = dict(cases)
    for sid in steps:
        known[sid] = ([], set(), all_plats)
    for res in results:
        R = Path(res).name
        text = read(res)
        base = Path(res).resolve().parent

        def missing_files(where, evidence):
            for f in EVIDENCE_FILE.findall(evidence):
                if not (base / Path(f).expanduser()).is_file():
                    find(R, f"{where}: evidence file {f} does not exist")
        for h in HEADER:
            m = re.search(rf"^\*\*{h}:\*\*(.*)$", text, re.M)
            if not m or unfilled(m.group(1)):
                find(R, f"header **{h}:** is missing or still a slot")
            elif h == "Plan" and Path(plan_path).name not in {Path(t).name for t in tokens(m.group(1))}:
                find(R, f"header **Plan:** does not name {Path(plan_path).name}")
        defects = {}
        for block in re.split(r"^### ", text, flags=re.M)[1:]:
            m = re.match(r"(BUG-\d+)\b", block)
            if not m:
                continue
            fields = dict(re.findall(r"^\s*-\s*\*\*([^*]+?):\*\*(.*)$", block, re.M))
            defects[m.group(1)] = fields
            missing_files(m.group(1), clean(fields.get("Evidence", "")))
            for f in DEFECT_FIELDS:
                if f not in fields or unfilled(fields[f]):
                    find(R, f"{m.group(1)}: field **{f}:** is missing or empty")
            if "Severity" in fields and not re.match(r"\s*S[1-4]\b", fields["Severity"]):
                find(R, f"{m.group(1)}: Severity must be S1 to S4")
        seen = {}
        found_table = False
        for header, rows in tables(text.splitlines()):
            ii, pi, si, ei = col(header, "id"), col(header, "platform"), col(header, "status"), col(header, "evidence")
            if None in (ii, pi, si):
                continue
            found_table = True
            for row in rows:
                cid, plat = clean(cell(row, ii)), clean(cell(row, pi)).lower()
                status = re.sub(r"\s+", " ", clean(cell(row, si)).upper())
                evidence = clean(cell(row, ei))
                if cid not in known:
                    find(R, f"{cid} is not in the plan; add the case to the plan first")
                    continue
                if (cid, plat) in seen:
                    find(R, f"{cid} {plat}: more than one row")
                seen[(cid, plat)] = status
                if status not in STATUSES:
                    find(R, f"{cid} {plat}: status '{status}' is not PASS, FAIL, BLOCKED or NOT RUN")
                if status in ("BLOCKED", "NOT RUN") and unfilled(evidence):
                    find(R, f"{cid} {plat}: {status} with no reason")
                if status == "PASS" and cid in cases and not EVIDENCE_FILE.search(evidence):
                    find(R, f"{cid} {plat}: PASS cites no evidence file (e.g. evidence/{cid}_{plat}_1.png)")
                missing_files(f"{cid} {plat}", evidence)
                if status == "FAIL":
                    bugs = re.findall(r"BUG-\d+", evidence)
                    if not bugs:
                        find(R, f"{cid} {plat}: FAIL cites no BUG-n")
                    for bug in bugs:
                        if bug not in defects:
                            find(R, f"{cid} {plat}: {bug} has no entry under Defects")
                        elif not re.search(rf"\b{re.escape(cid)}\b.*\b{plat}\b", defects[bug].get("Case", ""), re.I):
                            find(R, f"{bug}: **Case:** does not name {cid} {plat}")
        if not found_table:
            find(R, "no results table with ID, Platform and Status columns")
            continue
        for cid, (_, _, plats) in known.items():
            for plat in sorted(plats):
                if (cid, plat) not in seen:
                    find(R, f"{cid} {plat}: planned but has no row (write NOT RUN with the reason)")
        m = re.search(r"^E2E:.*$", text, re.M)
        if not m:
            find(R, "no E2E: hand-off line")
        else:
            for plat in sorted(PLATFORMS):
                got = re.search(rf"{plat}\s+pass=(\d+)\s+fail=(\d+)\s+blocked=(\d+)\s+not_run=(\d+)", m.group(0))
                want = [sum(1 for (c, p), st in seen.items() if c in cases and p == plat and st == x)
                        for x in ("PASS", "FAIL", "BLOCKED", "NOT RUN")]
                if plat not in all_plats and not got:
                    continue
                if not got or [int(g) for g in got.groups()] != want:
                    find(R, f"E2E: line {plat} counts differ from the table (pass, fail, blocked, not_run = {want})")

    for f in findings:
        print(f"FAIL {f}")
    print(f"e2e plan: {len(refs)} basis ref(s), {len(cases)} case(s), {len(findings)} finding(s)")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
