#!/bin/bash
set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
HOOK="$REPO_ROOT/plugin/strategic-partner/hooks/rhythm-check.sh"
FIXTURE_DIR="$SCRIPT_DIR/fixtures/rule11"
CWD_VALUE="/tmp"
MODE="jq"

if [ "${RULE11_PERL_FALLBACK:-0}" = "1" ]; then
  REAL_JQ=$(command -v jq 2>/dev/null || printf '')
  if [ -z "$REAL_JQ" ]; then
    printf 'FAIL perl-fallback setup: real jq unavailable for pre-rule hook parsing\n'
    exit 1
  fi
  FAKE_BIN=$(mktemp -d /tmp/rule11-fake-jq.XXXXXX)
  FAKE_JQ="$FAKE_BIN/jq"
  {
    printf '#!/bin/sh\n'
    printf 'if [ "$1" = "-e" ] && [ "$2" = "type" ]; then exit 1; fi\n'
    printf 'exec "%s" "$@"\n' "$REAL_JQ"
  } > "$FAKE_JQ"
  chmod +x "$FAKE_JQ"
  PATH="$FAKE_BIN:$PATH"
  export PATH
  MODE="perl"
fi

skill_version=$(grep '^version:' "$REPO_ROOT/plugin/strategic-partner/skills/strategic-partner/SKILL.md" 2>/dev/null | head -1 | awk '{print $2}')
[ -z "$skill_version" ] && skill_version="unknown"
rule_schema_version="v1"

log_path_for() {
  sid="$1"
  transcript="$2"
  cwd_hash=$(printf '%s' "$CWD_VALUE" | shasum -a 256 2>/dev/null | cut -d' ' -f1)
  tp_hash=$(printf '%s' "$transcript" | shasum -a 256 2>/dev/null | cut -d' ' -f1)
  key=$(printf '%s|%s|%s|%s|%s' "$sid" "$cwd_hash" "$tp_hash" "$skill_version" "$rule_schema_version" | shasum -a 256 2>/dev/null | cut -d' ' -f1 | head -c 16)
  # Mirrors the hook's own resolution: durable dir, /tmp only as fallback.
  viol_dir="${HOME}/.claude/.sp-rule-violations"
  if mkdir -p "$viol_dir" 2>/dev/null; then
    printf '%s/%s.log' "$viol_dir" "$key"
  else
    printf '/tmp/sp-rule-violations-%s.log' "$key"
  fi
}

run_fixture() {
  fixture="$1"
  expected="$2"
  name=$(basename "$fixture")
  sid="rule11-${MODE}-${name%.*}-$$"
  log_file=$(log_path_for "$sid" "$fixture")
  rm -f "$log_file"

  payload=$(printf '{"transcript_path":"%s","session_id":"%s","cwd":"%s"}' "$fixture" "$sid" "$CWD_VALUE")
  printf '%s' "$payload" | bash "$HOOK" >/tmp/rule11-qvl.out 2>/tmp/rule11-qvl.err
  code=$?

  qvl_count=0
  if [ -f "$log_file" ]; then
    qvl_count=$(grep -c 'question-visible-lead' "$log_file" 2>/dev/null || true)
    [ -z "$qvl_count" ] && qvl_count=0
  fi

  ok=no
  if [ "$code" = "0" ]; then
    case "$expected:$qvl_count" in
      violation:1) ok=yes ;;
      ok:0) ok=yes ;;
    esac
  fi

  if [ "$ok" = "yes" ]; then
    printf 'PASS %s (%s)\n' "$name" "$MODE"
    return 0
  fi

  printf 'FAIL %s (%s): exit=%s expected=%s question-visible-lead-lines=%s\n' "$name" "$MODE" "$code" "$expected" "$qvl_count"
  [ -f /tmp/rule11-qvl.err ] && sed -n '1,5p' /tmp/rule11-qvl.err
  return 1
}

pass=0
total=0

for fixture in "$FIXTURE_DIR"/*.jsonl; do
  total=$((total + 1))
  case "$(basename "$fixture")" in
    F1-*) expected="violation" ;;
    *) expected="ok" ;;
  esac
  if run_fixture "$fixture" "$expected"; then
    pass=$((pass + 1))
  fi
done

printf '%s/%s PASS (%s path)\n' "$pass" "$total" "$MODE"
[ "$pass" = "$total" ]
