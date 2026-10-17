#!/usr/bin/env bash
# Templates that two commands must agree on. task-decompose creates execution_state.md and implement fills it in;
# a column one writes and the other never created is a measurement that silently never happens.
set -uo pipefail
CMD="$(cd "$(dirname "$0")/.." && pwd)/plugins/dev-pipeline/commands"
pass=0; fail=0
ok() { pass=$((pass+1)); }
ko() { fail=$((fail+1)); echo "FAIL $*"; }

ledger() { grep -m1 '^| Task | Review rounds |' "$CMD/$1"; }
a=$(ledger task-decompose.md); b=$(ledger implement.md)
if [ -n "$a" ] && [ "$a" = "$b" ]; then ok; else ko "Cost Ledger headers differ:"; echo "  task-decompose: $a"; echo "  implement:      $b"; fi

for f in task-decompose.md implement.md; do
  grep -q 'Report lines = ' "$CMD/$f" && ok || ko "$f does not define the Report lines column"
done

# The sanctioned-stops header names a count; it must match the numbered list under it.
words=(zero one two three four five six seven eight nine)
word=$(grep -oE 'The [a-z]+ sanctioned stops\*\*' "$CMD/implement.md" | awk '{print $2}')
n=$(awk '/The [a-z]+ sanctioned stops\*\*/{f=1;next} f&&/^[0-9]+\. /{c++} f&&/^$/{exit} END{print c+0}' "$CMD/implement.md")
[ "${words[$n]}" = "$word" ] && ok || ko "implement.md says '$word' sanctioned stops but lists $n"

# Every place that dispatches a fix coder takes the pre-fix snapshot first; the delta review diffs against it.
rows=$(grep -c '^|.*Step=FIX' "$CMD/implement.md"); snap_rows=$(grep '^|.*Step=FIX' "$CMD/implement.md" | grep -c 'snapshot')
[ "$rows" -gt 0 ] && [ "$rows" = "$snap_rows" ] && ok || ko "implement.md: $((rows-snap_rows)) of $rows Step=FIX rows skip the snapshot"
awk '/^4\. `blocking > 0`/{f=1} f{s=s $0} f&&/delta re-review/{exit} END{exit !(s ~ /snapshot/)}' "$CMD/implement.md" \
  && ok || ko "implement.md Step 5.4 does not take the pre-fix snapshot"
grep -q 'No fix coder is dispatched while Pre-fix snapshot is `(none)`' "$CMD/implement.md" && ok || ko "implement.md lacks the no-snapshot dispatch guard"
grep -q 'If it is `(none)`, the fix ran without a snapshot' "$CMD/implement.md" && ok || ko "implement.md delta prompt lacks the no-snapshot fallback"

# A reviewer that returns its report inline leaves no path for the Cost Ledger or the next delta review: every agent
# with a review hand-off states the report-file exception, and both review commands check the file exists.
AGENTS="$(cd "$CMD/../.." && pwd)"
for f in "$AGENTS"/*/agents/*.md; do
  grep -q '^Reviewing → write the report' "$f" || continue
  grep -q 'it is required even$' "$f" && grep -q 'modify nothing else' "$f" && ok || ko "$(basename "$f") lacks the report-file exception"
done
grep -q '^\*\*Check the report file first\*\*' "$CMD/implement.md" && ok || ko "implement.md Step 2 does not check the report file"
grep -q 'names no report file that exists is re-prompted once' "$AGENTS/review-loop/commands/review.md" && ok || ko "review.md does not check the report file"

# A task that needs the owner's yes for a build or device run is marked in the plan, gated in implement, and an
# agent that stops itself with BLOCKED has its own routing row instead of falling to "no recognized ACTION".
grep -q '^\*\*Gate:\*\* none | owner approval' "$CMD/task-decompose.md" && ok || ko "task-decompose.md task template lacks **Gate:**"
for f in task-decompose.md implement.md; do
  grep -q '^- \*\*Owner approval:\*\*' "$CMD/$f" && ok || ko "$f Pipeline State lacks **Owner approval:**"
done
grep -q '^| An agent reports `BLOCKED` with a reason' "$CMD/implement.md" && ok || ko "implement.md routing table has no BLOCKED row"
grep -q '^\*\*Owner gate first.\*\*' "$CMD/implement.md" && ok || ko "implement.md Step 1 lacks the owner gate"

# Nothing else creates .claude/device-e2e/project.md; device-tester reports BLOCKED without it.
E2E_INIT="$AGENTS/device-e2e/commands/init.md"
[ -f "$E2E_INIT" ] && grep -q 'do not write to it' "$E2E_INIT" && grep -q 'skills/playbook/project.template.md' "$E2E_INIT" \
  && ok || ko "device-e2e/commands/init.md missing, or it may overwrite / names no template"
grep -q '/device-e2e:init' "$CMD/task-decompose.md" && ok || ko "task-decompose.md does not point device tasks to /device-e2e:init"

# A budget question that does not quote the Part A rule gets an answer spec-validate then rejects: one wasted round
# trip. spec-create writes the scoped exception; spec-validate accepts that same form.
grep -q 'A performance or budget question quotes the Part A rule' "$CMD/spec-create.md" && grep -q 'Exception to <rule name>' "$CMD/spec-create.md" \
  && ok || ko "spec-create.md does not quote the Part A rule or record the scoped exception"
grep -q 'unless §3 \*Performance / NFRs\* records an exception' "$CMD/spec-validate.md" && ok || ko "spec-validate.md rejects a recorded budget exception"
# An exception spec-validate accepts but no prompt carries is a budget the reviewer still enforces at the old limit.
e=$(grep -c '<EXCEPTION_LINES>' "$CMD/implement.md")
[ "$e" -ge 2 ] && ok || ko "implement.md passes budget exceptions to $e of the review prompts (want round 1 and delta)"
# A prior finding the fix did not close goes back to the coder; it is neither a regression nor a C4 spec doubt.
grep -q "fix the regressions plus every prior finding verdicted \`NOT CLOSED\`" "$CMD/implement.md" && ok || ko "implement.md does not route NOT CLOSED findings back to the fix"

echo "templates: pass=$pass fail=$fail"
[ "$fail" = 0 ]
