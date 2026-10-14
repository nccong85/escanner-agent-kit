#!/usr/bin/env bash
ROOT="${REVIEW_LOOP_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"
CONTEXT_DIR="${CONTEXT_DIR:-$ROOT/.claude/review-loop}"
if [ -f "$CONTEXT_DIR/config.env" ]; then
  . "$CONTEXT_DIR/config.env"
fi
export BRIEF="${BRIEF_FILE:-$CONTEXT_DIR/review_brief.md}"
export RULES="${RULES_FILE:-$CONTEXT_DIR/review_rules.md}"
export ROUTING="${ROUTING_FILE:-$CONTEXT_DIR/routing.md}"
export PITFALLS="${PITFALLS_FILE:-$CONTEXT_DIR/common_pitfalls.md}"
export SPECS_DIR="${SPECS_DIR:-$ROOT/docs/specs}"
export FEATURES_DIR="${FEATURES_DIR:-$ROOT/docs/features}"
