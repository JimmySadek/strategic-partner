# Voice Transcript Fixture — All Six Mechanical Patterns

This fixture mocks SP-authored chat content with each of the six voice
patterns appearing exactly once outside code blocks. The transcript lint
should detect exactly six mechanical violations on this file (one per
pattern type, same TYPE labels as the static-file lint).

## Pattern 1 — function-call notation in prose

The helper validate_voice_patterns() is the single source of truth for the regex set.

## Pattern 2 — incident ID in prose

This was the same failure mode as INC-2026-03-30 from a few releases back.

## Pattern 3 — internal direction reference

Direction 6 governs how user-facing artifacts get linted before each release.

## Pattern 4 — internal layer reference

Layer 3 catches violations the runtime guard cannot see.

## Pattern 5 — raw line reference

The relevant matcher lives at line 597 of validators.sh.

## Pattern 6 — internal deliverable reference

I'll start with deliverable 3 since it depends on the helper from deliverable 1.

## Code block — patterns inside should NOT fire

```bash
# Function calls inside code blocks are legitimate, e.g. validate_voice_patterns()
# Direction 1, Layer 1, line 1, deliverable 1, INC-2026-01-01
```

## Blockquote — patterns inside should NOT fire

> validate_tool_availability() is described in Layer 3 of the architecture,
> see INC-2026-03-30, Direction 6, line 597, deliverable 3.

## Recap

A non-developer reading this fixture without the patterns would still
understand the gist — release safety relies on automated checks. The
fixture exists only to drive the lint; it should never reach a user.
