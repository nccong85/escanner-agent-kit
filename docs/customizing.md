# Customizing

## Paths
The validators read `.claude/review-loop/config.env` if it exists. Override any of:
`BRIEF_FILE`, `RULES_FILE`, `ROUTING_FILE`, `PITFALLS_FILE`, `SPECS_DIR`, `FEATURES_DIR`.
`REVIEW_LOOP_PROJECT_DIR` overrides the project root (default: `CLAUDE_PROJECT_DIR`, then the git root).

## Add a rule namespace for your stack
Add rows to `review_rules.md` §2b: `| \`R-WEB-1\` | <rule> | <severity> |`. Any `R-<NS>-<n>` that appears as a row
resolves; nothing else needs to change.

## Add your own agents
Follow [agent-guideline.md](agent-guideline.md): name `<role>-<scope>`, point the body at
`.claude/review-loop/review_brief.md`, end with the §B7 hand-off block, and register the agent in `routing.md`.
Project agents live in `.claude/agents/`; plugin agents are referenced as `<plugin>:<agent>`.

## Write your own stack plugin
Copy `plugins/flutter-native-agents`, replace the agents, and add the plugin to your own marketplace with
`"dependencies": ["review-loop"]`. Plugin agents ignore `hooks`, `mcpServers` and `permissionMode` in their
frontmatter; the safety hook comes from `review-loop`.

## Rename an agent
Keep the old → new map in the "Legacy names" section of `routing.md`, so older `execution_state.md` files resolve.
