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

TPLPROJ="$PROJ/tplonly"; mkdir -p "$TPLPROJ/.claude/review-loop"
cp "$TPL/review_brief.md" "$TPL/review_rules.md" "$TPL/common_pitfalls.md" "$TPLPROJ/.claude/review-loop/"
out=$(cd "$TPLPROJ" && REVIEW_LOOP_PROJECT_DIR="$TPLPROJ" "$BIN/validate_rule_ids.sh" R-PIT-1 R-PIT-1.1 2>&1); got=$?
if [ "$got" = 1 ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL template pitfalls must not resolve R-PIT-1 (got $got)"; fi


git -C "$PROJ" init -q
printf 'line one\nfinal value = compute(a, b);\nline three\nline four\nline five\nline six\nline seven\nline eight\nline nine\nline ten\n' > "$PROJ/src/lib.dart"
git -C "$PROJ" add src/lib.dart
git -C "$PROJ" -c user.email=t@t -c user.name=t commit -qm init
sed -i.bak 's/line nine/line nine changed/' "$PROJ/src/lib.dart" && rm -f "$PROJ/src/lib.dart.bak"
printf 'brand new file\n' > "$PROJ/src/new.dart"
VF="$BIN/validate_findings.sh"
expect 0 "$VF" src/lib.dart:9 'line nine changed'
expect 0 "$VF" src/lib.dart:2 'final   value = compute(a, b);'
expect 0 "$VF" src/new.dart:1 'brand new'
expect 1 "$VF" src/missing.dart:3 'anything'
expect 1 "$VF" src/lib.dart:40 'line one'
expect 1 "$VF" src/lib.dart:9 'value = compute(x, y)'
expect 1 "$VF" src/lib.dart:9 ''
expect 1 "$VF" src/lib.dart 'line one'
expect 2 "$VF" src/lib.dart:9
expect 0 "$VF" src/lib.dart:9:12 'line nine changed'
expect 0 "$VF" '`src/lib.dart:9`' '`line nine changed`'
expect 0 "$VF" src/lib.dart:9-10:3 '"line nine changed"'
expect 1 "$VF" src/lib.dart:9:x 'line nine changed'
out=$(cd "$PROJ" && REVIEW_LOOP_PROJECT_DIR="$PROJ" "$VF" src/lib.dart:9 '``' 2>&1); got=$?
case "$got:$out" in 1:MISSING_QUOTE*) pass=$((pass+1)) ;; *) fail=$((fail+1)); echo "FAIL empty quote must be MISSING_QUOTE, got $got: $out" ;; esac
out=$(cd "$PROJ" && REVIEW_LOOP_PROJECT_DIR="$PROJ" "$VF" src/lib.dart:2 'final value' 2>&1); got=$?
case "$got:$out" in "0:OUT_OF_DIFF"*) pass=$((pass+1)) ;; *) fail=$((fail+1)); echo "FAIL unchanged line must be OUT_OF_DIFF with exit 0, got $got: $out" ;; esac
out=$(cd "$PROJ" && REVIEW_LOOP_PROJECT_DIR="$PROJ" "$VF" src/lib.dart:9-10 'line nine changed' src/lib.dart:1 'nope' 2>&1); got=$?
case "$got:$out" in 1:OK*NO_QUOTE*) pass=$((pass+1)) ;; *) fail=$((fail+1)); echo "FAIL mixed batch, got $got: $out" ;; esac

echo "validators: pass=$pass fail=$fail"
[ "$fail" = 0 ]
