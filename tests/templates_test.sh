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

echo "templates: pass=$pass fail=$fail"
[ "$fail" = 0 ]
