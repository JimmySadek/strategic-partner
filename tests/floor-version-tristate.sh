#!/usr/bin/env bash
# Regression test for the floor sentinel's tri-state version field (g6.diff).
# Guards against .backlog/fix-floor-sentinel-version-label-tristate.md: a
# local version AHEAD of the latest published release was mislabeled as
# "behind", producing a false "update available" notice.

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PASS=0
FAIL=0
SKIP=0

record_pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
record_fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }
record_skip() { SKIP=$((SKIP + 1)); printf 'SKIP: %s\n' "$1"; }

assert_contains() {
  name="$1"
  actual="$2"
  expected="$3"
  if printf '%s' "$actual" | grep -F "$expected" >/dev/null; then
    record_pass "$name"
  else
    record_fail "$name (missing: $expected)"
  fi
}

# Stubs `curl` to return a crafted GitHub "latest release" response so the
# hook's remote-version lookup is deterministic regardless of network state.
curl() {
  printf '{"tag_name": "v%s"}' "$__SP_TEST_REMOTE"
}
export -f curl

run_floor() {
  script="$1"
  sid="$2"
  remote="$3"
  __SP_TEST_REMOTE="$remote"
  export __SP_TEST_REMOTE
  payload=$(jq -cn --arg sid "$sid" --arg cwd "$ROOT" \
    '{session_id:$sid,cwd:$cwd,prompt:"/strategic-partner"}')
  printf '%s' "$payload" | bash "$script" 2>&1
}

for target in "hooks/floor-check.sh:root" "plugin/strategic-partner/hooks/floor-check.sh:plugin"; do
  script_rel="${target%%:*}"
  label="${target##*:}"
  script="$ROOT/$script_rel"

  if [ "$label" = "plugin" ]; then
    skill_path="$ROOT/plugin/strategic-partner/skills/strategic-partner/SKILL.md"
  else
    skill_path="$ROOT/SKILL.md"
  fi
  local_version=$(grep '^version:' "$skill_path" 2>/dev/null | head -1 | awk '{print $2}')

  out=$(run_floor "$script" "test-version-current-$label-$$" "$local_version")
  assert_contains "$label: current (remote == local)" "$out" "version=current"

  out=$(run_floor "$script" "test-version-ahead-$label-$$" "0.0.1")
  assert_contains "$label: ahead (remote < local)" "$out" "version=ahead"

  out=$(run_floor "$script" "test-version-behind-$label-$$" "999.0.0")
  assert_contains "$label: behind (remote > local)" "$out" "version=behind"
done

# --- Truth table for the independent-component comparison ------------------
#
# The three cases above stub only the remote side, because the hook reads its
# local version from the SKILL.md beside itself. Driving the LOCAL side too
# needs a staged install tree: a copy of the hook plus a crafted SKILL.md at
# the layout that hook expects. Root layout puts SKILL.md at the install root;
# plugin layout puts it under skills/strategic-partner/.
#
# HOME is redirected into the stage so the root hook's command-symlink
# fallback cannot reach the real install and substitute the real version —
# that fallback is what would otherwise make the empty-local row unstable.
run_floor_staged() {
  script_rel="$1"
  label="$2"
  sid="$3"
  local_v="$4"
  remote="$5"

  stage=$(mktemp -d)
  mkdir -p "$stage/hooks" "$stage/home/.claude"
  cp "$ROOT/$script_rel" "$stage/hooks/floor-check.sh"

  if [ "$label" = "plugin" ]; then
    skill_dir="$stage/skills/strategic-partner"
  else
    skill_dir="$stage"
  fi
  mkdir -p "$skill_dir"
  if [ -n "$local_v" ]; then
    printf 'name: strategic-partner\nversion: %s\n' "$local_v" > "$skill_dir/SKILL.md"
  else
    # No version field at all — the empty-local row.
    printf 'name: strategic-partner\n' > "$skill_dir/SKILL.md"
  fi

  __SP_TEST_REMOTE="$remote"
  export __SP_TEST_REMOTE
  payload=$(jq -cn --arg sid "$sid" --arg cwd "$ROOT" \
    '{session_id:$sid,cwd:$cwd,prompt:"/strategic-partner"}')
  staged_out=$(printf '%s' "$payload" | HOME="$stage/home" bash "$stage/hooks/floor-check.sh" 2>&1)
  rm -rf "$stage"
  printf '%s' "$staged_out"
}

# Each row: local|remote|expected. Empty fields are intentional (empty version).
# A malformed version on either side must produce "unknown", never "behind" —
# reporting behind on unparseable input is the false-update-notice bug.
for target in "hooks/floor-check.sh:root" "plugin/strategic-partner/hooks/floor-check.sh:plugin"; do
  script_rel="${target%%:*}"
  label="${target##*:}"
  row=0

  while IFS='|' read -r lv rv want; do
    [ -n "$want" ] || continue
    row=$((row + 1))
    out=$(run_floor_staged "$script_rel" "$label" "test-version-row$row-$label-$$" "$lv" "$rv")
    assert_contains "$label: ${lv:-(empty)} vs ${rv:-(empty)} -> $want" "$out" "version=$want"
  done <<'ROWS'
7.6.0|7.6.0|current
7.6.1|7.6.0|ahead
7.6.0|7.6.1|behind
2.0.0|1.1000.0|ahead
1.1000.0|2.0.0|behind
0.0.1|0.0.0|ahead
10.0.0|9.99.99|ahead
7.6.1|7.6.1-beta|unknown
7.6.1-beta|7.6.1|unknown
08.0.0|7.6.0|unknown
7.6.1.4|7.6.0|unknown
1.2|1.2.0|unknown
x.2.3|7.6.0|unknown
|7.6.0|unknown
7.6.0||unknown
999999999999999999999999999999.0.0|1.1.0|ahead
1.999999999999999999999999999999.0|1.1.1|ahead
999999999999999999999999999999.0.0|1.0.0|ahead
1.1.0|999999999999999999999999999999.0.0|behind
999999999999999999999999999999.0.0|999999999999999999999999999999.0.0|current
1.0.0|1.0.0000000000000000000000000001|unknown
ROWS
done

# --- Locale rows: validation must not admit non-ASCII digits ----------------
#
# Bash matches a digit range by collation, not by codepoint. Under a locale
# whose digit range runs wider than ASCII, an unpinned [0-9] test accepts
# characters the comparator cannot rank; they reached a byte comparison and
# reported 9.0.0 as "behind" ٢.0.0. Every mixed row below must answer
# "unknown": if the characters are invalid the answer is unknown, and if their
# numeric value were honoured nine still beats two, so "behind" is wrong under
# either reading.
#
# These rows run the comparator under a NON-C locale on purpose. Run under C
# they would have passed before the fix as well as after it, and would prove
# nothing. The ASCII rows repeat known-good answers under the same wide locale,
# so a pin that silenced the defect by breaking ordinary comparison would fail
# here rather than look like a fix.

# Returns the first installed locale that genuinely widens the digit range.
# Presence in `locale -a` is not enough — a locale can be installed and still
# collate like C, and rows run under such a locale would pass without
# exercising anything.
pick_wide_digit_locale() {
  cand=""
  for cand in fa_IR.UTF-8 ar_SA.UTF-8 fa_IR ar_SA ar_AE.UTF-8; do
    locale -a 2>/dev/null | grep -qx "$cand" || continue
    admits=$(LC_ALL="$cand" bash -c 'case "٢" in *[!0-9]*) printf no ;; *) printf yes ;; esac' 2>/dev/null)
    if [ "$admits" = "yes" ]; then
      printf '%s' "$cand"
      return 0
    fi
  done
  return 1
}

WIDE_LOCALE=$(pick_wide_digit_locale) || WIDE_LOCALE=""

for target in "hooks/floor-check.sh:root" "plugin/strategic-partner/hooks/floor-check.sh:plugin"; do
  script_rel="${target%%:*}"
  label="${target##*:}"

  if [ -z "$WIDE_LOCALE" ]; then
    record_skip "$label: locale rows — no installed locale widens the digit range on this machine (tried fa_IR.UTF-8, ar_SA.UTF-8, fa_IR, ar_SA, ar_AE.UTF-8)"
    continue
  fi

  # Drive the marked region directly. The rows need the comparator under a
  # chosen locale, and the region is the unit that owns the pin.
  probe=$(mktemp -t sp-locale-probe.XXXXXX)
  awk '/^# sp-comparator-region: begin$/{f=1} /^# sp-comparator-region: end$/{print; f=0} f' \
    "$ROOT/$script_rel" > "$probe"
  printf 'sp_version_diff "$1" "$2"\n' >> "$probe"

  while IFS='|' read -r lv rv want; do
    [ -n "$want" ] || continue
    got=$(LC_ALL="$WIDE_LOCALE" bash "$probe" "$lv" "$rv" 2>&1)
    if [ "$got" = "$want" ]; then
      record_pass "$label [$WIDE_LOCALE]: $lv vs $rv -> $want"
    else
      record_fail "$label [$WIDE_LOCALE]: $lv vs $rv -> expected $want, got ${got:-(empty)}"
    fi
  done <<'ROWS'
9.0.0|٢.0.0|unknown
١.٢.٣|١.٢.٣|unknown
٢.0.0|9.0.0|unknown
٩.٠.٠|1.0.0|unknown
7.6.٠|7.6.0|unknown
7.6.0|7.6.0|current
7.6.1|7.6.0|ahead
7.6.0|7.6.1|behind
10.0.0|9.99.99|ahead
ROWS

  rm -f "$probe"
done

# --- Structural: no version component is ever read as a number --------------
#
# The rows above prove today's answers. This proves the property that keeps
# them true. Both failure modes this suite exists for came from converting a
# component to a number: first a packed integer whose multiplier acted as a
# radix, then a per-component numeric test that errored on a long component
# and let control fall through to the next one. A length cap would have left
# that class in place; removing the conversion removes it.
#
# Length comparisons (${#...}) are the one permitted numeric test — they read
# how long a string is, never what number it holds, and they are what makes
# the string comparison correct. Anything else numeric fails this check.
# Scoped to the marked comparator region, so arithmetic elsewhere in the hook
# is none of this assertion's business.
assert_no_component_arithmetic() {
  label="$1"
  script="$2"
  region=$(awk '/^# sp-comparator-region: begin$/{f=1} /^# sp-comparator-region: end$/{print; f=0} f' "$script")
  if [ -z "$region" ]; then
    record_fail "$label: comparator region markers missing from $script"
    return
  fi

  offenders=""
  while IFS= read -r line; do
    if printf '%s' "$line" | grep -qE '\$\(\(' ; then
      offenders="${offenders}    ${line}
"
      continue
    fi
    ops=$(printf '%s' "$line" | grep -oE '[[:space:]]-(eq|ne|gt|lt|ge|le)[[:space:]]' | wc -l | tr -d ' ')
    safe=$(printf '%s' "$line" | grep -oE '"\$\{#[^}]*\}"[[:space:]]-(eq|ne|gt|lt|ge|le)[[:space:]]"\$\{#[^}]*\}"' | wc -l | tr -d ' ')
    if [ "$ops" != "$safe" ]; then
      offenders="${offenders}    ${line}
"
    fi
  done <<EOF
$region
EOF

  if [ -n "$offenders" ]; then
    record_fail "$label: comparator region reads a version component as a number:
$offenders"
  else
    record_pass "$label: comparator region converts no version component to a number"
  fi
}

assert_no_component_arithmetic "root" "$ROOT/hooks/floor-check.sh"
assert_no_component_arithmetic "plugin" "$ROOT/plugin/strategic-partner/hooks/floor-check.sh"

# --- A pin that cannot be applied answers "unknown" -------------------------
#
# `local LC_ALL=C` is an assignment, and an assignment can be refused. A caller
# that exports LC_ALL and marks it readonly makes the declaration fail: bash
# prints a diagnostic, the function CARRIES ON, and validation runs under the
# caller's locale — which is exactly the hole the pin was added to close,
# reopened without a trace. The comparator must fail closed instead.
#
# Unlike the wide-locale rows above, this needs no particular locale installed,
# so it runs on every machine rather than skipping. Two rows: the refused pin
# must answer "unknown", and the identical comparison with the pin allowed must
# still answer "ahead" — otherwise a comparator that answered "unknown" to
# everything would look like a fix.
for target in "hooks/floor-check.sh:root" "plugin/strategic-partner/hooks/floor-check.sh:plugin"; do
  script_rel="${target%%:*}"
  label="${target##*:}"

  # Region only, with no trailing call line: this row sources it into a shell
  # that has already marked LC_ALL readonly, then calls the entry point there.
  region_probe=$(mktemp -t sp-readonly-probe.XXXXXX)
  awk '/^# sp-comparator-region: begin$/{f=1} /^# sp-comparator-region: end$/{print; f=0} f' \
    "$ROOT/$script_rel" > "$region_probe"

  got=$(LC_ALL=C bash -c 'readonly LC_ALL; . "$1"; sp_version_diff "$2" "$3"' \
    bash "$region_probe" "7.6.1" "7.6.0" 2>&1)
  if [ "$got" = "unknown" ]; then
    record_pass "$label: readonly LC_ALL (pin refused) -> unknown"
  else
    record_fail "$label: readonly LC_ALL (pin refused) -> expected unknown, got ${got:-(empty)}"
  fi

  got=$(LC_ALL=C bash -c '. "$1"; sp_version_diff "$2" "$3"' \
    bash "$region_probe" "7.6.1" "7.6.0" 2>&1)
  if [ "$got" = "ahead" ]; then
    record_pass "$label: writable LC_ALL (pin applied) -> ahead"
  else
    record_fail "$label: writable LC_ALL (pin applied) -> expected ahead, got ${got:-(empty)}"
  fi

  rm -f "$region_probe"
done

# --- Structural: the locale is pinned before anything is validated ----------
#
# The rows above prove today's answers on this machine's locales. This proves
# the property that keeps them true anywhere. The defect was not that the
# comparator ignored the locale — it pinned C for its ordering step — but that
# it validated first, under whatever the caller had set. Validation is the gate
# a wide digit range walks through, so the pin has to come before it.
#
# Asserted as "first statement of every function in the region", not "appears
# somewhere in the region": the old code contained the pin and was still wrong,
# because of where it sat. Requiring it first is what encodes the ordering.
# A region with no functions fails rather than passing vacuously.
#
# The required form is the GUARDED pin — `local LC_ALL=C 2>/dev/null || ...` —
# not the bare assignment. A bare pin is refused silently when LC_ALL is
# exported readonly and the function proceeds unpinned, so requiring only
# `local LC_ALL=C` would accept the very shape the row above exists to catch.
assert_locale_pinned_first() {
  label="$1"
  script="$2"
  region=$(awk '/^# sp-comparator-region: begin$/{f=1} /^# sp-comparator-region: end$/{print; f=0} f' "$script")
  if [ -z "$region" ]; then
    record_fail "$label: comparator region markers missing from $script"
    return
  fi

  fn=""
  checked=0
  offenders=""
  while IFS= read -r line; do
    case "$line" in
      *'() {')
        fn=$(printf '%s' "$line" | sed 's/().*//')
        continue
        ;;
    esac
    [ -n "$fn" ] || continue
    trimmed=$(printf '%s' "$line" | sed 's/^[[:space:]]*//')
    # Comments and blank lines are not statements — keep looking.
    case "$trimmed" in
      '' | '#'*) continue ;;
    esac
    checked=$((checked + 1))
    case "$trimmed" in
      'local LC_ALL=C 2>/dev/null || '*) : ;;
      *)
        offenders="${offenders}    ${fn}: first statement is '${trimmed}'
"
        ;;
    esac
    fn=""
  done <<EOF
$region
EOF

  if [ "$checked" -eq 0 ]; then
    record_fail "$label: comparator region declares no functions — nothing was checked"
  elif [ -n "$offenders" ]; then
    record_fail "$label: comparator region validates before pinning the locale, or pins without guarding:
$offenders"
  else
    record_pass "$label: comparator region pins LC_ALL=C, guarded, before it validates ($checked functions)"
  fi
}

assert_locale_pinned_first "root" "$ROOT/hooks/floor-check.sh"
assert_locale_pinned_first "plugin" "$ROOT/plugin/strategic-partner/hooks/floor-check.sh"

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
