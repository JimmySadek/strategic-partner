#!/usr/bin/env bash
# tests/scanner/release-gate/quiet-mode-coverage.sh
# Codex finding #13 — scanner-side verification of the quiet-mode
# data flow. The startup-checklist.md dispatch reads
# `release_gate.coverage.uncovered_count`; this test confirms:
#   - The scanner emits the field via `--release-gate`.
#   - When all warn+ findings are covered by exceptions, uncovered=0
#     (so the quiet-mode dispatch suppresses the bullet).
#   - When findings exceed coverage, uncovered>0 (so the quiet-mode
#     dispatch surfaces the bullet).
#
# The session-acked-fingerprint and SP_HANDOFF=1 paths require a fresh
# Claude Code session to exercise the orchestration; they are
# documented in startup-checklist.md and not driven by this scanner-
# level test.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
fail=0

# Scenario 1: scan a fixture with one warn-level finding, one S2,
# zero exceptions. Expect uncovered_count >= 1 → bullet would surface.
TMP=$(mktemp -d); trap '\rm -rf "$TMP"' EXIT
cp "$FIXTURES/bloated-no-sections.md" "$TMP/CLAUDE.md"
cd "$TMP"
out=$(bash "$SCAN_SCRIPT" --release-gate 2>/dev/null)
ec=$?
uncovered=$(echo "$out" | jq -r '.release_gate.coverage.uncovered_count // 0')
if [ "$uncovered" -ge 1 ]; then
  echo "✅ no exceptions: uncovered_count=$uncovered (bullet would surface)"
else
  echo "❌ no exceptions: uncovered_count=$uncovered, expected ≥1 (exit=$ec)"
  fail=1
fi
cd "$PROJECT_ROOT"

# Scenario 2: same fixture, but every warn+ finding covered by an
# exception → uncovered_count should be 0 (bullet suppressed).
TMP2=$(mktemp -d); trap '\rm -rf "$TMP" "$TMP2"' EXIT
cp "$FIXTURES/bloated-no-sections.md" "$TMP2/CLAUDE.md"

# First scan to discover fingerprints
cd "$TMP2"
seed=$(bash "$SCAN_SCRIPT" --report-only 2>/dev/null)
warn_fps=$(echo "$seed" | jq -r '.findings[] | select(.severity != "info") | [.fingerprint, .rule_id, .source_file, .section_anchor, .normalized_subject] | @tsv')
# Build exceptions covering each warn+ finding
exc_array='[]'
while IFS=$'\t' read -r fp rid src anchor norm; do
  [ -z "$fp" ] && continue
  exc_array=$(echo "$exc_array" | jq \
    --arg fp "$fp" --arg rid "$rid" --arg src "$src" \
    --arg anchor "$anchor" --arg norm "$norm" \
    '. + [{fingerprint: $fp, rule_id: $rid, source_file: $src, section_anchor: $anchor, normalized_subject: $norm, subject: "auto", reason: "auto", accepted_at: "2026-05-05"}]')
done <<EOF
$warn_fps
EOF
echo "$exc_array" | jq '{schema_version: "v1", exceptions: .}' > "$TMP2/.scanner-exceptions.json"
out=$(bash "$SCAN_SCRIPT" --release-gate 2>/dev/null)
ec=$?
uncovered=$(echo "$out" | jq -r '.release_gate.coverage.uncovered_count // 0')
if [ "$uncovered" = "0" ]; then
  echo "✅ all warn+ covered: uncovered_count=0 (bullet would suppress)"
else
  echo "❌ all warn+ covered: uncovered_count=$uncovered, expected 0 (exit=$ec)"
  fail=1
fi
cd "$PROJECT_ROOT"

exit $fail
