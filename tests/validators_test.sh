#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$HERE/plugins/review-loop/bin"
TPL="$HERE/plugins/review-loop/templates"
PROJ="$(mktemp -d "${TMPDIR:-/tmp}/rl_fixture.XXXXXX")"
trap 'rm -rf "$PROJ"' EXIT

mkdir -p "$PROJ/.claude/review-loop" "$PROJ/.claude/agents" "$PROJ/src" "$PROJ/docs/features/sync"
cp "$TPL/review_brief.md" "$TPL/review_rules.md" "$TPL/routing.md" "$PROJ/.claude/review-loop/"
cat > "$PROJ/.claude/review-loop/common_pitfalls.md" <<'EOF'
## 1. State
### 1.1 Listener leaks
## 2. Logging
EOF
printf '| `R-BUD-cold-start` | cold start < 2 s |\n' >> "$PROJ/.claude/review-loop/review_rules.md"
printf '| `my-stack:review-x` |\n' >> "$PROJ/.claude/review-loop/routing.md"
touch "$PROJ/.claude/agents/dev-local.md" "$PROJ/src/app.dart" "$PROJ/docs/features/sync/spec_sync.md"

pass=0; fail=0
expect() {
  want=$1; shift
  out=$(cd "$PROJ" && REVIEW_LOOP_PROJECT_DIR="$PROJ" "$@" 2>&1); got=$?
  if [ "$got" = "$want" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL want $want got $got: $*"; echo "$out" | head -5; fi
}

expect 0 "$BIN/validate_rule_ids.sh" R-PIT-1 R-PIT-1.1 R-PIT-2 R-NN-1 R-NN-3 R-BUD-cold-start R-SPEC-sync§2 R-DOD-4 R-REQ
expect 1 "$BIN/validate_rule_ids.sh" R-PIT-1.2
expect 1 "$BIN/validate_rule_ids.sh" R-PIT-9
expect 1 "$BIN/validate_rule_ids.sh" R-NN-7
expect 1 "$BIN/validate_rule_ids.sh" R-BUD-ram
expect 1 "$BIN/validate_rule_ids.sh" R-SPEC-ghost§1
expect 1 "$BIN/validate_rule_ids.sh" R-DOD-x
expect 2 "$BIN/validate_rule_ids.sh"

cat > "$PROJ/docs/features/sync/sync_tasks.md" <<'EOF'
## Task 1: a
**Agent:** dev-local
Reference: src/app.dart
## Task 2: b
**Agent:** `my-stack:review-x` (notes)
## Task 3: c
**Agent:** main session
EOF
expect 0 "$BIN/validate_spec_refs.sh" "$PROJ/docs/features/sync/sync_tasks.md"

cat > "$PROJ/docs/features/sync/bad_tasks.md" <<'EOF'
## Task 1: a
**Agent:** dev-lokal
Reference: src/missing.dart
EOF
expect 1 "$BIN/validate_spec_refs.sh" "$PROJ/docs/features/sync/bad_tasks.md"

echo "validators: pass=$pass fail=$fail"
[ "$fail" = 0 ]
