#!/usr/bin/env bash
ROOT="${REVIEW_LOOP_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"
CONTEXT_DIR="${CONTEXT_DIR:-$ROOT/.claude/review-loop}"

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
