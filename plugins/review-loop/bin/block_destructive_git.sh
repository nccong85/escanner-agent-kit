#!/bin/bash
mode="${1:-auto}"
input=$(cat)
if command -v jq >/dev/null 2>&1; then
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
elif command -v python3 >/dev/null 2>&1; then
  cmd=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))')
else
  case "$input" in
    *git*) echo "Blocked: block_destructive_git.sh needs jq or python3 to inspect git commands." >&2; exit 2 ;;
    *) exit 0 ;;
  esac
fi
[ -z "$cmd" ] && exit 0
if [ "$mode" = "auto" ]; then
  if printf '%s' "$input" | grep -q '"agent_id"[[:space:]]*:[[:space:]]*"[^"]'; then mode=subagent; else mode=main; fi
fi

git_verb="(^|[;&|(){}[:space:]'\"/])git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+|[[:space:]]+--?[^[:space:]]+)*[[:space:]]+"
end="([[:space:]'\";&|)]|$)"
reentry="(^|[[:space:];&|(])((ba|z)?sh[[:space:]]+-[a-z]*c|eval|xargs)([[:space:]]|\$)"
if printf '%s' "$cmd" | grep -Eq "$reentry"; then
  scan="$cmd"
else
  scan=$(printf '%s' "$cmd" | sed -E "s/'[^']*'/Q/g; s/\"[^\"]*\"/Q/g")
fi
has() { printf '%s' "$scan" | grep -Eq "${git_verb}$1"; }

if [ "$mode" = "subagent" ]; then
  if has "(checkout|switch|restore|stash|clean|reset|commit|push|rebase|merge|cherry-pick|revert|rm|am)${end}" \
     && ! has "stash[[:space:]]+(create|list|show)${end}"; then
    reason="subagents must not run git commands that change the working tree, index or history (checkout/restore/stash/clean/reset/commit/push/...)"
  elif has "apply${end}" && ! has "apply([[:space:]]+[^;&|]*)?[[:space:]]--check"; then
    reason="subagents must not run git apply (use git apply --check to test a patch)"
  fi
else
  if has "checkout([[:space:]]+[^;&|]*)?[[:space:]](--|\.)${end}"; then
    reason="git checkout -- <path> / git checkout . discards uncommitted edits"
  elif has "restore${end}" && ! has "restore[[:space:]]+(--staged|-S)${end}"; then
    reason="git restore discards uncommitted edits (git restore --staged is allowed)"
  elif has "stash${end}" && ! has "stash[[:space:]]+(create|list|show)${end}"; then
    reason="git stash moves other sessions' uncommitted work out of the shared tree"
  elif has "clean${end}" && ! has "clean([[:space:]]+[^;&|]*)?[[:space:]](-n|--dry-run)${end}"; then
    reason="git clean deletes untracked files (git clean -n is allowed)"
  elif has "reset([[:space:]]+[^;&|]*)?[[:space:]]--(hard|merge|keep)${end}"; then
    reason="git reset --hard discards uncommitted edits"
  fi
fi

if [ -n "${reason:-}" ]; then
  echo "Blocked: ${reason}. The working tree is uncommitted and shared by several tasks/sessions. Restore a mutated file from a cp backup. If you really want this, run it yourself (in Claude Code: prefix the command with !)." >&2
  exit 2
fi
exit 0
