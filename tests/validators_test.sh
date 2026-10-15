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

# A missing pitfalls/brief file is a broken setup, not an unknown rule: FATAL + exit 2, never a silent UNKNOWN.
expect_out() {
  want=$1 pat=$2; shift 2
  out=$(cd "$PROJ" && REVIEW_LOOP_PROJECT_DIR="$PROJ" "$@" 2>&1); got=$?
  case "$got:$out" in "$want:"*"$pat"*) pass=$((pass+1)) ;; *) fail=$((fail+1)); echo "FAIL want $want + '$pat', got $got: $*"; echo "$out" | head -5 ;; esac
}
ln -s "$PROJ/nowhere.md" "$PROJ/dangling.md"
expect_out 2 "missing pitfalls" env PITFALLS_FILE=/nonexistent "$BIN/validate_rule_ids.sh" R-PIT-1.1
expect_out 2 "missing brief" env BRIEF_FILE=/nonexistent "$BIN/validate_rule_ids.sh" R-NN-1
expect_out 2 "broken symlink" env PITFALLS_FILE="$PROJ/dangling.md" "$BIN/validate_rule_ids.sh" R-PIT-1.1
expect_out 0 "OK      R-NN-1" env PITFALLS_FILE=/nonexistent "$BIN/validate_rule_ids.sh" R-NN-1
expect_out 0 "OK      R-PIT-1.1" env BRIEF_FILE=/nonexistent "$BIN/validate_rule_ids.sh" R-PIT-1.1

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
expect_out 2 "missing routing" env ROUTING_FILE=/nonexistent "$BIN/validate_spec_refs.sh" "$PROJ/docs/features/sync/sync_tasks.md"
expect_out 0 "result=OK" env ROUTING_FILE=/nonexistent "$BIN/validate_spec_refs.sh" docs/features/sync/spec_sync.md

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


printf 'See `src/app.dart` and `./src/app.dart`.\n' > "$PROJ/docs/features/sync/rooted.md"
printf 'See `lib/widgets/button.dart` for the pattern.\n' > "$PROJ/docs/features/sync/unrooted.md"
expect 0 "$BIN/validate_spec_refs.sh" docs/features/sync/rooted.md
expect 1 "$BIN/validate_spec_refs.sh" docs/features/sync/unrooted.md
out=$(cd "$PROJ" && REVIEW_LOOP_PROJECT_DIR="$PROJ" "$BIN/validate_spec_refs.sh" docs/features/sync/unrooted.md 2>&1)
case "$out" in *"UNROOTED lib/widgets/button.dart"*) pass=$((pass+1)) ;; *) fail=$((fail+1)); echo "FAIL unrooted path not reported: $out" ;; esac

PORT_FILE="$PROJ/port"
python3 - "$PORT_FILE" <<'PYSRV' &
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _reply(self, code, body=b""):
        self.send_response(code); self.send_header("Content-Length", str(len(body))); self.end_headers()
        if self.command != "HEAD": self.wfile.write(body)
    def do_HEAD(self): self._reply(404)
    def do_GET(self): self._reply(200 if self.path == "/head-404-get-200" else 404, b"x")
s = HTTPServer(("127.0.0.1", 0), H)
open(sys.argv[1], "w").write(str(s.server_address[1]))
s.serve_forever()
PYSRV
SRV=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$PORT_FILE" ] && break; sleep 0.2; done
PORT=$(cat "$PORT_FILE")
expect 0 "$BIN/validate_citations.sh" "http://127.0.0.1:$PORT/head-404-get-200"
expect 1 "$BIN/validate_citations.sh" "http://127.0.0.1:$PORT/really-gone"
kill "$SRV" 2>/dev/null; wait "$SRV" 2>/dev/null

echo "validators: pass=$pass fail=$fail"
[ "$fail" = 0 ]
