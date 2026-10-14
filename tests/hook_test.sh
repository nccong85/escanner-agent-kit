#!/bin/bash
H="$(cd "$(dirname "$0")/.." && pwd)/plugins/review-loop/bin/block_destructive_git.sh"
pass=0; fail=0
t() {
  exp=$1; mode=$2; c=$3
  printf '%s' "{\"tool_input\":{\"command\":$(jq -Rn --arg c "$c" '$c')}}" | "$H" "$mode" 2>/dev/null
  r=$?
  if [ "$r" = "$exp" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL [$mode] got $r want $exp: $c"; fi
}
for m in subagent main; do
  for c in 'git diff HEAD' 'git status' 'git log --oneline -5' 'git stash create' 'git stash list' 'ls gitcheckout' \
           "grep -nE 'stash|git restore|git checkout --' f.md" 'echo "run git stash first"' "rg 'git reset --hard' doc"; do
    t 0 $m "$c"
  done
  for c in 'git checkout -- a' "bash -c 'git stash'" "sh -c \"git restore a\"" '/usr/bin/git checkout -- a' \
           'git -C "/p q" checkout -- a' "eval 'git reset --hard'" 'git ls-files | xargs git checkout --' \
           "zsh -c 'git clean -fd'" 'cd app && git restore x' 'git stash' 'git reset --hard'; do
    t 2 $m "$c"
  done
done
t 2 subagent 'git commit -m "fix: keep stash out"'
t 0 main 'git commit -m "fix: keep stash out"'
for c in 'git checkout --help' 'git -C /r reset --hard' 'flutter test && git commit -m x' 'git --no-pager push' \
         'echo x; git rm a' 'git apply x.patch' 'git switch develop'; do t 2 subagent "$c"; done
for c in 'git apply --check x.patch' 'grep -n git.stash f'; do t 0 subagent "$c"; done
for c in 'git commit -m x' 'git push origin develop' 'git checkout develop' 'git checkout -b feat/x' \
         'git switch -c feat/y' 'git restore --staged a' 'git clean -n' 'git reset HEAD a' 'git reset --soft HEAD~1' \
         'git apply x.patch' 'git show abc:b.txt > b.txt'; do t 0 main "$c"; done
for c in 'git checkout .' 'git checkout HEAD -- a.dart' 'git stash push -m x' 'git stash pop' 'git clean -fd' \
         'git reset --hard origin/develop'; do t 2 main "$c"; done
ta() {
  exp=$1; json=$2
  printf '%s' "$json" | "$H" auto >/dev/null 2>&1
  r=$?
  if [ "$r" = "$exp" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL [auto] got $r want $exp: $json"; fi
}
ta 0 '{"tool_input":{"command":"git commit -m x"}}'
ta 2 '{"agent_id":"a1","agent_type":"x","tool_input":{"command":"git commit -m x"}}'
ta 2 '{"tool_input":{"command":"git stash"}}'
ta 0 '{"agent_id":"a1","tool_input":{"command":"git diff HEAD"}}'
printf '{"tool_input":{"command":"git stash"}}' | env PATH=/bin "$H" main >/dev/null 2>&1
[ $? = 2 ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL no-parser git should block"; }
printf '{"tool_input":{"command":"ls"}}' | env PATH=/bin "$H" main >/dev/null 2>&1
[ $? = 0 ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL no-parser ls should pass"; }
echo "hook: pass=$pass fail=$fail"
[ "$fail" = 0 ]
