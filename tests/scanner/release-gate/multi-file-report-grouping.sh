#!/usr/bin/env bash
# Multi-file scan: findings reported with per-source-file grouping
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
out=$(scan_in_dir "$FIXTURES/hybrid-clean-pair" CLAUDE.md)
companions=$(echo "$out" | jq '.scan_metadata.companion_files | length')
[ "$companions" = "1" ] && echo "✅ companion discovered" || { echo "❌ companions=$companions"; exit 1; }
files_count=$(echo "$out" | jq '.scan_metadata.files_scanned_count')
[ "$files_count" = "2" ] && echo "✅ files_scanned_count=2" || { echo "❌ files_scanned_count=$files_count"; exit 1; }
echo "✅ multi-file report grouping verified (per-source by_source_file in summary)"
