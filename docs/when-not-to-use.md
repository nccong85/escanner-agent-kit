# When not to use this

- **Small fixes.** A handful of local edits is faster in the main session: run the analyzer, the scoped tests and
  a mutation proof yourself. Skip the delta review.
- **Exploration and prototypes.** The loop optimizes correctness of a finished change, not speed of discovery.
- **Tasks that need shared context across many steps.** Subagents start cold; one long session keeps the context.
- **When you cannot afford the tokens.** Multi-agent runs cost many times a single chat. Set `model: inherit` and
  pick a cheaper session model if needed, but keep the filter strong.
- **When nobody will maintain the rules.** A rule index that never graduates findings into tests becomes noise.

Use it for features that touch several layers, contracts that must stay identical across platforms,
security-sensitive changes, and hot paths with budgets.
