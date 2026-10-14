# Security policy

This repository ships prompts, shell hooks and scripts that run inside Claude Code on your machine.

## Reporting a vulnerability
Please report privately through **GitHub → Security → Report a vulnerability** (private vulnerability reporting)
on this repository. Do not open a public issue for security problems.

Include what you ran, what happened, and the Claude Code version. You will get an acknowledgement as soon as
possible.

## Scope
- The `block_destructive_git.sh` hook is a guard against **accidents**, not a security boundary. It parses shell
  text, so a determined command can still bypass it (for example through an interpreter other than a shell, or a
  script file). Report bypasses anyway; they help.
- `config.env` is **read as data, never executed**: only six known keys are accepted, values may reference only
  `$ROOT` and `$CONTEXT_DIR`, and values containing command substitution or shell operators are refused.
- Validators read only files inside your project and never send data anywhere, except `validate_citations.sh`,
  which requests the URLs cited in a research report.
- Review every agent and command before you install them, as you would any code.
