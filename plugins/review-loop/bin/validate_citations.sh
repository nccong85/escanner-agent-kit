#!/usr/bin/env bash
# Deterministic citation checker for research reports (see the dev-pipeline research command, Step 4).
#
# Usage:
#   validate_citations.sh docs/research/some_report_20260812.md
#   validate_citations.sh <url> [<url> ...]
#
# Why this exists: research agents are measured at 3-13% FABRICATED citation URLs (no record they
# ever existed) and 5-18% non-resolving. That is a machine-checkable property, so it should be
# checked by a script -- not argued about by a model, and not taken on trust.
#
# Exit 0 = no dead citations. Exit 1 = at least one DEAD.
#
# It deliberately does NOT fail on 403/429/timeouts: a Cloudflare challenge or a rate limit is not
# evidence of fabrication, and treating it as such would train everyone to ignore this script.
# Those are reported as NEEDS-EYES and left to a human.

set -uo pipefail

TIMEOUT="${CITE_TIMEOUT:-12}"
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36'

command -v curl >/dev/null || { echo "FATAL: curl not found"; exit 2; }
[ $# -gt 0 ] || { echo "usage: $(basename "$0") <report.md | url...>"; exit 2; }

# macOS ships bash 3.2 (no `mapfile`), so URLs go through a temp file, not an array.
URLFILE="$(mktemp "${TMPDIR:-/tmp}/citeurls.XXXXXX")" || { echo "FATAL: mktemp failed"; exit 2; }
trap 'rm -f "$URLFILE"' EXIT

if [ -f "$1" ]; then
  # markdown links, angle-bracketed, and bare URLs; strip trailing punctuation
  grep -oE 'https?://[^][ )<>"`'"'"']+' "$1" | sed -E 's/[.,;:]+$//' | sort -u > "$URLFILE"
else
  printf '%s\n' "$@" > "$URLFILE"
fi

total=$(grep -c . "$URLFILE" || true)
[ "${total:-0}" -gt 0 ] || { echo "No URLs found in $1 — nothing to check."; exit 0; }

dead=0; eyes=0; ok=0
printf '%-9s %s\n' "STATUS" "URL"
printf '%s\n' "----------------------------------------------------------------------"

while IFS= read -r u; do
  [ -n "$u" ] || continue
  # HEAD first; many servers answer HEAD differently from a browser GET (Google help pages return 404 to
  # HEAD and 200 to GET), so any non-success HEAD is re-checked with a 1-byte ranged GET before judging.
  code=$(curl -sS -o /dev/null -w '%{http_code}' -I -L --max-time "$TIMEOUT" -A "$UA" "$u" 2>/dev/null)
  case "${code:-000}" in 2??|3??) ;; *) code=retry ;; esac
  if [ "$code" = "retry" ]; then
    code=$(curl -sS -o /dev/null -w '%{http_code}' -L --max-time "$TIMEOUT" -A "$UA" \
                -r 0-0 "$u" 2>/dev/null)
  fi
  case "${code:-000}" in
    2??|3??|416)  printf '%-9s %s\n' "OK"        "$u"; ok=$((ok+1)) ;;
    404|410)      printf '%-9s %s  (HTTP %s)\n' "DEAD"  "$u" "$code"; dead=$((dead+1)) ;;
    000)          printf '%-9s %s  (no response / DNS)\n' "DEAD" "$u"; dead=$((dead+1)) ;;
    401|403|429)  printf '%-9s %s  (HTTP %s — blocked or rate-limited, NOT proof of fabrication)\n' \
                         "NEEDS-EYES" "$u" "$code"; eyes=$((eyes+1)) ;;
    *)            printf '%-9s %s  (HTTP %s)\n' "NEEDS-EYES" "$u" "$code"; eyes=$((eyes+1)) ;;
  esac
done < "$URLFILE"

echo
echo "resolved=$ok  dead=$dead  needs-eyes=$eyes  total=$total"

if [ "$dead" -gt 0 ]; then
  echo
  echo "REJECTED: a DEAD citation is either fabricated or rotted. Do not ship the report with it."
  echo "  - Fabricated (never existed): delete the claim, or re-research it. Do NOT 'fix' the URL"
  echo "    by guessing a plausible one -- that is how the fabrication got there."
  echo "  - Rotted (existed, now gone): cite an archive snapshot and say so, or mark [Unverified]."
  exit 1
fi

if [ "$eyes" -gt 0 ]; then
  echo "Note: NEEDS-EYES entries were not reachable from this machine. Confirm them in a browser"
  echo "before treating them as sources; do not silently upgrade them to verified."
fi
exit 0
