#!/usr/bin/env bash
# Deterministic validator for review finding rule IDs (review_rules.md).
# Usage: validate_rule_ids.sh R-PIT-9.3 R-NN-5 R-BUD-cold-start ...
# Exit 0 = every ID resolves. Exit 1 = at least one does not; unknown IDs are printed.
# The orchestrator runs this instead of asking a model whether a finding is in scope.

set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib_config.sh"
shopt -s globstar nullglob 2>/dev/null || true

[ -f "$RULES" ] || { echo "FATAL: missing rules index $RULES (run /review-gate:init)"; exit 2; }
[ $# -gt 0 ] || { echo "usage: $(basename "$0") <RULE_ID>..."; exit 2; }
# Check the pitfalls/brief files only for the families actually cited, so a project that never cites one
# family need not keep its file. A missing file used to turn every such ID into a silent UNKNOWN, and the
# orchestrator dropped all of them.
for id in "$@"; do
  case "$id" in
    R-PIT-*) require_file "$PITFALLS" pitfalls ;;
    R-NN-*) require_file "$BRIEF" brief ;;
  esac
done

bad=0
for id in "$@"; do
  ok=0
  case "$id" in
    R-PIT-*)
      n="${id#R-PIT-}"
      # `### 9.3` for a sub-entry, `## 10.` for a whole section
      if { grep -qE "^### ${n//./\\.}[ .]" "$PITFALLS" || grep -qE "^## ${n//./\\.}\. " "$PITFALLS"; }; then
        ok=1
      fi
      ;;
    R-NN-*)
      n="${id#R-NN-}"
      case "$n" in
        ''|*[!0-9]*) ok=0 ;;
        *) grep -qE "^${n}\. " "$BRIEF" && ok=1 ;;
      esac
      ;;
    R-SPEC-*)
      # Normative specs live in TWO places: cross-cutting ones under SPECS_DIR, and per-feature
      # ones at FEATURES_DIR/<f>/spec_<f>.md. Resolving only the first silently rejected an entire
      # contract review once (6 of 11 blocking findings, including a Critical).
      f="${id#R-SPEC-}"; f="${f%%§*}"
      if [ -n "$f" ]; then
        if compgen -G "$SPECS_DIR/*${f}*" >/dev/null \
           || compgen -G "$FEATURES_DIR/*${f}*/spec_*.md" >/dev/null \
           || compgen -G "$FEATURES_DIR/**/*${f}*.md" >/dev/null; then
          ok=1
        fi
      fi
      ;;
    R-DOD-*)
      n="${id#R-DOD-}"
      case "$n" in ''|*[!0-9]*) ok=0 ;; *) ok=1 ;; esac
      ;;
    R-REQ)
      ok=1
      ;;
    R-*-*)
      # Every other namespace (R-BUD-*, a stack's own R-<NS>-*) is a row in the rules index.
      grep -qE "^\| \`${id}\` \|" "$RULES" && ok=1
      ;;
  esac
  if [ "$ok" -eq 1 ]; then
    printf 'OK      %s\n' "$id"
  else
    printf 'UNKNOWN %s\n' "$id"
    bad=1
  fi
done

if [ "$bad" -ne 0 ]; then
  echo
  echo "REJECTED: a finding citing an unresolvable rule ID is dropped, not fixed."
  echo
  echo "Most common cause: a pitfalls section with NO numbered sub-entries, so R-PIT-<n>.<m> does"
  echo "not exist. Cite the section instead (R-PIT-<n>) and name the sub-heading in the finding text."
  echo "Check first with:  grep -nE '^#{2,3} <n>' $PITFALLS"
  echo
  echo "If the rule is genuinely new: fix it, add a Symptom->Cause->Rule entry to the pitfalls file,"
  echo "then cite the new R-PIT-<n>.<m>."
  exit 1
fi
exit 0
