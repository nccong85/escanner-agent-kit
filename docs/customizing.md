# Customizing

Everything below is optional. The kit works with its defaults after `/review-loop:init`.

## 1. Keep your files somewhere else

**When:** your brief, rules or specs do not live in the default folders.

By default the kit looks in `.claude/review-loop/` for its files and in `docs/specs/` and `docs/features/` for
specs. To change that, create `.claude/review-loop/config.env` and set only the keys you need:

```
BRIEF_FILE=$ROOT/docs/agents/review_brief.md
RULES_FILE=$ROOT/docs/agents/review_rules.md
SPECS_DIR=$ROOT/documentation/specs
```

| Key | What it points to | Default |
|---|---|---|
| `BRIEF_FILE` | Project facts and review protocol | `.claude/review-loop/review_brief.md` |
| `RULES_FILE` | The list of rule IDs | `.claude/review-loop/review_rules.md` |
| `ROUTING_FILE` | Which agent handles which folder | `.claude/review-loop/routing.md` |
| `PITFALLS_FILE` | Your project's pitfalls list | `.claude/review-loop/common_pitfalls.md` |
| `SPECS_DIR` | Specs | `docs/specs` |
| `FEATURES_DIR` | Feature folders (tasks, state) | `docs/features` |

Values may use only `$ROOT` (the project root) and `$CONTEXT_DIR` (`.claude/review-loop`). The file is read as
plain data and never executed.

The project root is found in this order: `REVIEW_LOOP_PROJECT_DIR` if you set it, then `CLAUDE_PROJECT_DIR`,
then the git root.

## 2. Add rules for your own stack

**When:** you want reviewers to cite rules that are specific to your stack (web, backend, game, …).

Rule IDs look like `R-<NAMESPACE>-<number>`. To add a namespace, add rows to the table in section 2b of
`review_rules.md`, one rule per row:

```
| `R-WEB-1` | Never render user input as raw HTML | High |
| `R-WEB-2` | Every API call has a timeout | Medium |
```

That is all. As soon as a row exists, reviewers may cite `R-WEB-1` and `validate_rule_ids.sh` accepts it. An ID
with no row is dropped, so a reviewer cannot invent one.

## 3. Add your own agent

**When:** you need a coder or reviewer for a part of your codebase the kit does not cover.

1. Name it `<role>-<scope>`, for example `review-web` or `dev-backend`. The roles and what each may do are in
   [agent-guideline.md](agent-guideline.md).
2. Put the file in `.claude/agents/<name>.md` (a project agent) or in your own plugin (see section 4).
3. In the agent's instructions, tell it to read `.claude/review-loop/review_brief.md` first, and to end its reply
   with the hand-off block from §B7 of that brief.
4. Add the agent to `routing.md`, next to the folders it is responsible for. Write a plugin agent as
   `<plugin>:<agent>`, for example `my-stack:review-web`.

## 4. Make a plugin for your own stack

**When:** you want to reuse a set of agents across several projects, the way `flutter-native-agents` does for
Flutter.

1. Copy the folder `plugins/flutter-native-agents` and rename it.
2. Replace the agents inside it with your own.
3. In its `.claude-plugin/plugin.json`, keep `"dependencies": ["review-loop"]`, so the git safety hook and the
   validators are installed with it.
4. List the plugin in your own marketplace file.

Note: Claude Code ignores `hooks`, `mcpServers` and `permissionMode` in the frontmatter of a **plugin** agent. You
do not need them: the safety hook comes from `review-loop`.

## 5. Rename an agent

**When:** you change an agent's name after it has already been used.

Add the old and new names to the "Legacy names" section of `routing.md`, for example
`code-review-web → review-web`. Older `execution_state.md` files still mention the old name, and the pipeline
uses this map to find the right agent.
