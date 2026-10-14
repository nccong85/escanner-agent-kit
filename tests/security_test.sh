#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
H="$HERE/plugins/review-loop/bin/block_destructive_git.sh"
BIN="$HERE/plugins/review-loop/bin"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/rl_sec.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

git -C "$WORK" init -q
echo v1 > "$WORK/notes.txt"
git -C "$WORK" add notes.txt
git -C "$WORK" -c user.email=t@t -c user.name=t commit -qm init
git -C "$WORK" branch feature

pass=0; fail=0
t() {
  exp=$1; mode=$2; c=$3; agent=${4:-}
  json=$(jq -n --arg c "$c" --arg cwd "$WORK" --arg a "$agent" \
    'if $a == "" then {cwd:$cwd, tool_input:{command:$c}} else {cwd:$cwd, agent_id:$a, tool_input:{command:$c}} end')
  printf '%s' "$json" | "$H" "$mode" >/dev/null 2>&1
  r=$?
  if [ "$r" = "$exp" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL [$mode${agent:+/$agent}] got $r want $exp: $c"; fi
}

for c in 'git checkout HEAD notes.txt' 'git checkout notes.txt' 'git checkout -f feature' 'git checkout --force feature' \
         'git checkout HEAD~1 -- notes.txt' 'git checkout -p' 'git restore --staged --worktree notes.txt' \
         'git restore -SW notes.txt' 'git worktree remove --force ../wt' 'git --work-tree . checkout -- notes.txt' \
         'git --git-dir=.git checkout -- notes.txt' '\git stash' 'GIT=git; $GIT stash' '${GIT} restore notes.txt' \
         "eval 'git reset --hard'" 'git -c alias.x=stash x' '$(command -v git) stash' "bash -c 'git checkout .'"; do
  t 2 main "$c"
done

for c in 'git checkout feature' 'git checkout -b feat/new' 'git checkout -b feat/two origin/main' 'git switch feature' \
         'git restore --staged notes.txt' "git commit -m 'explain why \`git restore\` is blocked'" \
         'git log --format=%h -1 $(git rev-parse HEAD)' 'cd "$(git rev-parse --show-toplevel)" && git status' \
         'git branch -D old' 'git worktree list' 'echo "do not run git stash here"'; do
  t 0 main "$c"
done

for c in 'git branch -D old' 'git update-ref -d refs/heads/x' 'git gc --prune=now' 'git tag v9' 'git reflog expire --all' \
         'git filter-branch --force' 'echo $(git stash)' 'git commit -m x'; do
  t 2 auto "$c" sub-1
done
for c in 'git branch --show-current' 'git branch -a' 'git tag -l' 'git reflog' 'git diff HEAD' 'git stash list'; do
  t 0 auto "$c" sub-1
done

t 2 main 'git commit -m "explain why `git restore .` is blocked"'
t 2 main 'git stash list && git stash'
t 2 auto 'git stash list && git stash' sub-1
t 2 auto 'git branch -a; git branch -D old' sub-1

for c in 'git "stash"' "git 'checkout' -- notes.txt" 'git "reset" --hard' 'g""it stash' 'git stas""h' \
         "git \$'stash'" 'git st\ash' $'git \\\nstash' $'git status\ngit stash' \
         $'git stash list\ngit stash'; do
  t 2 main "$c"
done
for c in 'git "commit" -m x' $'git \\\ncommit -m x' 'git "branch" -D old'; do
  t 2 auto "$c" sub-2
done
for c in 'grep -n "git restore" notes.txt' "rg 'git stash' docs" 'git commit -m "fix: keep stash out of the tree"' \
         "git commit -m 'restore'" 'git log --grep="reset"' 'echo "use git checkout -- carefully"' \
         $'git status\ngit log --oneline -1' 'git commit -m "$(printf done)"'; do
  t 0 main "$c"
done

PROJ="$WORK/proj"; mkdir -p "$PROJ/.claude/review-loop"
cp "$HERE/plugins/review-loop/templates/review_rules.md" "$PROJ/.claude/review-loop/"
printf '1. rule\n' > "$PROJ/.claude/review-loop/review_brief.md"
cat > "$PROJ/.claude/review-loop/config.env" <<EOF
RULES_FILE="\$(touch $WORK/pwned1)\$CONTEXT_DIR/review_rules.md"
BRIEF_FILE=\`touch $WORK/pwned2\`
SPECS_DIR=\$ROOT/docs/specs; touch $WORK/pwned3
PATH=/tmp/evil
EOF
( cd "$PROJ" && REVIEW_LOOP_PROJECT_DIR="$PROJ" "$BIN/validate_rule_ids.sh" R-NN-1 >/dev/null 2>&1 )
if ls "$WORK"/pwned* >/dev/null 2>&1; then fail=$((fail+1)); echo "FAIL config.env executed code"; else pass=$((pass+1)); fi

printf 'RULES_FILE="$CONTEXT_DIR/review_rules.md"\nBRIEF_FILE=$ROOT/.claude/review-loop/review_brief.md\n' > "$PROJ/.claude/review-loop/config.env"
if ( cd "$PROJ" && REVIEW_LOOP_PROJECT_DIR="$PROJ" "$BIN/validate_rule_ids.sh" R-NN-1 >/dev/null 2>&1 ); then
  pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL a safe config.env was not honoured"; fi

echo "security: pass=$pass fail=$fail"
[ "$fail" = 0 ]
