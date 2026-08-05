#!/usr/bin/env bash
# lint-guard-allowlist.sh — release-time drift check for SP managed paths.
#
# This catches the failure mode where one guard copy, reference doc, or release
# gate forgets a managed artifact path and the omission is rediscovered live.

FAIL=0

require_token() {
  file=$1
  token=$2
  if grep -qF "$token" "$file" 2>/dev/null; then
    echo "PASS  $file contains $token"
  else
    echo "FAIL  $file missing $token"
    FAIL=1
  fi
}

require_same() {
  left=$1
  right=$2
  if cmp -s "$left" "$right"; then
    echo "PASS  $left mirrors $right"
  else
    echo "FAIL  $left differs from $right"
    FAIL=1
  fi
}

require_same hooks/guard-impl.sh plugin/strategic-partner/hooks/guard-impl.sh

for guard in hooks/guard-impl.sh plugin/strategic-partner/hooks/guard-impl.sh; do
  require_token "$guard" ".prompts"
  require_token "$guard" ".handoffs"
  require_token "$guard" ".scripts"
  require_token "$guard" ".backlog"
  require_token "$guard" "specs"
  require_token "$guard" "CLAUDE.md"
  require_token "$guard" "AGENTS.md"
  require_token "$guard" "GEMINI.md"
  require_token "$guard" "CHANGELOG.md"
  require_token "$guard" "README.md"
  require_token "$guard" "SKILL.md"
  require_token "$guard" ".claude-plugin/plugin.json"
  require_token "$guard" "output-styles/strategic-partner-voice.md"
  require_token "$guard" ".sp-managed"
  require_token "$guard" "trusted-contracts"
  require_token "$guard" "trust_marker_confirmation_present"
  require_token "$guard" "Activate stewardship contract"
  require_token "$guard" "managed_extension_allowed"
  require_token "$guard" "first_segment"
  require_token "$guard" "gsub(\"[—–]\""
done

for doc in \
  references/hooks-integration.md \
  plugin/strategic-partner/skills/strategic-partner/references/hooks-integration.md \
  references/stewardship-contract.md \
  plugin/strategic-partner/skills/strategic-partner/references/stewardship-contract.md
do
  require_token "$doc" ".sp-managed"
  require_token "$doc" "local activation"
  require_token "$doc" "output-styles/strategic-partner-voice.md"
  require_token "$doc" ".claude-plugin/plugin.json"
done

require_token claudedocs/release-process.md "tests/lint-guard-allowlist.sh"

if [ "$FAIL" -eq 0 ]; then
  echo "Guard allow-list lint passed."
  exit 0
fi

echo "Guard allow-list lint FAILED."
exit 1
