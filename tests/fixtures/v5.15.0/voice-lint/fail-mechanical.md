# Voice Lint Fixture — Mechanical Failures

This fixture deliberately contains all five mechanical patterns the voice
lint detects. The script must exit 1 and report exactly five violation
lines (one per pattern).

## Pattern 1 — function-call notation in prose

The validator validate_tool_availability() now also covers backtick spans.

## Pattern 2 — incident ID in prose

This was caused by INC-2026-03-30 in the previous release.

## Pattern 3 — internal direction reference

Direction 6 mandates that voice rules apply to every user-facing artifact.

## Pattern 4 — internal layer reference

Layer 3 catches violations the runtime guard cannot.

## Pattern 5 — raw line reference

The matcher lives at line 597 of validators.sh and was rewritten last week.
