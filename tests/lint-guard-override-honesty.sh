#!/usr/bin/env bash
# lint-guard-override-honesty.sh — release-time check that the context-file
# guard never advertises an override it cannot honor.
#
# The stewardship gate has two kinds of message. A `warn` lets the write
# proceed, so offering an override there is honest. A `block` refuses the
# write and exits; no acknowledgement is an input to the gate, so an override
# offered on a block path is a promise the guard cannot keep. Users burned an
# hour re-submitting the same edit against that promise (GitHub issue #1).
#
# This lint fails if any `block` call site regains override wording, and fails
# if the `warn` call sites lose theirs.

FAIL=0

GUARDS="hooks/context-file-guard.sh plugin/strategic-partner/hooks/context-file-guard.sh"

# A `block` / `warn` invocation: line start, after whitespace, or after `||`.
BLOCK_RE='(^|[[:space:]]|\|\|[[:space:]]*)block[[:space:]]+"'
WARN_RE='(^|[[:space:]]|\|\|[[:space:]]*)warn[[:space:]]+"'

# An override *offer*: the labelled prompt ("Override:" / "Override option:")
# or the acknowledgement token that never reaches the gate. Matching the bare
# word would also flag a message that denies an override exists, which is
# exactly what the block paths are supposed to say.
OFFER_RE='[Oo]verride([[:space:]]+option)?[[:space:]]*:|exception_label'

for guard in $GUARDS; do
  if [ ! -r "$guard" ]; then
    echo "FAIL  $guard is missing or unreadable (run from the repo root)"
    FAIL=1
    continue
  fi

  block_lines=$(grep -nE "$BLOCK_RE" "$guard")
  warn_lines=$(grep -nE "$WARN_RE" "$guard")

  # Fail closed: if the call sites cannot be found, the lint is not checking
  # anything and must not report a silent pass.
  block_count=$(printf '%s' "$block_lines" | grep -c . )
  warn_count=$(printf '%s' "$warn_lines" | grep -c . )

  if [ "$block_count" -eq 0 ]; then
    echo "FAIL  $guard has no recognizable block call sites — lint cannot verify"
    FAIL=1
  fi
  if [ "$warn_count" -lt 2 ]; then
    echo "FAIL  $guard has $warn_count warn call sites, expected at least 2"
    FAIL=1
  fi

  # 1. No block path may offer an override.
  offenders=$(printf '%s\n' "$block_lines" | grep -E "$OFFER_RE")
  if [ -n "$offenders" ]; then
    echo "FAIL  $guard offers an override on a block path (unreachable promise):"
    printf '%s\n' "$offenders" | sed 's/^/        /'
    FAIL=1
  else
    echo "PASS  $guard offers no override on any of its $block_count block paths"
  fi

  # 2. The warn paths must keep offering one — the write proceeds there.
  warn_with_override=$(printf '%s\n' "$warn_lines" | grep -cE "$OFFER_RE")
  if [ "$warn_with_override" -lt 2 ]; then
    echo "FAIL  $guard has $warn_with_override warn paths offering an override, expected at least 2"
    FAIL=1
  else
    echo "PASS  $guard keeps an override offer on $warn_with_override warn paths"
  fi

  # 3. The block paths must point at the route that actually works.
  if grep -qF 'write it to a script under .scripts/' "$guard"; then
    echo "PASS  $guard points blocked writes at the file-first handoff"
  else
    echo "FAIL  $guard block message does not name the file-first handoff route"
    FAIL=1
  fi
done

# 4. A half-applied fix across the two copies is worse than the original bug.
if cmp -s hooks/context-file-guard.sh plugin/strategic-partner/hooks/context-file-guard.sh; then
  echo "PASS  hooks/context-file-guard.sh mirrors the plugin copy"
else
  echo "FAIL  hooks/context-file-guard.sh differs from the plugin copy"
  FAIL=1
fi

if [ "$FAIL" -eq 0 ]; then
  echo "Guard override-honesty lint passed."
  exit 0
fi

echo "Guard override-honesty lint FAILED."
exit 1
