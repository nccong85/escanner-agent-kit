**English** · [Tiếng Việt](customizing.vi.md) · [日本語](customizing.ja.md)

# Customizing

None of the settings below are required. After `/review-gate:init` the kit runs with its defaults.

## 1. Set file paths

**When:** your brief, rules or specs are not in the default folders.

The kit looks for its files in `.claude/review-gate/` and for specs in `docs/specs/` and `docs/features/`. To
change where the validator scripts look, set only the keys you need in `.claude/review-gate/config.env` (`init`
copies it):

```
BRIEF_FILE=$ROOT/docs/agents/review_brief.md
RULES_FILE=$ROOT/docs/agents/review_rules.md
SPECS_DIR=$ROOT/documentation/specs
```

| Key | Path | Default |
|---|---|---|
| `BRIEF_FILE` | Project facts and review protocol | `.claude/review-gate/review_brief.md` |
| `RULES_FILE` | The list of rule IDs | `.claude/review-gate/review_rules.md` |
| `ROUTING_FILE` | Which agent handles which folder | `.claude/review-gate/routing.md` |
| `PITFALLS_FILE` | Your project's pitfalls list | `.claude/review-gate/common_pitfalls.md` |
| `SPECS_DIR` | Specs | `docs/specs` |
| `FEATURES_DIR` | Feature folders (tasks, state) | `docs/features` |

Values may use only `$ROOT` (the project root) and `$CONTEXT_DIR` (`.claude/review-gate`).
Only the validator scripts read `config.env`; agent and command prompts always read `.claude/review-gate/<file>`.
To keep a file elsewhere, also symlink it there, for example
`ln -s ../../docs/agents/review_brief.md .claude/review-gate/review_brief.md`.

The project root is, in order: `REVIEW_GATE_PROJECT_DIR` if set, `CLAUDE_PROJECT_DIR`, the git root, the current
directory.

## 2. Add rules for your own stack

**When:** you want reviewers to cite rules for your stack (web, backend, game, …).

Rule IDs look like `R-<NAMESPACE>-<number>`. To add a namespace, add rows to the table in section 2b of
`review_rules.md`, one rule per row:

```
| `R-WEB-1` | Never render user input as raw HTML | High |
| `R-WEB-2` | Every API call has a timeout | Medium |
```

Once it is set, reviewers may cite `R-WEB-1` and `validate_rule_ids.sh` accepts it. An ID with no row is
dropped, so reviewers cannot invent one.

## 3. Add your own agent

**When:** you need a coder or reviewer for a part of your codebase the kit does not cover.

1. Name it `<scope>-<role>`, for example `web-reviewer` or `backend-coder`. Roles and their permissions are in
   [agent-guideline.md](agent-guideline.md).
2. Put the file in `.claude/agents/<name>.md` (a project agent) or in your own plugin (see section 4).
3. Tell the agent to read `.claude/review-gate/review_brief.md` first and to end its reply with the hand-off block
   from §B7 of that brief. A reviewer also needs `Write` in its `tools:` line to write its report file (§B7), and
   no `Edit`.
4. Add the agent to `routing.md` next to the folders it owns. Write a plugin agent as `<plugin>:<agent>`, for
   example `my-stack:web-reviewer`.

## 4. Make a plugin for your own stack

**When:** you want to reuse a set of agents across projects, as `flutter-native` does for Flutter.

1. Copy `plugins/flutter-native` and rename it. In its `.claude-plugin/plugin.json`, change `name`, `displayName`
   and `description`, or the copy clashes with the original.
2. Replace its agents with your own.
3. Keep `"dependencies": ["review-gate"]` in that `plugin.json` so the git safety hook and the validators install
   with it.
4. List the plugin in your own marketplace file.

Claude Code ignores `hooks`, `mcpServers` and `permissionMode` in a plugin agent's frontmatter. You do not need
them: the safety hook comes from `review-gate`.

## 5. Rename an agent

**When:** you rename an agent that has already been used.

Add the old and new names to the "Legacy names" section of `routing.md`, for example `review-web → web-reviewer`.
Older `execution_state.md` files still use the old name, and the pipeline uses this map to find the right agent.
