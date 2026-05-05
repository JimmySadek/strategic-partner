# Agents Test Project — Broken Stub

The behavioral guardrails section points at a non-existent companion
under `.codex/rules/` so the scanner must emit B2 (hybrid broken — stub
without rules file). Per Codex finding #5, B2 must work for non-Claude
stub pointers, not only `.claude/rules/*.md`.

## Project Facts

- A minimal AGENTS.md whose stub pointer is intentionally broken.

## Behavioral Guardrails

When editing source files in this project, see
[`.codex/rules/source-editing.md`](.codex/rules/source-editing.md) for
the worked examples. (The companion file is intentionally absent in
this fixture so B2 fires.)
