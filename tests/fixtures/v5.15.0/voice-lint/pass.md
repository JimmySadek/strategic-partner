# Voice Lint Fixture — Pass

This fixture exercises the voice lint with content that should read clean.
The script must exit 0 with no violation output.

## What this checks

The lint scans for jargon-loaded patterns in user-facing artifacts. This
fixture demonstrates clean voice: function names appear only inside fenced
code blocks where they belong, and there are no internal references like
incident IDs, layer numbers, direction numbers, or raw line callouts.

## Code block — function calls allowed inside

```bash
validate_tool_availability "$turn_text"
parse_response_envelope() {
  local foo=$1
}
```

## Plain-English description

The release-time check that scans handoffs for protocol violations is named
the transcript lint. The earlier version of the rule applied only at session
start; the newer version applies to every artifact written during the
release ceremony.

## Code block with internal references — allowed inside

```
Layer 1, Layer 2, Layer 3
Direction 4
INC-2026-03-30
line 597
```

## Recap

When a non-developer reads this paragraph they should understand the gist:
release safety comes from two places — the live guard while you work and the
batch check that runs before pushing.
