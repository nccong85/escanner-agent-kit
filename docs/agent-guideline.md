**English** · [Tiếng Việt](agent-guideline.vi.md) · [日本語](agent-guideline.ja.md)

# Agent Guideline

Checked against the [Claude Code subagent docs](https://code.claude.com/docs/en/sub-agents).

## 1. When do you need an agent?

Use the lightest tool:

- **Main session:** everyday work.
- **Skill:** know-how or a procedure. An agent can preload it with `skills:`.
- **Agent:** only for independence, restricted permissions, or background/parallel work.

## 2. Naming: `<scope>-<role>`

The name says what the agent does; the suffix says what it may do.

| Suffix | Meaning |
|---|---|
| `-coder` | Writes code. Does not review. |
| `-expert` | Writes and reviews code in its own area. |
| `-reviewer` | Reviews only; may `Write` only its own report file. |
| `-checker` | Cross-area deep check (security, performance), with a reviewer's permissions. |
| `-tester` | Runs tests and reports results. |
| `-researcher` | Read-only research. |

## 3. Basic rules

- **Only one agent files each kind of finding.** When several agents review the same diff (for example
  `flutter-reviewer`, `performance-checker` and `security-checker` in parallel), overlapping scopes cause:
  - duplicates: one defect reported several times, at double the cost;
  - conflicts: two agents want opposite changes on the same line.

- **Write the frontmatter as documented.**
  - Use only documented fields; only `name` and `description` are required.
  - `description` says *when* to delegate ("Use when …"), short and quoted. All agents' descriptions share a
    15,000-token budget.
  - MCP: a whole server is `mcp__<server>__*`; the bare `mcp__<server>` works only in `disallowedTools`.
  - Colors: red, blue, green, yellow, purple, orange, pink, cyan.
  - Plugin agents ignore `hooks`, `mcpServers` and `permissionMode`.
- **Shared project facts (test commands, budgets, folders…) are written in one file only.** Each agent says "read
  that file first" instead of defining its own.

## 4. Permissions

- **Grant only the tools the agent needs.**
  - Always write the `tools:` line. Without it the agent gets *every* tool, every MCP tool included.
  - A reviewer only reads and writes its report, so it gets no `Edit`.
  - To grant almost everything but block a few tools, list the blocked ones in `disallowedTools`.
  - Do not let an agent call other agents through its `tools:`.
- **Enforce important rules with a hook or script, not only the prompt.**
- **Get confirmation** before an agent runs on a real device, builds or releases.

## 5. Review loop

- **Only Critical/High findings make the coder fix now.** Medium/Low go on a list, reviewed once when the
  feature is done.
- **From the second review on, the reviewer looks only at what was just fixed**, not the whole diff again
  (delta review).
- **At most 2 fix rounds.** If a blocker remains after 2 rounds, stop and tell a human: a third round tends to
  produce new findings instead of converging.
- **Say "done" only when the tests actually ran** and produced a result, not just built.
- **Agents return results in a fixed format** (for example an `ACTION: REVIEW_REQUIRED` line plus the files
  changed), so the main session can read them without guessing.

## 6. Verify

1. **Let Claude Code load the new version before testing.**
2. **Give the agent a small check task:**
   - ask which tools it has, and compare with its `tools:` line;
   - have it call one MCP tool (for example serena) and see that the call works;
   - have it run a command the hook must block, and see that it is blocked.
3. **Report honestly.**

---

## Checklist

1. Need independence, restricted permissions or parallel work? If not, use the main session or a skill.
2. Overlaps an existing agent? Then extend that agent.
3. Name `<scope>-<role>`.
4. Frontmatter: `name`, `description` (when to use), minimal `tools`, `model`, `color`, `skills` if needed.
5. Body: point to the project facts file, role (2–3 lines), hard rules, method, hand-off block.
6. Register it in the routing table and in every workflow that delegates to it.
7. Verify as in section 6.

## Template

```markdown
---
name: <scope>-<role>
description: "<What it does> in <scope>. Use when <when to call it>."
tools: Read, Grep, Glob, Bash, Write, <Edit if it writes code>, <mcp__server__* if needed>
model: <model>
color: <allowed color>
---

## Binding context
Read <shared project facts file> first. It overrides this file on conflict.

## Role
<Two or three lines.>

## Hard rules
- <Rules specific to this area.>

## Method
1. <Steps.>

## Hand-off
<The exact block the orchestrator parses.>
```
