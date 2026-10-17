#!/usr/bin/env bash
ROOT="${REVIEW_GATE_PROJECT_DIR:-${REVIEW_LOOP_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}}"
# Before 2.0.0 the plugin was review-loop and its files lived in .claude/review-loop/. Keep reading them until
# /review-gate:init moves them, and say so on every run.
if [ -z "${CONTEXT_DIR:-}" ] && [ ! -e "$ROOT/.claude/review-gate" ] && [ -d "$ROOT/.claude/review-loop" ]; then
  echo "NOTE: reading .claude/review-loop/ (the pre-2.0 name); run /review-gate:init to move it to .claude/review-gate/" >&2
  CONTEXT_DIR="$ROOT/.claude/review-loop"
fi
CONTEXT_DIR="${CONTEXT_DIR:-$ROOT/.claude/review-gate}"

read_config() {
  local file="$1" line key value
  [ -f "$file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    key="${line%%=*}"
    value="${line#*=}"
    [ "$key" != "$line" ] || continue
    case "$key" in
      BRIEF_FILE|RULES_FILE|ROUTING_FILE|PITFALLS_FILE|SPECS_DIR|FEATURES_DIR) ;;
      *) echo "config.env: ignoring unknown key '$key'" >&2; continue ;;
    esac
    case "$value" in
      \"*\") value="${value#\"}"; value="${value%\"}" ;;
      \'*\') value="${value#\'}"; value="${value%\'}" ;;
    esac
    case "$value" in
      *'`'*|*'$('*|*'${'*|*';'*|*'|'*|*'&'*|*'<'*|*'>'*)
        echo "config.env: refusing $key — value may not contain \`, \$(, \${, ;, |, &, < or >" >&2
        continue ;;
    esac
    value="${value//\$CONTEXT_DIR/$CONTEXT_DIR}"
    value="${value//\$ROOT/$ROOT}"
    case "$value" in
      *'$'*) echo "config.env: refusing $key — only \$ROOT and \$CONTEXT_DIR may be referenced" >&2; continue ;;
    esac
    printf -v "CFG_$key" '%s' "$value"
  done < "$file"
}

read_config "$CONTEXT_DIR/config.env"

export BRIEF="${BRIEF_FILE:-${CFG_BRIEF_FILE:-$CONTEXT_DIR/review_brief.md}}"
export RULES="${RULES_FILE:-${CFG_RULES_FILE:-$CONTEXT_DIR/review_rules.md}}"
export ROUTING="${ROUTING_FILE:-${CFG_ROUTING_FILE:-$CONTEXT_DIR/routing.md}}"
export PITFALLS="${PITFALLS_FILE:-${CFG_PITFALLS_FILE:-$CONTEXT_DIR/common_pitfalls.md}}"
export SPECS_DIR="${SPECS_DIR:-${CFG_SPECS_DIR:-$ROOT/docs/specs}}"
export FEATURES_DIR="${FEATURES_DIR:-${CFG_FEATURES_DIR:-$ROOT/docs/features}}"

# require_file <path> <label>: a missing project file is a broken setup, never an empty result.
# Exit 2 so callers can tell "your files are broken" from "this ID/path does not resolve" (exit 1).
require_file() {
  [ -f "$1" ] && return 0
  if [ -L "$1" ]; then
    echo "FATAL: broken symlink for the $2 file: $1 -> $(readlink "$1") (fix the link or config.env)"
  else
    echo "FATAL: missing $2 file $1 (run /review-gate:init or fix config.env)"
  fi
  exit 2
}
