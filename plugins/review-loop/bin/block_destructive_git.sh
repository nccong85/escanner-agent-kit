#!/bin/bash
mode="${1:-auto}"
input=$(cat)

field() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r "$1 // empty"
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$input" | python3 -c 'import json,sys
d=json.load(sys.stdin)
for k in sys.argv[1].lstrip(".").split("."):
    d=d.get(k,"") if isinstance(d,dict) else ""
print(d if isinstance(d,str) else "")' "$1"
  else
    return 2
  fi
}

cmd=$(field '.tool_input.command')
if [ $? -eq 2 ]; then
  case "$input" in
    *git*) echo "Blocked: block_destructive_git.sh needs jq or python3 to inspect git commands." >&2; exit 2 ;;
    *) exit 0 ;;
  esac
fi
[ -z "$cmd" ] && exit 0
cwd=$(field '.cwd'); [ -n "$cwd" ] || cwd="$PWD"

if [ "$mode" = "auto" ]; then
  if [ -n "$(field '.agent_id')" ]; then mode=subagent; else mode=main; fi
fi

block() {
  echo "Blocked: $1. The working tree is uncommitted and may be shared by several tasks/sessions. Restore a mutated file from a cp backup. If you really want this, run it yourself (in Claude Code: prefix the command with !)." >&2
  exit 2
}

danger_word='(checkout|switch|restore|stash|clean|reset|worktree|update-ref|filter-branch|filter-repo)'
has_danger=0
printf '%s' "$cmd" | grep -Eq "(^|[^A-Za-z0-9_-])${danger_word}([^A-Za-z0-9_-]|$)" && has_danger=1
if [ "$has_danger" = 1 ]; then
  indirect='\$\{?GIT([^A-Za-z0-9_]|$)|(^|[[:space:];&|(])eval[[:space:]][^;&|]*git|-c[[:space:]]+alias\.|git[[:space:]]+config[^;&|]*alias\.|\$\([^)]*git[^)]*\)[[:space:]]+'"${danger_word}"
  if printf '%s' "$cmd" | grep -Eq "$indirect"; then
    block "a git command built through an alias, a variable, eval or command substitution cannot be checked"
  fi
  if [ "$mode" = "subagent" ] && printf '%s' "$cmd" | grep -Eq '\$\(|`|(^|[[:space:];&|(])eval([[:space:]]|$)'; then
    block "subagents may not combine git verbs with command substitution or eval"
  fi
fi

reentry="(^|[[:space:];&|(])((ba|z)?sh[[:space:]]+-[a-z]*c|xargs)([[:space:]]|\$)"
if printf '%s' "$cmd" | grep -Eq "$reentry"; then
  scan="$cmd"
else
  scan=$(printf '%s' "$cmd" | sed -E "s/'[^']*'/Q/g; s/\"[^\"]*\"/Q/g")
fi

opt_with_value='(-[Cc]|--git-dir|--work-tree|--namespace|--super-prefix|--config-env)'
git_verb="(^|[;&|(){}[:space:]'\"/\\\\])git([[:space:]]+${opt_with_value}([[:space:]]+|=)[^[:space:]]+|[[:space:]]+--?[^[:space:]]+)*[[:space:]]+"
end="([[:space:]'\";&|)]|\$)"
has() { printf '%s' "$seg" | grep -Eq "${git_verb}$1"; }
only() { printf '%s' "$seg" | grep -Eq "${git_verb}$1[[:space:]]*\$"; }

checkout_args() {
  printf '%s' "$seg" | grep -Eo "${git_verb}checkout([[:space:]].*)?$" | head -1 \
    | sed -E "s/.*[[:space:]]checkout//; s/['\"]//g" | tr -s '[:space:]' '\n' | sed '/^$/d'
}

checkout_restores_paths() {
  local args a positional=0 creating=0 last=""
  args=$(checkout_args)
  [ -n "$args" ] || return 1
  while IFS= read -r a; do
    case "$a" in
      --|.) return 0 ;;
      -f|--force|-p|--patch|--ours|--theirs|--merge|-m) return 0 ;;
      -b|-B|--orphan|-c|-C) creating=1 ;;
      -*) ;;
      *) positional=$((positional+1)); last="$a" ;;
    esac
  done <<ARGS
$args
ARGS
  [ "$creating" = 1 ] && return 1
  [ "$positional" -ge 2 ] && return 0
  if [ "$positional" = 1 ] && [ -e "$cwd/$last" ] && ! git -C "$cwd" rev-parse --verify --quiet "$last^{commit}" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

check_subagent() {
  if has "(checkout|switch|restore|stash|clean|reset|commit|push|rebase|merge|cherry-pick|revert|rm|am|branch|worktree|update-ref|gc|reflog|filter-branch|filter-repo|tag)${end}"; then
    only "stash[[:space:]]+(create|list|show)([[:space:]][^;&|]*)?" && return 0
    only "branch(([[:space:]]+(--show-current|--list|-l|-a|--all|-r|--remotes|-v|-vv))*)" && return 0
    only "reflog([[:space:]]+show([[:space:]][^;&|]*)?)?" && return 0
    only "tag(([[:space:]]+(-l|--list))*)" && return 0
    block "subagents must not run git commands that change the working tree, index, refs or history (checkout/restore/stash/clean/reset/commit/push/branch/tag/...)"
  fi
  if has "apply${end}" && ! has "apply([[:space:]]+[^;&|]*)?[[:space:]]--check"; then
    block "subagents must not run git apply (use git apply --check to test a patch)"
  fi
}

check_main() {
  if has "checkout${end}" && checkout_restores_paths; then
    block "git checkout of paths (or with --force) discards uncommitted edits"
  fi
  if has "restore${end}"; then
    if ! has "restore[[:space:]]+(--staged|-S)${end}" || has "restore([[:space:]]+[^;&|]*)?[[:space:]](--worktree|-W|-SW|-WS)${end}"; then
      block "git restore discards uncommitted edits (only git restore --staged is allowed)"
    fi
  fi
  if has "stash${end}" && ! has "stash[[:space:]]+(create|list|show)${end}"; then
    block "git stash moves other sessions' uncommitted work out of the shared tree"
  fi
  if has "clean${end}" && ! has "clean([[:space:]]+[^;&|]*)?[[:space:]](-n|--dry-run)${end}"; then
    block "git clean deletes untracked files (git clean -n is allowed)"
  fi
  if has "reset([[:space:]]+[^;&|]*)?[[:space:]]--(hard|merge|keep)${end}"; then
    block "git reset --hard discards uncommitted edits"
  fi
  if has "worktree[[:space:]]+remove([[:space:]]+[^;&|]*)?[[:space:]](-f|--force)${end}"; then
    block "git worktree remove --force deletes a worktree with uncommitted edits"
  fi
}

segments=$(printf '%s' "$scan" | tr ';&|()' '\n\n\n\n\n')
while IFS= read -r seg; do
  [ -n "$seg" ] || continue
  if [ "$mode" = "subagent" ]; then check_subagent; else check_main; fi
done <<SEGS
$segments
SEGS
exit 0
