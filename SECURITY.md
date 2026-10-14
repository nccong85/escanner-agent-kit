# Security policy

This repository ships prompts, shell hooks and scripts that run inside Claude Code on your machine.

## Reporting a vulnerability
Please report privately through **GitHub → Security → Report a vulnerability** (private vulnerability reporting)
on this repository. Do not open a public issue for security problems.

Include what you ran, what happened, and the Claude Code version. You will get an acknowledgement as soon as
possible.

## Scope
- The `block_destructive_git.sh` hook is a guard against **accidents**, not a security boundary. A determined
  command can bypass it (for example through an interpreter other than a shell). Report bypasses anyway; they
  help.
- Validators read only files inside your project and never send data anywhere, except `validate_citations.sh`,
  which requests the URLs cited in a research report.
- Review every agent and command before you install them, as you would any code.
