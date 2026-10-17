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
    *[Gg][Ii][Tt]*) echo "Blocked: block_destructive_git.sh needs jq or python3 to inspect git commands." >&2; exit 2 ;;
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

read -r -d '' PROG <<'AWK'
function setlist(arr, s,   n, a, i) { n = split(s, a, " "); for (i = 1; i <= n; i++) arr[a[i]] = 1 }
function block(r) { print "BLOCK\t" r; exit 0 }
function shq(s) { gsub(/'/, "'\\''", s); return "'" s "'" }
function enqueue(s) { nq++; Q[nq] = s; if (nq > 400) block("the command is too complex to check") }
function newcmd() { ncmd++; cw = ncmd; NW[cw] = 0; HS[cw] = ""; HD[cw] = ""; PIPEIN[cw] = pipe_next; PREVC[cw] = pipe_prev; pipe_next = 0 }
function markdyn() { word = word DYN; wdyn = 1; inword = 1 }
function endword() {
  if (!inword) return
  if (redir == "here") HS[cw] = HS[cw] "\n" word
  else if (redir == "heredoc") { HDN++; HDDELIM[HDN] = word; HDCMD[HDN] = cw; HDSTRIP[HDN] = hdstrip; HDEXP[HDN] = !wquoted }
  else if (redir == "" && !wquoted && !wdyn && (word == "{" || word == "}")) {
    if (NW[cw] > 0) { word = ""; inword = 0; newcmd(); return }
  }
  else if (redir == "") {
    if (!(NW[cw] == 0 && !wquoted && !wdyn && (word in RESERVED))) { NW[cw]++; W[cw, NW[cw]] = word }
  }
  redir = ""; word = ""; inword = 0; wdyn = 0; wquoted = 0
}
function endcmd(sep) {
  endword()
  if (sep == "pipe") { pipe_next = 1; pipe_prev = cw } else { pipe_prev = 0 }
  newcmd()
}
function matchclose(s, j, op, cl,   n, c, d) {
  n = length(s); d = 1
  while (j <= n) {
    c = substr(s, j, 1)
    if (c == "\\") { j += 2; continue }
    if (c == "'") { j++; while (j <= n && substr(s, j, 1) != "'") j++; j++; continue }
    if (c == "\"") { j++; while (j <= n && substr(s, j, 1) != "\"") { if (substr(s, j, 1) == "\\") j++; j++ }; j++; continue }
    if (c == op) d++
    else if (c == cl) { d--; if (d == 0) return j }
    j++
  }
  return n + 1
}
function subst_scan(s,   i, n, c, j) {
  n = length(s); i = 1
  while (i <= n) {
    c = substr(s, i, 1)
    if (c == "\\") { i += 2; continue }
    if (c == "$" && substr(s, i + 1, 1) == "(") { j = matchclose(s, i + 2, "(", ")"); enqueue(substr(s, i + 2, j - i - 2)); i = j + 1; continue }
    if (c == "`") { j = index(substr(s, i + 1), "`"); if (j == 0) { enqueue(substr(s, i + 1)); return } enqueue(substr(s, i + 1, j - 1)); i += j + 1; continue }
    i++
  }
}
function backtick(s, i,   j, inner) {
  j = index(substr(s, i), "`")
  if (j == 0) { inner = substr(s, i); i = length(s) + 1 } else { inner = substr(s, i, j - 1); i += j }
  gsub(/\\`/, "`", inner); enqueue(inner); markdyn(); return i
}
function dollar(s, i, indq,   nx, j) {
  nx = substr(s, i + 1, 1)
  if (nx == "(") { j = matchclose(s, i + 2, "(", ")"); enqueue(substr(s, i + 2, j - i - 2)); markdyn(); return j + 1 }
  if (nx == "{") { j = matchclose(s, i + 2, "{", "}"); subst_scan(substr(s, i + 2, j - i - 2)); markdyn(); return j + 1 }
  if (!indq && nx == "'") return ansic(s, i + 2)
  if (!indq && nx == "\"") return dquote(s, i + 2)
  if (nx ~ /[A-Za-z_]/) { j = i + 1; while (substr(s, j, 1) ~ /[A-Za-z0-9_]/) j++; markdyn(); return j }
  if (nx != "" && index("0123456789@*#?$!-", nx)) { markdyn(); return i + 2 }
  return 0
}
function dquote(s, i,   n, c, nx, j) {
  n = length(s); inword = 1; wquoted = 1
  while (i <= n) {
    c = substr(s, i, 1)
    if (c == "\"") return i + 1
    if (c == "\\") { nx = substr(s, i + 1, 1); if (nx == "\n") { i += 2; continue } if (index("$`\"\\", nx) && nx != "") { word = word nx; i += 2; continue } word = word c; i++; continue }
    if (c == "`") { i = backtick(s, i + 1); continue }
    if (c == "$") { j = dollar(s, i, 1); if (j > 0) { i = j; continue } word = word c; markdyn(); i++; continue }
    word = word c; i++
  }
  return i
}
function chr(v) { v = v % 256; if (v == 0) return ""; return sprintf("%c", v) }
function hexval(s, i, max,   v, k, h) {
  v = 0; k = 0
  while (k < max && (h = index("0123456789abcdef", tolower(substr(s, i + k, 1)))) > 0) { v = v * 16 + h - 1; k++ }
  HEXLEN = k; return v
}
function ansic(s, i,   n, c, nx, v, k) {
  n = length(s); inword = 1; wquoted = 1
  while (i <= n) {
    c = substr(s, i, 1)
    if (c == "'") return i + 1
    if (c != "\\") { word = word c; i++; continue }
    nx = substr(s, i + 1, 1); i += 2
    if (nx == "n") word = word "\n"
    else if (nx == "t") word = word "\t"
    else if (nx == "r") word = word "\r"
    else if (nx == "a" || nx == "b" || nx == "e" || nx == "E" || nx == "f" || nx == "v") word = word " "
    else if (nx == "x") { v = hexval(s, i, 2); i += HEXLEN; word = word chr(v) }
    else if (nx == "u") { v = hexval(s, i, 4); i += HEXLEN; word = word (v < 128 ? chr(v) : "?") }
    else if (nx == "U") { v = hexval(s, i, 8); i += HEXLEN; word = word (v < 128 ? chr(v) : "?") }
    else if (nx ~ /[0-7]/) { v = nx + 0; k = 1; while (k < 3 && substr(s, i, 1) ~ /[0-7]/) { v = v * 8 + substr(s, i, 1); i++; k++ } word = word chr(v) }
    else if (nx == "c") { i++; word = word "?" }
    else word = word nx
  }
  return i
}
function heredocs(s, i,   k, n, nl, line, d, body) {
  n = length(s)
  for (k = HDH; k <= HDN; k++) {
    body = ""
    while (i <= n) {
      nl = index(substr(s, i), "\n")
      if (nl == 0) { line = substr(s, i); i = n + 1 } else { line = substr(s, i, nl - 1); i += nl }
      d = line; if (HDSTRIP[k]) sub(/^\t+/, "", d)
      if (d == HDDELIM[k]) break
      body = body line "\n"
    }
    HD[HDCMD[k]] = HD[HDCMD[k]] body
    if (HDEXP[k]) subst_scan(body)
  }
  HDH = HDN + 1
  return i
}
function brace_end(s, i,   j, n, c) {
  n = length(s)
  for (j = i + 1; j <= n; j++) { c = substr(s, j, 1); if (c == "}") return j; if (index(" \t\n;&|()<>'\"", c)) return 0 }
  return 0
}
function lex(s,   n, i, c, nx, j, seg) {
  n = length(s); i = 1
  word = ""; inword = 0; wdyn = 0; wquoted = 0; redir = ""; pipe_next = 0; pipe_prev = 0
  newcmd()
  while (i <= n) {
    c = substr(s, i, 1)
    if (c == "\\") { nx = substr(s, i + 1, 1); if (nx == "\n") { i += 2; continue } if (nx != "") { word = word nx; inword = 1 } i += 2; continue }
    if (c == "'") { j = index(substr(s, i + 1), "'"); inword = 1; wquoted = 1; if (j == 0) { word = word substr(s, i + 1); i = n + 1; continue } word = word substr(s, i + 1, j - 1); i += j + 1; continue }
    if (c == "\"") { i = dquote(s, i + 1); continue }
    if (c == "$") { j = dollar(s, i, 0); if (j > 0) { i = j; continue } word = word c; markdyn(); i++; continue }
    if (c == "`") { i = backtick(s, i + 1); continue }
    if (c == " " || c == "\t" || c == "\r") { endword(); i++; continue }
    if (c == "\n") { endcmd("nl"); i = heredocs(s, i + 1); continue }
    if (c == "#" && !inword) { while (i <= n && substr(s, i, 1) != "\n") i++; continue }
    if ((c == "<" || c == ">") && substr(s, i + 1, 1) == "(") { j = matchclose(s, i + 2, "(", ")"); enqueue(substr(s, i + 2, j - i - 2)); markdyn(); i = j + 1; continue }
    if (c == "<" || c == ">") {
      if (inword && word ~ /^[0-9]+$/ && !wquoted && !wdyn) { word = ""; inword = 0 } else endword()
      if (substr(s, i, 3) == "<<<") { redir = "here"; i += 3; continue }
      if (substr(s, i, 2) == "<<") { i += 2; hdstrip = 0; if (substr(s, i, 1) == "-") { hdstrip = 1; i++ } redir = "heredoc"; continue }
      i++; while (i <= n && index("<>&|", substr(s, i, 1))) i++
      redir = "file"; continue
    }
    if (c == "&" && substr(s, i + 1, 1) == ">") { endword(); i++; continue }
    if (c == "|") { if (substr(s, i + 1, 1) == "|") { endcmd("or"); i += 2 } else { endcmd("pipe"); i += (substr(s, i + 1, 1) == "&") ? 2 : 1 } continue }
    if (c == ";" || c == "&" || c == "(" || c == ")") { endcmd("sep"); i++; continue }
    if (c == "[" && !inword && (substr(s, i + 1, 1) ~ /[ \t]/ || (substr(s, i + 1, 1) == "[" && substr(s, i + 2, 1) ~ /[ \t]/))) {
      if (substr(s, i + 1, 1) == "[") { word = "[["; i += 2 } else { word = "["; i++ }
      inword = 1; continue
    }
    if (c == "*" || c == "?" || c == "[") { word = word c; markdyn(); i++; continue }
    if (c == "{") { j = brace_end(s, i); if (j > 0) { seg = substr(s, i, j - i + 1); if (seg ~ /,|\.\./) { word = word seg; markdyn(); i = j + 1; continue } } }
    word = word c; inword = 1; i++
  }
  endcmd("end")
}
function isdyn(c, k) { return index(W[c, k], DYN) > 0 }
function toks(s, arr) { s = tolower(s); gsub(/[^a-z0-9._-]+/, " ", s); return split(s, arr, " ") }
function heur(s, win,   n, a, i, j) {
  n = toks(s, a)
  for (i = 1; i <= n; i++) if (a[i] == "git" || a[i] == "git.exe")
    for (j = i + 1; j <= n && (win == 0 || j <= i + win); j++) if (a[j] in DANGER) return 1
  return 0
}
function hasgit(s,   n, a, i) { n = toks(s, a); for (i = 1; i <= n; i++) if (a[i] == "git" || a[i] == "git.exe") return 1; return 0 }
function is_assign(t) { return t ~ /^[A-Za-z_][A-Za-z0-9_]*\+?=/ }
function check_assign(t,   name, val) {
  name = t; sub(/\+?=.*/, "", name); name = toupper(name)
  val = t; sub(/^[^=]*=/, "", val)
  if (heur(val, 0)) block("a variable that holds a destructive git command cannot be checked")
  if (name ~ /^GIT_CONFIG/ || name == "HOME" || name == "XDG_CONFIG_HOME") CFGENV = 1
  if (name ~ /^GIT_CONFIG/ && tolower(t) ~ /(alias|include)/) block("a git alias set through the environment cannot be checked")
}
function takes_value(w, t) { return ((w SUBSEP t) in TV) }
function skip_wrapper(c, w, k, e,   t, first) {
  first = 1
  while (k <= e) {
    t = W[c, k]
    if (w == "env") {
      if (is_assign(t)) { check_assign(t); k++; continue }
      if (t == "-S" || t == "--split-string") { enqueue(W[c, k + 1]); return e + 1 }
      if (t ~ /^-S./) { enqueue(substr(t, 3)); return e + 1 }
      if (t ~ /^--split-string=/) { enqueue(substr(t, 16)); return e + 1 }
      if (t == "-u" || t == "--unset" || t == "-C" || t == "--chdir") { k += 2; continue }
    }
    if (w == "command" && t ~ /^-[a-zA-Z]*[vV]/) return e + 1
    if (t == "--") return k + 1
    if (t ~ /^-./) { k += takes_value(w, t) ? 2 : 1; continue }
    if (w == "timeout" && first && t ~ /^[0-9.]+[smhd]?$/) { k++; first = 0; continue }
    break
  }
  return k
}
function longbody(t,   b, p) { b = substr(t, 3); p = index(b, "="); if (p) b = substr(b, 1, p - 1); return b }
function longis(t, name, minlen,   b) { if (substr(t, 1, 2) != "--" || length(t) < 3) return 0; b = longbody(t); return length(b) >= minlen && substr(name, 1, length(b)) == b }
function shorthas(t, letters, valtak,   i, ch) {
  if (t !~ /^-[^-]/) return 0
  for (i = 2; i <= length(t); i++) { ch = substr(t, i, 1); if (index(letters, ch)) return 1; if (index(valtak, ch)) return 0 }
  return 0
}
function anylong(c, k, e, name, minlen,   j) { for (j = k; j <= e; j++) { if (W[c, j] == "--") return 0; if (longis(W[c, j], name, minlen)) return 1 } return 0 }
function anyshort(c, k, e, letters, valtak,   j) { for (j = k; j <= e; j++) { if (W[c, j] == "--") return 0; if (shorthas(W[c, j], letters, valtak)) return 1 } return 0 }
function anyexact(c, k, e, set,   j, a) { setlist(a, set); for (j = k; j <= e; j++) if (W[c, j] in a) return 1; return 0 }
function path_not_commit(p,   f) {
  f = (substr(p, 1, 1) == "/") ? p : cwd "/" p
  if (system("test -e " shq(f)) != 0) return 0
  return system("git -C " shq(cwd) " rev-parse --verify --quiet " shq(p "^{commit}") " >/dev/null 2>&1") != 0
}
function checkout_paths(c, k, e,   j, t, i, ch, pos, creating, last, lastdyn) {
  pos = 0; creating = 0; last = ""; lastdyn = 0
  for (j = k; j <= e; j++) {
    t = W[c, j]
    if (t == "--" || t == ".") return 1
    if (isdyn(c, j) && t !~ /^-/) { pos++; lastdyn = 1; continue }
    if (substr(t, 1, 2) == "--") {
      if (longis(t, "force", 1) || longis(t, "patch", 2) || longis(t, "pathspec-from-file", 5) || longis(t, "ours", 2) || longis(t, "theirs", 2) || longis(t, "merge", 1)) return 1
      if (longis(t, "orphan", 2)) { creating = 1; if (!index(t, "=")) j++ }
      continue
    }
    if (t ~ /^-./) {
      for (i = 2; i <= length(t); i++) { ch = substr(t, i, 1); if (index("fpm", ch)) return 1; if (index("bB", ch)) { creating = 1; if (i == length(t)) j++; break } }
      continue
    }
    pos++; last = t; lastdyn = 0
  }
  if (creating) return 0
  if (pos >= 2) return 1
  if (pos == 1 && lastdyn) return 1
  if (pos == 1 && path_not_commit(last)) return 1
  return 0
}
function main_rules(v, c, k, e, stdin) {
  if (v == "checkout") { if (stdin || checkout_paths(c, k, e)) block("git checkout of paths (or with --force) discards uncommitted edits"); return }
  if (v == "switch") { if (anylong(c, k, e, "force", 1) || anylong(c, k, e, "discard-changes", 2) || anyshort(c, k, e, "f", "cC")) block("git switch --force/--discard-changes discards uncommitted edits"); return }
  if (v == "restore") { if (stdin || !(anylong(c, k, e, "staged", 2) || anyshort(c, k, e, "S", "s")) || anylong(c, k, e, "worktree", 1) || anyshort(c, k, e, "W", "s")) block("git restore discards uncommitted edits (only git restore --staged is allowed)"); return }
  if (v == "stash") { if (k > e || isdyn(c, k) || !(W[c, k] in STASH_OK)) block("git stash moves other sessions' uncommitted work out of the shared tree"); return }
  if (v == "clean") { if (!(anylong(c, k, e, "dry-run", 1) || anyshort(c, k, e, "n", "e"))) block("git clean deletes untracked files (git clean -n is allowed)"); return }
  if (v == "reset") { if (anylong(c, k, e, "hard", 1) || anylong(c, k, e, "merge", 2) || anylong(c, k, e, "keep", 1)) block("git reset --hard discards uncommitted edits"); return }
  if (v == "worktree") { if (k <= e && W[c, k] == "remove" && (anylong(c, k + 1, e, "force", 1) || anyshort(c, k + 1, e, "f", ""))) block("git worktree remove --force deletes a worktree with uncommitted edits"); return }
  if (v == "checkout-index") { if (anylong(c, k, e, "force", 1) || anyshort(c, k, e, "f", "")) block("git checkout-index --force overwrites uncommitted edits"); return }
  if (v == "read-tree") { if (anyshort(c, k, e, "u", "")) block("git read-tree -u overwrites the working tree"); return }
  if (v == "rm") { if ((stdin || anylong(c, k, e, "force", 1) || anyshort(c, k, e, "f", "")) && !anylong(c, k, e, "cached", 1)) block("git rm --force deletes uncommitted edits"); return }
  if (v == "mv") { if (anylong(c, k, e, "force", 1) || anyshort(c, k, e, "f", "")) block("git mv --force overwrites a file with uncommitted edits"); return }
  if (v == "submodule") { if (k <= e && (W[c, k] == "deinit" || W[c, k] == "update") && (anylong(c, k + 1, e, "force", 1) || anyshort(c, k + 1, e, "f", ""))) block("git submodule --force discards uncommitted edits in a submodule"); return }
}
function branch_listing(c, k, e,   j, t, i, list) {
  list = anylong(c, k, e, "list", 1) || anyshort(c, k, e, "l", "")
  for (j = k; j <= e; j++) {
    t = W[c, j]
    if (t == "--") { if (j < e && !list) return 0; continue }
    if (substr(t, 1, 2) == "--") {
      if (!prefix_any(longbody(t), BRANCH_LONG)) return 0
      if (!index(t, "=") && prefix_any(longbody(t), BRANCH_VAL) && j < e && W[c, j + 1] !~ /^-/) j++
      continue
    }
    if (t ~ /^-./) { for (i = 2; i <= length(t); i++) if (!index("alrvq", substr(t, i, 1))) return 0; continue }
    if (!list) return 0
  }
  return 1
}
function prefix_any(b, set,   n, a, i) { if (b == "") return 0; n = split(set, a, " "); for (i = 1; i <= n; i++) if (substr(a[i], 1, length(b)) == b) return 1; return 0 }
function tag_listing(c, k, e,   j, t, i) {
  if (k > e) return 1
  if (!(anylong(c, k, e, "list", 1) || anyshort(c, k, e, "l", ""))) return 0
  for (j = k; j <= e; j++) {
    t = W[c, j]
    if (substr(t, 1, 2) == "--" && length(t) > 2) { if (!prefix_any(longbody(t), TAG_LONG)) return 0; continue }
    if (t ~ /^-./) { for (i = 2; i <= length(t); i++) if (!index("lni0123456789", substr(t, i, 1))) return 0 }
  }
  return 1
}
function config_read(c, k, e,   j, t, pos, read) {
  pos = 0; read = 0
  for (j = k; j <= e; j++) {
    t = W[c, j]
    if (t in CONFIG_READ) { read = 1; continue }
    if (t in CONFIG_WRITE) return 0
    if (t in CONFIG_VAL) { j++; continue }
    if (t ~ /^-/) continue
    pos++
    if (pos == 1 && (t == "get" || t == "list")) read = 1
    if (pos == 1 && (t == "set" || t == "unset" || t == "rename-section" || t == "remove-section" || t == "edit")) return 0
  }
  if (read) return 1
  return pos == 1
}
function symref_read(c, k, e,   j, pos) {
  if (anylong(c, k, e, "delete", 1) || anyshort(c, k, e, "dm", "")) return 0
  pos = 0; for (j = k; j <= e; j++) if (W[c, j] !~ /^-/) pos++
  return pos <= 1
}
function fetch_safe(c, k, e,   j, pos) {
  pos = 0
  for (j = k; j <= e; j++) {
    if (W[c, j] == "--update-head-ok" || W[c, j] == "-u") return 0
    if (W[c, j] ~ /^-/) continue
    pos++
    if (pos >= 2 && index(W[c, j], ":")) return 0
  }
  return 1
}
function update_index_refresh(c, k, e,   j) {
  if (k > e) return 0
  for (j = k; j <= e; j++) if (W[c, j] != "--refresh" && W[c, j] != "--really-refresh" && W[c, j] != "-q") return 0
  return 1
}
function sub_rules(v, c, k, e, stdin) {
  if (!(v in SUB_DANGER)) return
  if (v == "stash" && k <= e && !isdyn(c, k) && (W[c, k] in STASH_OK)) return
  if (v == "branch" && branch_listing(c, k, e)) return
  if (v == "tag" && tag_listing(c, k, e)) return
  if (v == "reflog" && (k > e || W[c, k] == "show" || W[c, k] == "exists" || W[c, k] ~ /^-/)) return
  if (v == "worktree" && k <= e && W[c, k] == "list") return
  if (v == "config" && config_read(c, k, e)) return
  if (v == "submodule" && (k > e || W[c, k] == "status" || W[c, k] == "summary")) return
  if (v == "notes" && (k > e || W[c, k] == "list" || W[c, k] == "show")) return
  if (v == "replace" && (k > e || anylong(c, k, e, "list", 1) || anyshort(c, k, e, "l", ""))) return
  if (v == "symbolic-ref" && symref_read(c, k, e)) return
  if (v == "fetch" && fetch_safe(c, k, e)) return
  if (v == "remote" && (k > e || W[c, k] ~ /^-/ || W[c, k] == "show" || W[c, k] == "get-url")) return
  if (v == "update-index" && update_index_refresh(c, k, e)) return
  if (v == "lfs" && k <= e && (W[c, k] == "ls-files" || W[c, k] == "status" || W[c, k] == "env" || W[c, k] == "version" || W[c, k] == "logs")) return
  if (v == "apply") { if (anylong(c, k, e, "check", 2) && !anylong(c, k, e, "apply", 2)) return; block("subagents must not run git apply (use git apply --check to test a patch)") }
  block("subagents must not run git commands that change the working tree, index, refs or history (checkout/restore/stash/clean/reset/commit/push/branch/tag/...)")
}
function git_alias(v,   cmd, val) {
  cmd = "git -C " shq(CDDIR != "" ? CDDIR : cwd) " config --get " shq("alias." v) " 2>/dev/null"
  val = ""; cmd | getline val; close(cmd); return val
}
function cfg_check(v) {
  v = tolower(v)
  if (v ~ /^(alias|include|includeif)\./) block("a git alias or include set on the command line cannot be checked")
  if (heur(v, 0)) block("a git config value that runs a destructive git command cannot be checked")
}
function analyze_git(c, k, e, stdin,   t, other, v, a, rest, j) {
  other = 0
  while (k <= e) {
    t = W[c, k]
    if (t == "-c" || t == "--config-env") { cfg_check(W[c, k + 1]); k += 2; continue }
    if (t ~ /^-c./) { cfg_check(substr(t, 3)); k++; continue }
    if (t ~ /^--config-env=/) { cfg_check(substr(t, 14)); k++; continue }
    if (t == "-C" || t == "--git-dir" || t == "--work-tree" || t == "--namespace" || t == "--super-prefix") { other = 1; k += 2; continue }
    if (t ~ /^--(git-dir|work-tree|namespace|super-prefix)=/ || t ~ /^-C./) { other = 1; k++; continue }
    if (t ~ /^-/) { k++; continue }
    break
  }
  if (k > e) { if (stdin) block("git with its subcommand supplied at runtime cannot be checked"); return }
  if (isdyn(c, k)) block("a git subcommand built from a variable, an expansion or a substitution cannot be checked")
  v = W[c, k]
  if (!(v in BUILTIN) && !(v in SUB_DANGER)) {
    if (stdin) block("git with its subcommand supplied at runtime cannot be checked")
    if (v !~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/) return
    if (other || CFGENV) block("a git alias read from another repository or config cannot be checked")
    if (index(tolower(raw), "alias")) block("a git alias defined in the same command cannot be checked")
    a = git_alias(v)
    if (a == "") return
    rest = ""; for (j = k + 1; j <= e; j++) rest = rest " " shq(W[c, j])
    if (substr(a, 1, 1) == "!") enqueue(substr(a, 2) rest); else enqueue("git " a rest)
    return
  }
  verb_rules(v, c, k + 1, e, stdin)
}
function join_from(c, k, e,   j, s) { s = ""; for (j = k; j <= e; j++) s = s " " shq(W[c, j]); return s }
function runners(v, c, k, e,   j, t) {
  if (v == "bisect" && k <= e && W[c, k] == "run") { enqueue(join_from(c, k + 1, e)); return }
  if (v == "submodule" && k <= e && W[c, k] == "foreach") { j = k + 1; while (j <= e && W[c, j] ~ /^-/) j++; for (; j <= e; j++) enqueue(W[c, j]); return }
  if (v == "for-each-repo") { j = k; while (j <= e && W[c, j] ~ /^-/) { if (W[c, j] == "--config") j++; j++ } enqueue("git" join_from(c, j, e)); return }
  for (j = k; j <= e; j++) {
    t = W[c, j]
    if ((v == "rebase" && (t == "-x" || t == "--exec")) || (v == "difftool" && (t == "-x" || t == "--extcmd")) || (v == "grep" && (t == "-O" || t == "--open-files-in-pager")) || (v == "filter-branch" && t ~ /-filter$/)) { enqueue(W[c, j + 1]); j++; continue }
    if (v == "rebase" && t ~ /^--exec=/) enqueue(substr(t, 8))
    if (v == "difftool" && t ~ /^--extcmd=/) enqueue(substr(t, 10))
    if (v == "grep" && t ~ /^(-O.|--open-files-in-pager=)/) { sub(/^(-O|--open-files-in-pager=)/, "", t); enqueue(t) }
    if (v == "rebase" && t ~ /^-x./) enqueue(substr(t, 3))
  }
}
function alias_define(c, k, e,   j, t, val) {
  for (j = k; j <= e; j++) {
    t = W[c, j]
    if (tolower(t) ~ /^alias\./ && j < e) {
      val = W[c, j + 1]
      if (substr(val, 1, 1) == "!" || heur("git " val, 0) || isdyn(c, j + 1)) block("a git alias that runs a destructive git command cannot be checked")
    }
  }
}
function verb_rules(v, c, k, e, stdin) {
  runners(v, c, k, e)
  if (v == "config") alias_define(c, k, e)
  if (mode == "subagent") sub_rules(v, c, k, e, stdin); else main_rules(v, c, k, e, stdin)
}
function dyn_head(c, s, e,   j, a) {
  DYNEXEC = 1
  if (hasgit(W[c, s])) block("a git command whose name is built at runtime cannot be checked")
  for (j = s + 1; j <= e; j++) {
    if (W[c, j] in DANGER) block("a command whose name is built at runtime, run with a destructive git verb, cannot be checked")
    if (W[c, j] ~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/ && !(W[c, j] in BUILTIN) && j <= s + 3) { a = git_alias(W[c, j]); if (a != "" && heur("git " a, 0)) block("a command whose name is built at runtime, run with a destructive git alias, cannot be checked") }
  }
}
function pipe_text(c,   p, j, txt) {
  txt = ""
  if (PIPEIN[c] && PREVC[c] > 0) {
    p = PREVC[c]
    for (j = 1; j <= NW[p]; j++) { txt = txt "\n" W[p, j]; if (isdyn(p, j)) DYNEXEC = 1 }
    txt = txt "\n" HS[p] "\n" HD[p]
    if (NW[p] > 0 && W[p, 1] !~ /^(echo|printf)$/) DYNEXEC = 1
  }
  return txt
}
function shell_cmd(c, k, e, fromargs,   t, hasc, stdin) {
  hasc = 0; stdin = 0
  while (k <= e) {
    t = W[c, k]
    if (t == "--") { k++; break }
    if (t ~ /^[-+][oO]$/ || t == "--rcfile" || t == "--init-file") { k += 2; continue }
    if (t ~ /^-[A-Za-z]*c[A-Za-z]*$/) { hasc = 1; k++; continue }
    if (t ~ /^-[A-Za-z]*s[A-Za-z]*$/) { stdin = 1; k++; continue }
    if (t ~ /^[-+]./) { k++; continue }
    break
  }
  if (hasc) {
    if (k <= e) { enqueue(W[c, k]); if (isdyn(c, k)) DYNEXEC = 1; if (fromargs && hasgit(W[c, k])) block("git run by xargs/find through a shell cannot be checked") }
    return
  }
  if (k <= e && !stdin && W[c, k] != "-" && W[c, k] != "/dev/stdin" && W[c, k] != "/dev/fd/0") { if (isdyn(c, k)) DYNEXEC = 1; return }
  if (HS[c] != "" || HD[c] != "") enqueue(HS[c] "\n" HD[c])
  if (PIPEIN[c] && heur(raw, 0)) block("a shell reading a destructive git command from a pipe cannot be checked")
}
function interp_cmd(c, lb, k, e,   t, code, prog, script) {
  code = ""; prog = 0; script = 0
  while (k <= e) {
    t = W[c, k]
    if (lb ~ /awk$/) {
      if (t == "-f") { script = 1; k += 2; continue }
      if (t == "-v" || t == "-F") { k += 2; continue }
      if (t ~ /^-./) { k++; continue }
      if (!script && !prog) { code = code "\n" t; prog = 1 }
      k++; continue
    }
    if (t ~ /^-[A-Za-z]*[ceEr]$/ || t == "--eval" || t == "--command" || t == "-p" || t == "--print") { code = code "\n" W[c, k + 1]; if (isdyn(c, k + 1)) DYNEXEC = 1; prog = 1; k += 2; continue }
    if (t ~ /^-[ceE]./) { code = code "\n" substr(t, 3); prog = 1; k++; continue }
    if (t ~ /^-./) { k++; continue }
    if (t != "-" && !prog) script = 1
    break
  }
  if (!prog && !script) { code = code "\n" HS[c] "\n" HD[c]; if (PIPEIN[c] && heur(raw, 0)) block("an interpreter reading a destructive git command from a pipe cannot be checked") }
  if (heur(code, 4)) block("an interpreter running a destructive git command cannot be checked")
}
function find_cmd(c, k, e,   j, m) {
  for (j = k; j <= e; j++) {
    if (W[c, j] ~ /^-(exec|execdir|ok|okdir)$/) {
      for (m = j + 1; m <= e && W[c, m] != ";" && W[c, m] != "+" && W[c, m] !~ /\{\}\+$/; m++) ;
      analyze_words(c, j + 1, m - 1, 1)
      j = m
    }
  }
}
function analyze_words(c, s, e, stdin,   t, b, lb, k, txt, j) {
  while (s <= e && is_assign(W[c, s])) { check_assign(W[c, s]); s++ }
  if (s > e) return
  t = W[c, s]; b = t; sub(/.*\//, "", b); sub(/^=/, "", b); lb = tolower(b)
  if (index(b, DYN)) { dyn_head(c, s, e); return }
  if (t ~ /[ \t]/ && heur(t, 0)) block("a command word that holds a destructive git command cannot be checked")
  if (lb ~ /^git-[a-z]/) { verb_rules(substr(lb, 5), c, s + 1, e, stdin); return }
  if (lb in WRAP) { k = skip_wrapper(c, lb, s + 1, e); analyze_words(c, k, e, stdin || lb == "xargs" || lb == "parallel"); return }
  if (lb == "git" || lb == "git.exe") { analyze_git(c, s + 1, e, stdin); return }
  if (lb in SHELLS) { shell_cmd(c, s + 1, e, stdin); return }
  if (lb == "source" || lb == ".") { if (s < e && isdyn(c, s + 1)) DYNEXEC = 1; return }
  if (lb == "trap") { if (s < e && W[c, s + 1] !~ /^-/) enqueue(W[c, s + 1]); return }
  if (lb == "script") { k = s + 1; while (k <= e && W[c, k] ~ /^-/) { if (W[c, k] == "-c" || W[c, k] == "--command") { enqueue(W[c, k + 1]); return } k += (W[c, k] == "-t" || W[c, k] == "-T" || W[c, k] == "-F") ? 2 : 1 } analyze_words(c, k + 1, e, stdin); return }
  if ((lb == "cd" || lb == "pushd") && s < e && !isdyn(c, s + 1)) { CDDIR = (substr(W[c, s + 1], 1, 1) == "/") ? W[c, s + 1] : cwd "/" W[c, s + 1]; return }
  if (lb in INTERP) { interp_cmd(c, lb, s + 1, e); return }
  if (lb == "eval" || lb == "watch") { txt = ""; for (j = s + 1; j <= e; j++) { txt = txt " " W[c, j]; if (isdyn(c, j)) DYNEXEC = 1 } if (stdin && hasgit(txt)) block("git run by xargs/find through eval cannot be checked"); enqueue(txt); return }
  if (lb == "find") { find_cmd(c, s + 1, e); return }
  if (lb == "alias") { for (j = s + 1; j <= e; j++) if (hasgit(W[c, j])) block("a shell alias that runs git cannot be checked"); return }
}
BEGIN {
  mode = ENVIRON["HOOK_MODE"]; cwd = ENVIRON["HOOK_CWD"]; raw = ENVIRON["HOOK_CMD"]
  DYN = "\001"
  setlist(WRAP, "command builtin exec env nice nohup time sudo doas xargs parallel stdbuf timeout caffeinate xcrun arch chronic unbuffer noglob nocorrect")
  setlist(SHELLS, "sh bash zsh dash ksh mksh fish busybox")
  setlist(INTERP, "python python2 python3 perl ruby node nodejs deno bun php lua osascript rscript tclsh expect awk gawk nawk mawk")
  setlist(RESERVED, "if then else elif fi do done while until case esac ! { } function select coproc")
  setlist(STASH_OK, "list show create")
  setlist(MAIN_DANGER, "stash checkout switch restore clean reset worktree checkout-index read-tree rm submodule")
  setlist(SUB_DANGER, "stash checkout switch restore clean reset worktree checkout-index read-tree rm submodule commit push pull rebase merge cherry-pick revert mv am apply branch tag update-ref gc reflog filter-branch filter-repo config bisect notes replace symbolic-ref prune sparse-checkout fetch remote update-index lfs")
  if (mode == "subagent") { for (x in SUB_DANGER) DANGER[x] = 1 } else { for (x in MAIN_DANGER) DANGER[x] = 1 }
  setlist(BUILTIN, "add am annotate apply archive bisect blame branch bundle cat-file check-attr check-ignore check-mailmap check-ref-format checkout checkout-index cherry cherry-pick citool clean clone column commit commit-graph commit-tree config count-objects credential describe diff diff-files diff-index diff-tree difftool fast-export fast-import fetch fetch-pack filter-branch fmt-merge-msg for-each-ref for-each-repo format-patch fsck gc get-tar-commit-id grep gui hash-object help hook index-pack init instaweb interpret-trailers log ls-files ls-remote ls-tree mailinfo mailsplit maintenance merge merge-base merge-file merge-index merge-tree mergetool mktag mktree multi-pack-index mv name-rev notes pack-objects pack-redundant pack-refs patch-id prune prune-packed pull push range-diff read-tree rebase reflog remote repack replace rerere reset restore rev-list rev-parse revert rm send-email shortlog show show-branch show-index show-ref sparse-checkout stash status stripspace submodule switch symbolic-ref tag unpack-file unpack-objects update-index update-ref update-server-info var verify-commit verify-pack verify-tag version whatchanged worktree write-tree")
  BRANCH_LONG = "show-current list all remotes verbose contains no-contains merged no-merged sort format points-at color no-color column no-column abbrev no-abbrev ignore-case omit-empty quiet"
  BRANCH_VAL = "contains no-contains merged no-merged sort format points-at"
  TAG_LONG = "list sort format contains no-contains merged no-merged points-at column no-column ignore-case color omit-empty"
  setlist(CONFIG_READ, "--get --get-all --get-regexp --get-urlmatch --get-color --get-colorbool --list -l")
  setlist(CONFIG_WRITE, "--add --unset --unset-all --replace-all --rename-section --remove-section --edit -e")
  setlist(CONFIG_VAL, "--file -f --blob --type --default")
  split("sudo:-u sudo:-g sudo:-C sudo:-D sudo:-h sudo:-p sudo:-U sudo:-r sudo:-t sudo:-T sudo:-R doas:-u doas:-C nice:-n xargs:-I xargs:-n xargs:-P xargs:-L xargs:-d xargs:-E xargs:-s xargs:-a xargs:-R xargs:-S parallel:-j parallel:-I stdbuf:-i stdbuf:-o stdbuf:-e timeout:-s timeout:-k timeout:--signal timeout:--kill-after xcrun:--sdk xcrun:-sdk xcrun:--toolchain xcrun:-toolchain arch:-arch caffeinate:-t caffeinate:-w time:-f time:-o exec:-a", tv, " ")
  for (x in tv) { split(tv[x], p, ":"); TV[p[1], p[2]] = 1 }
  ncmd = 0; nq = 0; qh = 1; HDN = 0; HDH = 1; DYNEXEC = 0
  enqueue(raw)
  c = 1
  while (1) {
    while (qh <= nq) { s = Q[qh]; qh++; lex(s) }
    if (c > ncmd) break
    CFGENV = 0
    if (NW[c] > 0) analyze_words(c, 1, NW[c], 0)
    c++
  }
  if (DYNEXEC && heur(raw, 0)) block("a command built at runtime from text that names a destructive git command cannot be checked")
  print "OK"
}
AWK

if ! command -v awk >/dev/null 2>&1; then
  case "$cmd" in *[Gg][Ii][Tt]*) block "block_destructive_git.sh needs awk to inspect git commands" ;; esac
  exit 0
fi
verdict=$(HOOK_CMD="$cmd" HOOK_MODE="$mode" HOOK_CWD="$cwd" LC_ALL=C awk "$PROG" </dev/null 2>/dev/null)
case "$verdict" in
  OK) exit 0 ;;
  BLOCK*) block "${verdict#BLOCK?}" ;;
esac
case "$cmd" in *[Gg][Ii][Tt]*) block "the command could not be analyzed" ;; esac
exit 0
