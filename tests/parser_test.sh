#!/bin/bash
H="$(cd "$(dirname "$0")/.." && pwd)/plugins/review-loop/bin/block_destructive_git.sh"
CWD="$(mktemp -d "${TMPDIR:-/tmp}/rl_parser.XXXXXX")"; trap 'rm -rf "$CWD"' EXIT
git -C "$CWD" init -q; echo v > "$CWD/notes.txt"; echo x > "$CWD/f"; git -C "$CWD" add .; git -C "$CWD" -c user.email=t@t -c user.name=t commit -qm init
pass=0; fail=0
t() {
  want=$1 agent=$2 cmd=$3
  json=$(jq -nc --arg c "$cmd" --arg a "$agent" --arg d "$CWD" \
    'if $a=="" then {cwd:$d,tool_input:{command:$c}} else {cwd:$d,agent_id:$a,tool_input:{command:$c}} end')
  printf '%s' "$json" | "$H" auto >/dev/null 2>&1
  r=$?
  got=allow; [ "$r" = 2 ] && got=block
  if [ "$got" = "$want" ]; then pass=$((pass+1)); else fail=$((fail+1)); printf 'FAIL want=%-5s got=%-5s %-3s %q\n' "$want" "$got" "${agent:+sub}" "$cmd"; fi
}
B() { t block "" "$1"; }
A() { t allow "" "$1"; }
SB() { t block sub1 "$1"; }
SA() { t allow sub1 "$1"; }

B 'git stash'; B 'git "stash"'; B "git 'checkout' -- f"; B 'g""it stash'; B 'git stas""h'; B 'git st\ash'
B $'git \\\nstash'; B $'echo hi\ngit stash'; B "git \$'stash'"; B "git \$'\\x73tash'"; B "\$'\\x67it' \$'\\x73tash'"
B 'x=stash; git $x'; B 'git ${CMD:-stash}'; B 'git {stash,}'; B 'git $(echo stash)'; B 'git `echo stash`'
B 'G=git; $G stash'; B '$(echo git) stash'; B '$(printf gi)t stash'; B '`echo git` stash'
B 'GIT stash'; B 'Git stash'; B '/usr/bin/git stash'; B '/usr/bin/GIT reset --hard'
B '{git,stash}'; B '/usr/bin/gi? stash'; B 'echo stash | xargs git'; B 'xargs -I{} git {} < list'
B 'echo `git stash`'; B 'echo "now `git stash` done"'; B 'echo "now $(git stash) done"'
B "echo \"it's\" ; git stash ; echo 'x'"; B 'bash <<< "git stash"'; B "bash -c 'git stash'"
B "python3 -c \"import os; os.system('git stash')\""; B "perl -e 'system(\"git stash\")'"
B 'git reset --har'; B 'git reset --ha'; B 'git reset -q --hard'; B 'git reset --merg HEAD'
B 'git checkout -fq HEAD'; B 'git checkout -qf main'; B 'git checkout --forc main'; B 'git checkout --pat'
B 'git restore --sta -qW f'; B 'git restore --staged --wor f'; B 'git restore f'
B 'git worktree remove --forc wt'; B 'git worktree remove -f wt'
B 'git switch --disc main'; B 'git switch -f main'; B 'git switch --force main'
B 'git checkout-index -f -a'; B 'git checkout-index -af'; B 'git read-tree -u --reset HEAD'
B 'git rm -f notes.txt'; B 'git clean -fd'; B 'git clean -fdx'
B 'f(){ git stash; }; f'; B '( git stash )'; B 'if true; then git stash; fi'
B 'env git stash'; B 'sudo -u me git stash'; B 'command git stash'; B 'nice -n 5 git stash'
B 'git -C . stash'; B 'git --git-dir=.git stash'; B 'git -c core.x=1 stash'; B 'git --no-pager stash'
B 'git -c alias.s=stash s'; B 'eval "git stash"'; B 'GIT=git; $GIT stash'

A 'git status'; A 'git diff HEAD'; A 'git log --oneline -5'; A 'git stash list'; A 'git stash show -p'
A 'git stash create'; A 'git checkout main'; A 'git checkout -b feature/x'; A 'git switch develop'
A 'git commit -m "fix: keep stash out of the tree"'; A "git commit -m 'restore'"; A 'git push origin develop'
A 'grep -n "git restore" notes.txt'; A "rg 'git stash' docs"; A 'git log --grep="reset"'
A 'echo "use git checkout -- carefully"'; A 'git restore --staged f'; A 'git restore -S f'
A 'git clean -n'; A 'git clean -fdn'; A 'git reset HEAD~1'; A 'git reset --soft HEAD~1'; A 'git help stash'
A 'git log --format="%h stash" -1'; A 'git rm --cached f'; A 'git add -A'; A "printf '%s\\n' a b"
A 'IFS=$'"'"'\n'"'"' read -r x <<< "$y"'; A "tr \$'\\t' ','"; A '"$HOME/flutter/bin/flutter" test'
A 'export PATH="$HOME/flutter/bin:$PATH" && flutter analyze'; A '"$CLAUDE_PROJECT_DIR"/tool/run_ios.sh'
A 'git commit -m "$(printf done)"'; A 'jq -r ".a" f.json | head -3'; A 'for f in *.md; do wc -l "$f"; done'
A 'ls ./build/*.log'; A 'git diff --stat | tail -1'; A 'echo $((1+2))'; A 'git rev-parse --abbrev-ref HEAD'
A 'git worktree add ../wt develop'; A 'git worktree list'; A 'git branch -D old'; A 'git tag v1'

SB 'git commit -m x'; SB 'git "commit" -m x'; SB $'git \\\ncommit -m x'; SB 'x=commit; git $x -m y'
SB 'git $(printf push) origin'; SB 'GIT commit -m x'; SB 'git config alias.c commit'; SB 'git bisect start'
SB 'git mv a b'; SB 'git submodule update --force'; SB 'git checkout-index -a'; SB 'git read-tree HEAD'
SB 'git branch -D x'; SB 'git tag -d v1'; SB 'git push --force'; SB 'git stash list && git stash'
SA 'git status'; SA 'git diff HEAD'; SA 'git log -3'; SA 'git stash list'; SA 'git stash create'
SA 'git branch -a'; SA 'git tag -l'; SA 'git apply --check p.diff'; SA 'git config --get user.name'
SA 'git config --list'; SA 'git show HEAD:f'; SA 'grep -rn "git commit" docs'

B '=git stash'; B 'noglob git stash'; B 'nocorrect git stash'; B 'function f { git stash; }; f'
B "printf 'stash\n' | xargs -I% sh -c 'git %'"; B "find . -name x -exec sh -c 'git checkout \"\$1\"' _ {} \\;"
B 'bash /dev/stdin <<< "git stash"'; B "bash <(echo 'git stash')"; B "source <(echo 'git stash')"
B "{ echo git stash; } | sh"; B "(echo git stash) | bash"; B "trap 'git stash' EXIT"
B 'script -q /dev/null git stash'; B "git -c core.pager='git stash' log"; B "GIT_PAGER='git stash' git log"
B "git rebase -x 'git stash' HEAD~1"; B 'git bisect run git stash'; B "git submodule foreach 'git stash'"
B 'git for-each-repo --config=x.y stash'; B "git difftool -x 'git stash'"; B 'git mv -f a notes.txt'
B "$(git --exec-path)/git-stash"; B "git config alias.zz stash && git zz"
A "cd sub && git zz"; B 'git -C ../other zz'
SB 'git fetch origin develop:develop'; SB 'git remote add x y'; SB 'git update-index --assume-unchanged f'
A 'git log --oneline -5 && git status'; A 'git diff --stat'
A "git commit -m \"\$(cat <<'EOF'
fix: it's done (finally)

Explains why git stash is blocked; don't run git checkout -- x.
EOF
)\""
A "git commit -F - <<'EOF'
mention git stash here
EOF"
A 'git remote -v'; A 'git fetch origin'; A 'git config user.name'; A 'echo hi # restore later'
A 'cd app && flutter test'; A "osascript -e 'display notification \"done\"'"
A "python3 - <<'PY'
print('hello')
PY"
B $'# don\'t\ngit stash'; B 'x=stash; git $=x'; B 'git ${~x:-stash}'; B "ls *(e:'git stash':)"
B '=(git stash)'; B 'x=$'"'"'git stash'"'"'; eval "$x"'; B "GIT_EDITOR='git stash' git commit"
B "env GIT_PAGER='git reset --hard' git log"; B "git -c core.editor='git reset --hard' commit"
B '$(( $(git stash) ))'; B "bash -c 'git sta'\"sh\""; B 'sh -c "git \$1" _ stash'; B 'xargs git <<< stash'
B 'a=gi; b=t; $a$b stash'; B $'git sta\\\nsh'; B "git sta\$'\\x73'h"; B 'git stash&'; B 'nohup git stash &'
B 'time (git stash)'; B 'coproc { git stash; }'; B 'git rm -rf dir'; B 'git clean -X -f'
B "printf '%s' stash | xargs git"; B 'command -v git && git stash'; B 'exec 3>&1; git stash'
B "zsh -c 'git restore .'"; B "osascript -e 'do shell script \"git stash\"'"
SB 'git-commit -m x'; SB 'git lfs pull'; SB 'git branch --set-upstream-to=origin/x'; SB 'git config --global user.name X'
SB 'git fetch . HEAD:refs/heads/x'; SB 'git tag -l -d x'; SB 'git notes add -m x'
SA 'git lfs ls-files'; SA 'git config --global user.name'; SA 'git fetch --prune origin'; SA 'git remote show origin'
A 'git status # ; git stash'; A 'echo $HOME'; A 'echo "cost: $5"'; A 'git log --format="%an <%ae>"'
A 'git switch --force-create x origin/x'; A 'git checkout --orphan gh-pages'; A 'git rm -r --cached build'
A "awk '{print \$1}' f"; A 'git diff HEAD~1 -- app/lib'; A 'git show --stat HEAD'; A "sed -n '1,5p' f"
A $'# restore the file later\ngit status'; A 'git checkout -'; A 'git stash show -p stash@{0}'
echo "parser: pass=$pass fail=$fail"
[ "$fail" = 0 ]
