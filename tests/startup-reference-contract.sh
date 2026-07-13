#!/usr/bin/env bash
# Contract for direct startup references and demand-only routing maintenance.

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

for skill in "$ROOT/SKILL.md" "$ROOT/plugin/strategic-partner/skills/strategic-partner/SKILL.md"; do
  base=$(dirname "$skill")
  while IFS= read -r ref; do
    [ -e "$base/$ref" ] && pass "$(basename "$skill") resolves $ref" || fail "$(basename "$skill") resolves $ref"
  done < <(sed -n '/<reference_files>/,/<\/reference_files>/s/.*| `\([^`]*\.md\)` |.*/\1/p' "$skill")
  grep -F '| `references/skill-routing-matrix.md` | Demand-only routing' "$skill" >/dev/null \
    && pass "$(basename "$skill") keeps routing demand-only" \
    || fail "$(basename "$skill") keeps routing demand-only"
done

for checklist in "$ROOT/references/startup-checklist.md" "$ROOT/plugin/strategic-partner/skills/strategic-partner/references/startup-checklist.md"; do
  if sed -n '1,40p' "$checklist" | grep -F 'Agent D' >/dev/null; then
    fail "$(basename "$checklist") startup diagram excludes Agent D"
  else
    pass "$(basename "$checklist") startup diagram excludes Agent D"
  fi
  grep -F 'counts come from Agent D' "$checklist" >/dev/null \
    && fail "$(basename "$checklist") removes stale missing-routing counts" \
    || pass "$(basename "$checklist") removes stale missing-routing counts"
  grep -F '1. **Auto-memory**' "$checklist" >/dev/null \
    && fail "$(basename "$checklist") removes Claude auto-memory startup probing" \
    || pass "$(basename "$checklist") removes Claude auto-memory startup probing"
  grep -F 'Three or more visible status signals require the compact table below.' "$checklist" >/dev/null \
    && pass "$(basename "$checklist") requires a visual multi-signal orientation" \
    || fail "$(basename "$checklist") requires a visual multi-signal orientation"
  grep -F '| Area | Status | What it means |' "$checklist" >/dev/null \
    && pass "$(basename "$checklist") defines the compact orientation table" \
    || fail "$(basename "$checklist") defines the compact orientation table"
done

printf '\nResult: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
