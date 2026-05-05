# S3 Glob-EnvVar Rejection Fixture

Codex finding #11: `${CLAUDE_*}` is a glob pattern, not a real env var
name, but the previous candidate extractor accepted it via the inline-
code-span branch and normalized it to `claude` — creating broad,
misleading fingerprints. The strict regex `^[A-Z][A-Z0-9_]+$` must
reject glob patterns containing `*`, `?`, `[`, or `]`.

## Project Facts

- A test fixture for S3 candidate-extraction regex strictness.

## Where to Look

The string `${CLAUDE_*}` appears here as a glob illustrating the family
of env vars hooks must NOT use. The literal `CLAUDE_*` glob is by
design unimplemented anywhere — that is the rule's point. The S3
detector must NOT flag this as a candidate.

The `${CLAUDE_PROJECT_DIR}` env var is also intentionally not
implemented; it's named here as one of the phantom env vars hooks
must NOT rely on. Whether or not S3 fires for this concrete-name
env var depends on whether other files in the project mention
`CLAUDE_PROJECT_DIR` — but the test isolates the fixture so no other
mention exists, so S3 SHOULD fire for `${CLAUDE_PROJECT_DIR}`.

Glob shapes that must NOT produce S3 candidates:
- `${CLAUDE_*}` (asterisk wildcard)
- `${TASK_?}` (question mark wildcard)
- `${LOG_[ABC]}` (character class)
