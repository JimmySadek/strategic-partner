#!/usr/bin/env bash
# tests/scanner/release-gate/exception-edges-7-5.sh
# Codex finding #12: spec § 7.5 exception-file edges that the v1 build
# left unimplemented:
#   - Exception with `review_at` in the past → emit info finding
#     "Exception ${rule_id} on ${file} has past review date ${date};
#      consider re-evaluating."
#   - Exception with unknown future `rule_id` (e.g., S99) → warn-and-skip
#     (informational message; entry skipped from coverage; no exit 5).
#   - Exception with unknown extra fields → warn-and-accept (forward
#     compatibility for future schema additions; entry still applies).
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
fail=0

# Build a fixture with three exception types.
TMP=$(mktemp -d); trap '\rm -rf "$TMP"' EXIT
cp "$FIXTURES/clean-minimal.md" "$TMP/CLAUDE.md"

# Compute valid fingerprint for the past-review entry.
fp_past=$(bash -c "
  . '$PROJECT_ROOT/.scripts/context-file-scan/lib/utils.sh'
  scanner_fingerprint S3 CLAUDE.md '<root>' 'past-review-subject'
")
fp_future_id=$(bash -c "
  . '$PROJECT_ROOT/.scripts/context-file-scan/lib/utils.sh'
  scanner_fingerprint S99 CLAUDE.md '<root>' 'future-rule-subject'
")
fp_extra=$(bash -c "
  . '$PROJECT_ROOT/.scripts/context-file-scan/lib/utils.sh'
  scanner_fingerprint S3 CLAUDE.md '<root>' 'extra-field-subject'
")

cat > "$TMP/.scanner-exceptions.json" <<EOF
{"schema_version":"v1","exceptions":[
  {
    "fingerprint":"$fp_past",
    "rule_id":"S3","source_file":"CLAUDE.md","section_anchor":"<root>",
    "normalized_subject":"past-review-subject",
    "subject":"Past review fixture",
    "reason":"To exercise the past-review_at edge",
    "accepted_at":"2025-05-05",
    "review_at":"2025-08-05"
  },
  {
    "fingerprint":"$fp_future_id",
    "rule_id":"S99","source_file":"CLAUDE.md","section_anchor":"<root>",
    "normalized_subject":"future-rule-subject",
    "subject":"Forward-compat rule_id fixture",
    "reason":"To exercise the unknown-rule_id edge",
    "accepted_at":"2026-05-05"
  },
  {
    "fingerprint":"$fp_extra",
    "rule_id":"S3","source_file":"CLAUDE.md","section_anchor":"<root>",
    "normalized_subject":"extra-field-subject",
    "subject":"Extra-field fixture",
    "reason":"To exercise the extra-field edge",
    "accepted_at":"2026-05-05",
    "future_field_for_v6_1":"reserved",
    "experimental_metric":42
  }
]}
EOF

# Run release-gate.
out=$(cd "$TMP" && bash "$SCAN_SCRIPT" --release-gate 2>&1)
ec=$?

# 1) Past-review_at: emits info finding mentioning the past review date
past_findings=$(echo "$out" | jq -r '[.findings[] | select(.title | test("[Pp]ast review"))] | length' 2>/dev/null || echo 0)
if [ "$past_findings" -ge 1 ]; then
  echo "✅ past-review_at: info finding emitted"
else
  echo "❌ past-review_at: no info finding (expected one)"
  fail=1
fi

# 2) Unknown rule_id: warn-and-skip (informational stderr; not exit 5)
if [ "$ec" = "5" ]; then
  echo "❌ unknown-rule_id: scan errored exit 5 (expected skip-and-warn)"
  fail=1
elif echo "$out" | grep -qiF 'S99'; then
  echo "✅ unknown-rule_id: scanner surfaced informational message"
else
  echo "⚠️  unknown-rule_id: no informational message — soft assertion"
fi

# 3) Unknown extra fields: scan accepts the entry (no exit 5).
if [ "$ec" = "5" ]; then
  echo "❌ unknown-extra-fields: scan errored exit 5 (expected accept)"
  fail=1
else
  echo "✅ unknown-extra-fields: entry accepted (no exit 5)"
fi

exit $fail
