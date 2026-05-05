#!/usr/bin/env bash
# tests/scanner/infra/schema-validation.sh
# Asserts that every emitted finding has the 11 required fields
# documented in schemas/scanner-findings.json + correct enum values.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/_test_helper.sh"

# Run scan against the bloated fixture (will produce findings).
result=$(run_scan --file "$FIXTURES/bloated-no-sections.md") || true
[ -z "$result" ] && { echo "❌ scan produced no output"; exit 1; }

# Validate JSON shape
if ! echo "$result" | jq -e . >/dev/null 2>&1; then
  echo "❌ scan output is not valid JSON"
  exit 1
fi
echo "✅ scan output is valid JSON"

# Each finding must have all 11 required fields with valid types.
findings=$(echo "$result" | jq -c '.findings[]')
[ -z "$findings" ] && { echo "❌ no findings emitted from bloated fixture"; exit 1; }

count=$(echo "$result" | jq '.findings | length')
echo "✅ findings count: $count"

while IFS= read -r f; do
  for required in rule_id rule_class severity title source_file section_anchor fingerprint template_substitutions normalized_subject suggested_action exception_label; do
    val=$(echo "$f" | jq --arg r "$required" 'has($r)')
    if [ "$val" != "true" ]; then
      echo "❌ finding missing required field: $required"
      echo "$f" | jq .
      exit 1
    fi
  done

  # Enum: severity ∈ {info, warn, surface-loudly}
  sev=$(echo "$f" | jq -r .severity)
  case "$sev" in
    info|warn|surface-loudly) ;;
    *) echo "❌ invalid severity: $sev"; exit 1 ;;
  esac

  # Enum: rule_class ∈ {structural, behavioral}
  rc=$(echo "$f" | jq -r .rule_class)
  case "$rc" in
    structural|behavioral) ;;
    *) echo "❌ invalid rule_class: $rc"; exit 1 ;;
  esac

  # rule_id pattern
  rid=$(echo "$f" | jq -r .rule_id)
  case "$rid" in
    S[1-8]|B[1-8]) ;;
    *) echo "❌ invalid rule_id: $rid"; exit 1 ;;
  esac

  # fingerprint is 16 hex chars
  fp=$(echo "$f" | jq -r .fingerprint)
  if ! echo "$fp" | grep -qE '^[0-9a-f]{16}$'; then
    echo "❌ invalid fingerprint format: $fp"
    exit 1
  fi
done <<<"$findings"

echo ""
echo "── schema-validation: all $count findings conform to schemas/scanner-findings.json ──"
exit 0
