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
#
# Hardened after the cross-model NO-GO review demonstrated two blind spots:
#   - A call split across a line continuation (`block \` on one line, the
#     message on the next) was invisible to the line-based grep. Call sites
#     are now detected on continuation-joined lines.
#   - The file-first-route check accepted one matching message anywhere in
#     the file. It now runs per hard-block site: every block message that
#     declares finality must itself name the working route.
# A negative self-test at the bottom keeps both fixes honest: a deliberately
# broken guard fixture (multiline block offering an override) must be caught
# by the hardened logic, and must be shown invisible to the old line-based
# logic.

FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

GUARDS="hooks/context-file-guard.sh plugin/strategic-partner/hooks/context-file-guard.sh"

# A `block` / `warn` invocation on a joined line: after whitespace or `||`.
# Joined lines carry a "NNN: " prefix, so line-start calls sit after a space.
BLOCK_RE='(^|[[:space:]]|\|\|[[:space:]]*)block[[:space:]]+"'
WARN_RE='(^|[[:space:]]|\|\|[[:space:]]*)warn[[:space:]]+"'

# An override *offer*: the labelled prompt ("Override:" / "Override option:")
# or the acknowledgement token that never reaches the gate. Matching the bare
# word would also flag a message that denies an override exists, which is
# exactly what the block paths are supposed to say.
OFFER_RE='[Oo]verride([[:space:]]+option)?[[:space:]]*:|exception_label'

# A hard-block declaration: the message tells the user the refusal is final.
# Every such message must also name the route that actually works.
FINAL_RE='[Tt]his block is final|no override'
ROUTE_STR='write it to a script under .scripts/'

# Join backslash-continued lines so a call written as `block \` + `"..."` is
# one call site. Each joined line keeps its first physical line number,
# emitted as "NNN: " so failures still point somewhere useful.
join_continuations() {
  awk '{
    line = $0
    if (buf == "") start = NR
    if (line ~ /\\$/) { sub(/\\$/, "", line); buf = buf line; next }
    print start ": " buf line
    buf = ""
  }
  END { if (buf != "") print start ": " buf }' "$1"
}

# Run every per-file check against one guard. Prints PASS/FAIL lines and
# returns nonzero if any check failed.
check_guard() {
  guard="$1"
  rc=0

  joined=$(join_continuations "$guard")
  block_lines=$(printf '%s\n' "$joined" | grep -E "$BLOCK_RE")
  warn_lines=$(printf '%s\n' "$joined" | grep -E "$WARN_RE")

  # Fail closed: if the call sites cannot be found, the lint is not checking
  # anything and must not report a silent pass.
  block_count=$(printf '%s' "$block_lines" | grep -c . )
  warn_count=$(printf '%s' "$warn_lines" | grep -c . )

  if [ "$block_count" -eq 0 ]; then
    echo "FAIL  $guard has no recognizable block call sites — lint cannot verify"
    rc=1
  fi
  if [ "$warn_count" -lt 2 ]; then
    echo "FAIL  $guard has $warn_count warn call sites, expected at least 2"
    rc=1
  fi

  # 1. No block path may offer an override.
  offenders=$(printf '%s\n' "$block_lines" | grep -E "$OFFER_RE")
  if [ -n "$offenders" ]; then
    echo "FAIL  $guard offers an override on a block path (unreachable promise):"
    printf '%s\n' "$offenders" | sed 's/^/        /'
    rc=1
  else
    echo "PASS  $guard offers no override on any of its $block_count block paths"
  fi

  # 2. The warn paths must keep offering one — the write proceeds there.
  warn_with_override=$(printf '%s\n' "$warn_lines" | grep -cE "$OFFER_RE")
  if [ "$warn_with_override" -lt 2 ]; then
    echo "FAIL  $guard has $warn_with_override warn paths offering an override, expected at least 2"
    rc=1
  else
    echo "PASS  $guard keeps an override offer on $warn_with_override warn paths"
  fi

  # 3. Every hard-block site (a block message declaring finality) must itself
  # point at the route that actually works — not one match somewhere in the
  # file. Fail closed if no hard-block site is recognizable.
  hard_lines=$(printf '%s\n' "$block_lines" | grep -E "$FINAL_RE")
  hard_count=$(printf '%s' "$hard_lines" | grep -c . )
  if [ "$hard_count" -eq 0 ]; then
    echo "FAIL  $guard has no finality-declaring block sites — route check cannot verify"
    rc=1
  else
    route_missing=$(printf '%s\n' "$hard_lines" | grep -vF "$ROUTE_STR")
    if [ -n "$route_missing" ]; then
      echo "FAIL  $guard hard-block site(s) do not name the file-first handoff route:"
      printf '%s\n' "$route_missing" | sed 's/^/        /'
      rc=1
    else
      echo "PASS  $guard names the file-first handoff on all $hard_count hard-block sites"
    fi
  fi

  return $rc
}

for guard in $GUARDS; do
  if [ ! -r "$guard" ]; then
    echo "FAIL  $guard is missing or unreadable (run from the repo root)"
    FAIL=1
    continue
  fi
  check_guard "$guard" || FAIL=1
done

# 4. A half-applied fix across the two copies is worse than the original bug.
if cmp -s hooks/context-file-guard.sh plugin/strategic-partner/hooks/context-file-guard.sh; then
  echo "PASS  hooks/context-file-guard.sh mirrors the plugin copy"
else
  echo "FAIL  hooks/context-file-guard.sh differs from the plugin copy"
  FAIL=1
fi

# 5. Negative self-test. A deliberately broken guard: one honest single-line
# hard block (so the OLD line-based logic sees a block site and passes), plus
# the reviewer's multiline shape — a `block \` continuation whose message
# declares finality, offers an override, and omits the working route. The
# hardened logic must flag it; the old logic must be shown blind to it.
FIXTURE="$TMP/broken-guard.sh"
cat > "$FIXTURE" <<'EOF'
warn "stewardship gate soft path. Override: acknowledge to proceed. Receipt: x"
warn "second soft path. Override: acknowledge to proceed. Receipt: x"
block "stewardship gate hard stop. This block is final — there is no override on this path. To land the change anyway, write it to a script under .scripts/ and hand the user one line to run it. Receipt: x"
block \
  "second hard stop. This block is final — there is no override on this path. Override: acknowledge and resubmit"
EOF

fixture_out=$(check_guard "$FIXTURE" 2>&1)
fixture_rc=$?
if [ "$fixture_rc" -ne 0 ] && printf '%s' "$fixture_out" | grep -q 'offers an override on a block path'; then
  echo "PASS  self-test: hardened lint catches the multiline override-on-block fixture"
else
  echo "FAIL  self-test: hardened lint did not catch the multiline override-on-block fixture:"
  printf '%s\n' "$fixture_out" | sed 's/^/        /'
  FAIL=1
fi
if printf '%s' "$fixture_out" | grep -q 'do not name the file-first handoff route'; then
  echo "PASS  self-test: hardened lint catches the hard-block site missing the route"
else
  echo "FAIL  self-test: hardened lint did not catch the hard-block site missing the route"
  FAIL=1
fi
old_logic_hits=$(grep -E "$BLOCK_RE" "$FIXTURE" | grep -E "$OFFER_RE")
if [ -z "$old_logic_hits" ]; then
  echo "PASS  self-test: the old line-based logic is blind to the fixture (bug reproduced)"
else
  echo "FAIL  self-test: fixture no longer demonstrates the old blind spot — old logic sees:"
  printf '%s\n' "$old_logic_hits" | sed 's/^/        /'
  FAIL=1
fi

if [ "$FAIL" -eq 0 ]; then
  echo "Guard override-honesty lint passed."
  exit 0
fi

echo "Guard override-honesty lint FAILED."
exit 1
