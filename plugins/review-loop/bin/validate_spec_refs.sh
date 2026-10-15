#!/usr/bin/env bash
# Deterministic reference checker for specs and task breakdowns.
#
# Usage:
#   validate_spec_refs.sh docs/features/<f>/spec_<f>.md
#   validate_spec_refs.sh docs/features/<f>/<f>_tasks.md
#
# Checks two things a model should never be trusted to eyeball:
#   1. Every repo path the document cites actually exists.
#      ("Reference files cited don't exist in the repo" is an auto-Not-Ready red flag in
#       /dev:spec-validate, and it is the only red flag on that list a machine can settle.)
#   2. Every `**Agent:** <name>` in a task breakdown names an agent the routing file declares
#      (or a project agent in .claude/agents/).
#      A typo there makes /dev:implement dispatch a subagent_type that does not exist.
#
# Exit 0 = all references resolve. Exit 1 = at least one does not.
#
# Placeholders are SKIPPED, not failed: a path containing < > { } * or an ellipsis is a
# template slot, not a claim about the repo. So is a path the document says it will CREATE
# ("new src/…"), and so is prose that merely contains a slash ("native/OCR pipeline") —
# only a token with a real file extension, or an explicit directory, is treated as a path claim.
#
# SCOPE: run this on the spec you are AUTHORING or VALIDATING, not retroactively across the
# archive. A finished spec that cites a file some later commit deleted is history, not a defect —
# sweeping 127 old spec/tasks files once left 33 failures, dominated by exactly that. The value of this check is at authoring time, where a bad path is still cheap to fix.

set -uo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib_config.sh"
AGENTS="$ROOT/.claude/agents"
TOPS=$(cd "$ROOT" && for d in */ .claude/; do [ -d "$d" ] && printf '%s|' "${d%/}"; done | sed -e 's/|$//' -e 's/\./\\./g')
[ -n "$TOPS" ] || TOPS='\.claude'

[ $# -gt 0 ] || { echo "usage: $(basename "$0") <spec-or-tasks.md>..."; exit 2; }

bad=0; checked=0; skipped=0; planned=0; unrooted=0

is_placeholder() {
  case "$1" in
    *"<"*|*">"*|*"{"*|*"}"*|*"*"*|*"..."*|*"…"*|*'$'*) return 0 ;;
    *) return 1 ;;
  esac
}

for doc in "$@"; do
  [ -f "$doc" ] || { echo "FATAL: no such file: $doc"; exit 2; }
  echo "##### $doc"

  # ---- 1. repo paths -------------------------------------------------------
  # Capture up to 24 chars of preceding context with each path, so a path the spec says it will
  # CREATE is not reported as missing. A spec's "Key files to create/modify" table legitimately
  # names files that do not exist yet; failing those would make this checker cry wolf on every
  # new-feature spec, and a checker that cries wolf gets ignored.
  hits=$(grep -oE ".{0,24}($TOPS)/[^][ \`)(\",;:]+" "$doc" \
         | sed -E 's/[.,;:]+$//' | sort -u)

  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    # split the captured chunk into <prefix><path>
    p=$(printf '%s' "$hit" | grep -oE "($TOPS)/[^][ \`)(\",;:]+" | tail -1)
    [ -n "$p" ] || continue
    prefix=${hit%"$p"}
    # planned-file markers immediately before the path
    case "$prefix" in
      *new\ *|*New\ *|*NEW\ *|*create*|*Create*|*add\ *|*Add\ *)
        planned=$((planned+1)); continue ;;
    esac
    # Strip a directory suffix FIRST — `app/lib/core/ffi/**` is a directory claim, not a template
    # slot. Testing is_placeholder before this made every `path/**` citation skip silently, so the
    # dir branch below could never fire: a bogus `app/lib/core/ghostdir/**` passed. That is the
    # "guard that cannot fail" shape, caught by probing it rather than reading it.
    isdir=0
    case "$p" in *"/**"|*"/*"|*/) isdir=1 ;; esac
    clean="${p%/\*\*}"; clean="${clean%/\*}"; clean="${clean%/}"

    if is_placeholder "$clean"; then skipped=$((skipped+1)); continue; fi
    # Only a real file extension, or an explicit directory, is a path claim.
    # "native/OCR", "app/engine", "native/FFI" are English prose that happens to contain a slash.
    if [ "$isdir" -eq 0 ]; then
      case "$clean" in
        *.dart|*.md|*.cpp|*.cc|*.c|*.h|*.hpp|*.sh|*.yaml|*.yml|*.json|*.kt|*.kts|*.swift|*.go|*.rs|*.py|*.ts|*.tsx|*.js|*.cs|*.csproj|*.xaml|*.sql|*.txt|*.toml|*.plist|*.xcprivacy|*.cmake|*.gradle|*.podspec|*.arb|*.png|*.svg) ;;
        *) skipped=$((skipped+1)); continue ;;
      esac
    fi
    checked=$((checked+1))
    if [ ! -e "$ROOT/$clean" ]; then
      printf '  MISSING  %s\n' "$p"
      bad=1
    fi
  done <<EOF
$hits
EOF

  while IFS= read -r u; do
    [ -n "$u" ] || continue
    u="${u#./}"
    if is_placeholder "$u"; then continue; fi
    case "$u" in
      *.dart|*.md|*.cpp|*.cc|*.c|*.h|*.hpp|*.sh|*.yaml|*.yml|*.json|*.kt|*.kts|*.swift|*.go|*.rs|*.py|*.ts|*.tsx|*.js|*.cs|*.csproj|*.xaml|*.sql|*.txt|*.toml|*.plist|*.xcprivacy|*.cmake|*.gradle|*.podspec|*.arb|*.png|*.svg) ;;
      *) continue ;;
    esac
    if printf '%s' "${u%%/*}" | grep -qE "^($TOPS)$"; then continue; fi
    printf '  UNROOTED %s  (write it from the repo root, or it is never checked)\n' "$u"
    unrooted=$((unrooted+1)); bad=1
  done <<EOF
$(grep -oE '(^|[[:space:]`(|])\.?/?[A-Za-z0-9_@-][A-Za-z0-9_.@-]*(/[A-Za-z0-9_.@+-]+)+' "$doc" | sed -E 's/^[[:space:]`(|]//; s/[.,;:]+$//' | sort -u)
EOF

  # ---- 2. Agent: fields ----------------------------------------------------
  # Real rows look like: **Agent:** `dev-flutter`  /  my-plugin:review-x (notes) + owner-contract
  # so: strip markdown, split on + and , and ;, cut prose after the first '(' or '_' or em-dash,
  # then keep only a bare agent-name token.
  agents=$(grep -oE '^\*\*Agent:\*\*[^|]*' "$doc" 2>/dev/null \
           | sed -E 's/^\*\*Agent:\*\* *//' \
           | tr '+,;' '\n\n\n' \
           | sed -E 's/[`*_]//g; s/\(.*$//; s/—.*$//; s/^ +//; s/ +$//' \
           | grep -oE '^[a-z][a-z0-9-]*(:[a-z][a-z0-9-]+)?$' \
           | grep -vE '^(none|owner|na|main)$' | sort -u)
  # A missing routing file would report every plugin agent MISSING without naming the real cause.
  [ -z "$agents" ] || require_file "$ROUTING" routing
  while IFS= read -r a; do
    [ -n "$a" ] || continue
    case "$a" in none|None|N/A|-) continue ;; esac
    if is_placeholder "$a"; then skipped=$((skipped+1)); continue; fi
    checked=$((checked+1))
    if [ ! -f "$AGENTS/${a#*:}.md" ] && ! grep -qF "\`$a\`" "$ROUTING"; then
      printf '  MISSING  agent "%s" (not in %s, no .claude/agents/%s.md)\n' "$a" "$ROUTING" "${a#*:}"
      bad=1
    fi
  done <<EOF
$agents
EOF
done

echo
echo "checked=$checked  unrooted=$unrooted  planned-not-yet-created=$planned  skipped-placeholders=$skipped  result=$([ $bad -eq 0 ] && echo OK || echo FAILED)"

if [ "$bad" -ne 0 ]; then
  echo
  echo "REJECTED: a spec that cites files which do not exist cannot be implemented from."
  echo "  - Wrong path      -> fix the citation."
  echo "  - UNROOTED        -> the path is relative to a subfolder; cite it from the repo root."
  echo "  - Renamed/deleted -> the spec is stale; re-ground it before decomposing."
  echo "  - Not built yet   -> say so explicitly ('to be created'), don't cite it as a reference."
  exit 1
fi
exit 0
