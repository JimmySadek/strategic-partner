#!/usr/bin/env bash
# Regression test for the floor sentinel's tri-state version field (g6.diff).
# Guards against .backlog/fix-floor-sentinel-version-label-tristate.md: a
# local version AHEAD of the latest published release was mislabeled as
# "behind", producing a false "update available" notice.

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PASS=0
FAIL=0

record_pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
record_fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

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

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
