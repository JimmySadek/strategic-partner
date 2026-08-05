#!/usr/bin/env bash
# lint-report-sanitize.sh — truth-table check for the /report-issue
# deterministic sanitiser (.scripts/report-sanitize.sh, root + plugin copies).
#
# Both directions are load-bearing. Every strip shape must come out replaced
# by its placeholder, AND every preserve shape must pass through byte-for-byte
# untouched — GitHub issue #2 treats over-stripping (guard receipts, git short
# SHAs, version numbers, relative in-plugin paths) as a filter bug, not a
# safety margin, because it guts the report's evidence. A self-test at the end
# builds a deliberately over-stripping variant in this test's own temp dir and
# requires the same table to catch it; a table that cannot flag a broken
# filter proves nothing about the real one.
#
# Conventions match tests/lint-context-path-heuristic.sh: PASS/FAIL per case,
# exit 0/1, temp-dir only, no writes anywhere in the project tree.
#
# FORCE-TRACKED despite `tests/` being gitignored: added with `git add -f`
# (ratified tracking decision, 2026-08-04) so a fresh clone can run it — the
# settled practice for the other contract suites in this directory.
#
# bash 3.2 compatible: indexed arrays only, no associative arrays, no nameref.

HERE=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$HERE/.." && pwd)

FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# --- STRIP cases: the named fragment must vanish, the placeholder must appear.
STRIP_INPUT=(
  "logs at /Users/jane/client-x/src/app.ts"
  "built under /home/pat/work/acme-portal"
  "installed in /opt/acme/tools"
  "config lives at ~/clients/acme/notes.md"
  "contact pat@acme-corp.com for access"
  "dashboard at https://portal.acme-corp.com/admin"
  "the api base is api.acme-corp.io/v2"
  "origin is git@github.com:acme/internal-app.git"
  "mirror at ssh://git@git.acme.com/x/y.git"
  "clone https://gitlab.com/acme/internal.git first"
  "leaked token=abc123def456abc123def456abc123def456 in env"
  "password: hunter2hunter2 was committed"
  "an aws id AKIAIOSFODNN7EXAMPLE was present"
  "session hash 0123456789abcdef0123456789abcdef appeared twice"
  "bearer QmFzZTY0U2VjcmV0VG9rZW4xMjM0NTY3ODkw sent along"
  "lookalike github.com/JimmySadek/strategic-partner-client/private slipped before"
  "lookalike github.com/anthropics-client/private slipped before"
  "lookalike github.com/anthropics.private/client slipped before"
  "spaced /Users/Jane Doe/Client Alpha/private.yml leaked its tail"
  "password: correct horse battery staple"
  "b64 with slash QmFzZTY0/U2VjcmV0VG9rZW4xMjM0NTY3 inline"
  "digit-free blob AbCdEfGhIjKlMnOpQrStUvWxYzAbCdEf appeared"
  "enc1 https://github.com/JimmySadek/strategic-partner%2Dclient/private hidden"
  "enc2 https://github.com/anthropics%2Eprivate/client hidden"
  "pre clientgithub.com/JimmySadek/strategic-partner/private hidden"
  "sub client.github.com/JimmySadek/strategic-partner/private hidden"
  "PaSsWoRd: correct horse battery staple"
  "shout ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEF here"
  "mount /mnt/d/clients/Acme/private.yml leaked"
  "served /srv/Acme/private.yml leaked"
  "windows C:\Clients\Acme\private.yml leaked"
  "bare internal-client.tech/admin surfaced"
)
STRIP_GONE=(
  "/Users/jane"
  "/home/pat"
  "/opt/acme"
  "~/clients"
  "pat@acme-corp.com"
  "portal.acme-corp.com"
  "api.acme-corp.io"
  "acme/internal-app"
  "git.acme.com"
  "gitlab.com/acme"
  "abc123def456"
  "hunter2"
  "AKIAIOSFODNN7EXAMPLE"
  "0123456789abcdef0123456789abcdef"
  "QmFzZTY0"
  "strategic-partner-client"
  "anthropics-client"
  "anthropics.private"
  "Doe"
  "staple"
  "U2VjcmV0"
  "AbCdEfGhIj"
  "%2Dclient"
  "%2Eprivate"
  "clientgithub.com"
  "client.github.com"
  "battery staple"
  "ABCDEFGHIJ"
  "/mnt/d"
  "/srv/Acme"
  "Clients"
  "internal-client.tech"
)
STRIP_WANT=(
  "[path]"
  "[path]"
  "[path]"
  "[path]"
  "[email]"
  "[url]"
  "[url]"
  "[remote]"
  "[remote]"
  "[remote]"
  "[secret]"
  "[secret]"
  "[secret]"
  "[secret]"
  "[secret]"
  "[url]"
  "[url]"
  "[url]"
  "[path]"
  "[secret]"
  "[secret]"
  "[secret]"
  "[url]"
  "[url]"
  "[url]"
  "[url]"
  "[secret]"
  "[secret]"
  "[path]"
  "[path]"
  "[path]"
  "[url]"
)

# --- PRESERVE cases: the whole line must pass through byte-for-byte unchanged.
PRESERVE_INPUT=(
  "guard receipt 216a6fedf72a04db stayed stable"
  "fixed in commit 3e2dcf1 on main"
  "running plugin version 7.8.0 on Darwin"
  "all 27 sanitiser cases passed"
  "the hook hooks/context-file-guard.sh blocked the write"
  "run bash tests/guard-regression.sh after the change"
  "the filter lives at .scripts/report-sanitize.sh"
  "tracker https://github.com/JimmySadek/strategic-partner/issues/2 has the design"
  "see github.com/anthropics/claude-code for the upstream issue"
  "the command /strategic-partner:report-issue ran twice"
  "docs at github.com/JimmySadek/strategic-partner cover the flow"
  "see github.com/anthropics for the vendor account"
  "the_report_sanitize_truth_table_suite ran clean"
  "upstream github.com/anthropics/claude-code/issues/7 stayed linkable"
  "tracker github.com/JimmySadek/strategic-partner/issues/2 stayed linkable"
  "the guard hooks/lib/floor-sentinel.sh line 42 fired first"
)

# Runs the full table against one script. Sets SUITE_FAILS; prints PASS/FAIL
# per case, prefixed with the given label.
run_suite() {
  label="$1"; script="$2"
  SUITE_FAILS=0

  if [ ! -r "$script" ]; then
    echo "FAIL  [$label] $script is missing or unreadable (run from the repo root)"
    SUITE_FAILS=$(( SUITE_FAILS + 1 ))
    return
  fi

  i=0
  while [ "$i" -lt "${#STRIP_INPUT[@]}" ]; do
    input="${STRIP_INPUT[$i]}"; gone="${STRIP_GONE[$i]}"; want="${STRIP_WANT[$i]}"
    out=$(printf '%s\n' "$input" | bash "$script")
    ok=1
    case "$out" in *"$gone"*) ok=0 ;; esac
    case "$out" in *"$want"*) : ;; *) ok=0 ;; esac
    if [ "$ok" -eq 1 ]; then
      echo "PASS  [$label] strip $want: $input"
    else
      echo "FAIL  [$label] expected '$gone' replaced by $want: $input"
      echo "        got: $out"
      SUITE_FAILS=$(( SUITE_FAILS + 1 ))
    fi
    i=$(( i + 1 ))
  done

  i=0
  while [ "$i" -lt "${#PRESERVE_INPUT[@]}" ]; do
    input="${PRESERVE_INPUT[$i]}"
    out=$(printf '%s\n' "$input" | bash "$script")
    if [ "$out" = "$input" ]; then
      echo "PASS  [$label] preserve: $input"
    else
      echo "FAIL  [$label] expected unchanged: $input"
      echo "        got: $out"
      SUITE_FAILS=$(( SUITE_FAILS + 1 ))
    fi
    i=$(( i + 1 ))
  done
}

# --- The real filters: root and plugin copies must both pass everything.
for entry in \
  "root:$PROJECT_ROOT/.scripts/report-sanitize.sh" \
  "plugin:$PROJECT_ROOT/plugin/strategic-partner/.scripts/report-sanitize.sh"
do
  run_suite "${entry%%:*}" "${entry#*:}"
  FAIL=$(( FAIL + SUITE_FAILS ))
done

# --- Self-test: an over-stripping variant (also eats 7-16 char hex, i.e.
# receipts and short SHAs) must be CAUGHT by the preserve rows above. The
# FAIL lines it prints are expected output — they prove the table has teeth.
BROKEN="$TMP/broken-report-sanitize.sh"
{
  printf '#!/usr/bin/env bash\n'
  printf '# deliberately broken: over-strips content-derived short hex\n'
  printf 'bash "%s" | sed -E "s/[0-9a-f]{7,16}/[secret]/g"\n' \
    "$PROJECT_ROOT/.scripts/report-sanitize.sh"
} > "$BROKEN"

echo "--- self-test: FAIL lines below are expected (broken variant must be caught) ---"
run_suite "self-test-broken" "$BROKEN"
if [ "$SUITE_FAILS" -gt 0 ]; then
  echo "PASS  [self-test] truth table caught the over-stripping variant ($SUITE_FAILS case failures)"
else
  echo "FAIL  [self-test] truth table did NOT catch the over-stripping variant"
  FAIL=$(( FAIL + 1 ))
fi

if [ "$FAIL" -eq 0 ]; then
  echo "Report-sanitiser truth-table lint passed."
  exit 0
fi

echo "Report-sanitiser truth-table lint FAILED ($FAIL failure(s))."
exit 1
