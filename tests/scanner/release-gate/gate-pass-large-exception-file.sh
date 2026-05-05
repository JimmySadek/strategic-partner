#!/usr/bin/env bash
# 200 defensive exceptions: gate passes within performance budget
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
TMP=$(mktemp -d); trap '\rm -rf "$TMP"' EXIT
cp "$FIXTURES/clean-minimal.md" "$TMP/CLAUDE.md"
exceptions='['
for i in $(seq 1 200); do
  fp=$(bash -c "
    . '$PROJECT_ROOT/.scripts/context-file-scan/lib/utils.sh'
    scanner_fingerprint S3 CLAUDE.md '<root>' 'defensive-$i'
  ")
  if [ "$i" -gt 1 ]; then exceptions="${exceptions},"; fi
  exceptions="${exceptions}{\"fingerprint\":\"$fp\",\"rule_id\":\"S3\",\"source_file\":\"CLAUDE.md\",\"section_anchor\":\"<root>\",\"normalized_subject\":\"defensive-$i\",\"subject\":\"x\",\"reason\":\"y\",\"accepted_at\":\"2026-05-05\"}"
done
exceptions="${exceptions}]"
echo "{\"schema_version\":\"v1\",\"exceptions\":$exceptions}" > "$TMP/.scanner-exceptions.json"
cd "$TMP"
bash "$SCAN_SCRIPT" --release-gate >/dev/null 2>&1
ec=$?
[ "$ec" = "0" ] && echo "✅ 200-exception file → exit 0 on clean fixture" || { echo "❌ exit $ec"; exit 1; }
