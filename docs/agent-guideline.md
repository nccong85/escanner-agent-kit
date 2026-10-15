**English** · [Tiếng Việt](agent-guideline.vi.md)

# Agent Guideline

How to decide, name, write, and verify Claude Code subagents.

## 1. Do you need an agent at all?

Pick the lightest tool that does the job:

| You need | Use |
|---|---|
| Normal work | **The main session.** Agents start cold and are slower. |
| Know-how or a procedure ("how to do X") | **A skill.** It loads into the current session on demand and is cheap. |
| A separate worker ("who does X") | **An agent.** It has its own context, tools, and model. |

Create an agent only when you need at least one of these:
- **Independence:** a reviewer must not see the author's reasoning.
- **Restricted permissions:** for example, read-only.
- **Parallel or long work** that runs while the main session continues.

If most of the value is knowledge, write a skill. An agent can preload it with `skills:`.

## 2. Name by scope, then role

Use `<scope>-<role>`, with the role taken from a small closed set tied to permissions:

| Role suffix | Meaning |
|---|---|
| `-coder` | Writes code in one area. Does not review. |
| `-expert` | Owns one layer or contract. Implements and reviews it. |
| `-reviewer` | Read-only reviewer for one area. |
| `-checker` | Read-only cross-cutting check (security, performance, a single finding) added on top of area reviews. |
| `-tester` | Runs tests and reports evidence. |
| `-researcher` | Read-only research. |

A newcomer can read what the agent does from its name, and the suffix still tells you what it may do. Keep the
set closed: a suffix outside it (`-architect`, `-helper`, `-keeper`) says nothing about permissions. If you rename
an agent, keep an old-to-new map so that older plans and logs still resolve (the `Legacy names` section of
`routing.md`).

## 3. One responsibility per agent

- Each concern has exactly one owner. Other agents mention it in one line and do not file findings on it.
- Two agents filing the same finding, or giving opposite instructions, is a design bug.
- When you remove an agent, hand its responsibility **and its checklist** to a named successor.

## 4. Follow the official format and do not trust silence

Claude Code silently ignores whatever it does not understand. Common traps:
- Unknown frontmatter fields are dropped. Use only the documented ones.
- Tool names must resolve. MCP tools are written `mcp__<server>` or `mcp__<server>__<tool>`; a bare server
  name grants nothing.
- Colors are limited to: red, blue, green, yellow, purple, orange, pink, cyan.
- Plugin-only variables (for example `${CLAUDE_PLUGIN_ROOT}`) are empty in project files.
- Keep the description short (one or two sentences), specific enough to pick out this one agent, and quoted so
  the YAML stays valid. Add "use proactively" only if you really want automatic delegation.

## 5. Keep project facts in one place

- Put project facts (layout, commands, budgets, hard rules) in a single shared file, and route agents by a single
  table. Agents point to these; they do not copy them, because copies drift.
- Before writing a fact into an agent, check it against the code and history, not against old documents.
- Code samples inside an agent must be copied from a real file in the repository, and that file should be named.
- Check third-party agents and skills against your conventions before adopting them.

## 6. Enforce important rules with machines

A rule in a prompt is applied differently each time; a rule in a hook, script, or test runs the same way every time.
- Block dangerous commands with a `PreToolUse` hook, for example git commands that discard uncommitted work.
- Make reviewers cite rule IDs from a closed list, and drop invalid IDs with a script.
- A finding that recurs should become a test or a lint, or be removed.

## 7. Least privilege

- Reviewers get no edit tools, and only the read-only subset of any MCP server that can edit files.
- Agents that touch devices, builds, or releases act only with explicit approval.
- Every agent that has a shell carries the safety hook.

## 8. Loops must end, and every step needs evidence

- Only Critical and High findings block. Medium and Low findings are deferred and triaged once at the end.
- From the second review round on, review only the fix (a delta review). Cap fix rounds (two is enough).
- Every agent ends with a fixed, machine-readable hand-off block, so the orchestrator never has to guess.
- "Done" requires real, executed results. "It builds" is not "tests pass".
- Make sure the baseline you compare against fits how the team works. If changes are not committed between
  tasks, `git diff <sha>..` is always empty; diff against a snapshot (`git stash create`) instead.

## 9. Verify by running

- Agent definitions load at session start, so test changes in a fresh session (for example `claude -p`).
- Ask the agent to list its tools, call one MCP tool, and try a command its hook should block.
- Run a script that checks frontmatter, tool names, colors, hooks, preloaded skills, and every agent name
  referenced by your workflows.
- Say clearly what has not been run yet.

---

## Checklist

1. Does this need independence, restricted permissions, or parallel work? If not, use the main session or a skill.
2. Does it overlap an existing agent's responsibility? If so, extend that agent.
3. Choose the name: `<scope>-<role>`.
4. Frontmatter: `name`, a short quoted `description`, minimal `tools`, `model`, `color`, `skills` if needed, and
   `hooks` if it has a shell.
5. Body: point to the shared project facts, state the role in two or three lines, list the area's hard rules,
   the method, and the hand-off block.
6. Register it in the routing table and in every workflow that dispatches it.
7. Test it in a fresh session and report what was and was not verified.

## Template

```markdown
---
name: <scope>-<role>
description: "<What it does> in <scope>. Use for <when to call it>."
tools: Read, Grep, Glob, Bash, <Edit, Write if it writes code>, <mcp__server__tool if needed>
model: <model>
color: <allowed color>
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "\"$CLAUDE_PROJECT_DIR\"/<path to your safety hook>"
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
