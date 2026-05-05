#!/usr/bin/env bash
# tests/scanner/unit/b4-full-inlined.sh
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
fail=0

# Positive: inline BG with anti-pattern + corrected approach blocks
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/CLAUDE.md" <<MD
# Project
## Behavioral Guardrails

### Rule 1
Some text.

❌ Anti-pattern (something):
\`\`\`
bad code
\`\`\`

✅ Corrected approach:
\`\`\`
good code
\`\`\`

### Rule 2

❌ Anti-pattern (other):
\`\`\`
bad
\`\`\`

✅ Corrected approach:
\`\`\`
good
\`\`\`
MD
out=$(cd "$TMP" && bash "$SCAN_SCRIPT" --file CLAUDE.md 2>/dev/null)
assert_finding_fires "$out" B4 || fail=1

# Negative: stub form (no anti-pattern markers, short body)
out=$(scan_in_dir "$FIXTURES/hybrid-clean-pair" CLAUDE.md)
assert_finding_silent "$out" B4 || fail=1

exit $fail
