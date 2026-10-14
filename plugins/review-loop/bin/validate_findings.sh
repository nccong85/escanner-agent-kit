#!/usr/bin/env bash
set -uo pipefail

usage() {
  echo "usage: $(basename "$0") [--base <rev>] <path:line[-line]> <quote> [<path:line> <quote> ...]" >&2
  echo "  NO_FILE / NO_LINE / NO_QUOTE drop the finding; MISSING_QUOTE asks the reviewer for one (exit 1 for all four)." >&2
  echo "  OUT_OF_DIFF only flags the finding (exit 0)." >&2
  exit 2
}

ROOT="${REVIEW_LOOP_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"
BASE="HEAD"
if [ "${1:-}" = "--base" ]; then
  [ $# -ge 2 ] || usage
  BASE="$2"; shift 2
fi
[ $# -ge 2 ] && [ $(( $# % 2 )) -eq 0 ] || usage

squash() { tr -s ' \t\r\n' ' ' | sed -e 's/^ //' -e 's/ $//'; }

in_diff() {
  local path="$1" lo="$2" hi="$3" hunk c d
  if ! git -C "$ROOT" ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
    return 0
  fi
  while IFS= read -r hunk; do
    hunk="${hunk#*+}"; hunk="${hunk%% *}"
    c="${hunk%%,*}"
    if [ "$c" = "$hunk" ]; then d=1; else d="${hunk#*,}"; fi
    [ "$d" -eq 0 ] && d=1
    if [ "$c" -le "$hi" ] && [ $(( c + d - 1 )) -ge "$lo" ]; then
      return 0
    fi
  done < <(git -C "$ROOT" diff -U0 "$BASE" -- "$path" 2>/dev/null | grep -E '^@@ ')
  return 1
}

bad=0
while [ $# -gt 0 ]; do
  loc="$1"; quote="$2"; shift 2
  loc="${loc#\`}"; loc="${loc%\`}"
  if [[ "$loc" =~ ^(.+):([0-9]+(-[0-9]+)?):[0-9]+$ ]]; then loc="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}"; fi
  path="${loc%:*}"; range="${loc##*:}"
  start="${range%%-*}"; end="${range#*-}"
  case "$start$end" in
    *[!0-9]*|'') echo "NO_LINE      $loc  (not path:line)"; bad=1; continue ;;
  esac
  [ "$path" = "$loc" ] && { echo "NO_LINE      $loc  (not path:line)"; bad=1; continue; }
  [ "$end" -lt "$start" ] && end="$start"
  file="$path"; case "$file" in /*) ;; *) file="$ROOT/$path" ;; esac
  if [ ! -f "$file" ]; then echo "NO_FILE      $loc"; bad=1; continue; fi
  total=$(wc -l < "$file" | tr -d ' ')
  if [ "$start" -lt 1 ] || [ "$start" -gt $(( total + 1 )) ]; then
    echo "NO_LINE      $loc  (file has $total lines)"; bad=1; continue
  fi
  want=$(printf '%s' "$quote" | squash)
  case "$want" in \`*\`|\"*\") want="${want:1:${#want}-2}" ;; esac
  if [ -z "$want" ]; then echo "MISSING_QUOTE $loc"; bad=1; continue; fi
  lo=$(( start > 3 ? start - 3 : 1 )); hi=$(( end + 3 ))
  window=$(sed -n "${lo},${hi}p" "$file" | squash)
  case "$window" in
    *"$want"*) ;;
    *) echo "NO_QUOTE     $loc  (quote not found within ±3 lines)"; bad=1; continue ;;
  esac
  rel="${file#"$ROOT"/}"
  if in_diff "$rel" "$lo" "$hi"; then echo "OK           $loc"; else echo "OUT_OF_DIFF  $loc"; fi
done
exit $bad
