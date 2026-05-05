# Enforceable Rules

A project whose rules belong in linter / pre-commit / hook layers.

## Behavioral Guardrails

### No console.log

No console.log calls in production code. No debugger. Max line length 100.

### Pre-commit safety

Never commit secrets. No .env files in commits. All commits must pass tests.

### Format consistency

Tabs vs spaces: use 2-space indent. Indent with two spaces. Consistent
spacing matters.
