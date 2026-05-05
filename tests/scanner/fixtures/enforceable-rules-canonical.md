# Enforceable Rules — Canonical Phrasing

Codex finding #6: B6 must trigger on the canonical phrases from spec
§ 4.B6 even when written with inline-code backticks. Each rule below
uses one canonical phrase exactly as the spec catalog shows it.

## Behavioral Guardrails

### No `console.log`

No `console.log` calls in production code.

### No `print()`

No `print()` calls left in shipped code.

### No `debugger`

No `debugger` statements in production code.

### No `.env` files in commits

No `.env` files in commits — secrets stay out of version control.

### Always use prettier

Always use prettier for JS/TS formatting; never hand-format.
