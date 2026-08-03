#!/usr/bin/env bash
# opening-parity-contract.sh — contract for the v8.0 opening path.
#
# Two properties, checked mechanically across BOTH packagings (root skill tree
# and plugin/strategic-partner/...):
#
#   1. ORDER — every entry form prescribes signal line -> one read batch ->
#      rendered briefing -> on-demand verification -> optional question, and
#      forbids re-deriving what the floor sentinel already computed.
#   2. PARITY — the light entry form (`status` recenter) and the full entry
#      form (startup opening checklist) source the SAME facts, from the same
#      floor results file, so the two surfaces cannot drift into briefing the
#      user about different things for the same session state.
#
# [⚠️ RISK] What this fixture does NOT prove. The order checks are literal-string
# anchors and the parity checks are vocabulary-level: they prove each surface
# still NAMES the same fact, not that the two render it identically. Renaming a
# briefing row while keeping the word ("Git" -> "GitX") passes. Treat a clean
# run as "no step and no fact went missing from one surface," never as "the two
# surfaces are equivalent."
#
# Usage:  bash tests/opening-parity-contract.sh
# Exit 0 = contract holds. Exit 1 = at least one assertion failed.
#
# bash 3.2 compatible (macOS): no associative arrays, no mapfile, no nameref.

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

# has <label> <file> <literal>
has() {
  if [ ! -r "$2" ]; then
    fail "$1 (unreadable file: $2)"
    return
  fi
  if grep -qF "$3" "$2"; then
    pass "$1"
  else
    fail "$1 (missing from $(basename "$2"): $3)"
  fi
}

# lacks <label> <file> <literal>
lacks() {
  if [ ! -r "$2" ]; then
    fail "$1 (unreadable file: $2)"
    return
  fi
  if grep -qF "$3" "$2"; then
    fail "$1 (still present in $(basename "$2"): $3)"
  else
    pass "$1"
  fi
}

# has_i <label> <file> <case-insensitive pattern>
has_i() {
  if [ ! -r "$2" ]; then
    fail "$1 (unreadable file: $2)"
    return
  fi
  if grep -qiE "$3" "$2"; then
    pass "$1"
  else
    fail "$1 (missing from $(basename "$2"): $3)"
  fi
}

SKILL_ROOT="$ROOT/SKILL.md"
SKILL_PLUGIN="$ROOT/plugin/strategic-partner/skills/strategic-partner/SKILL.md"
LIST_ROOT="$ROOT/references/startup-checklist.md"
LIST_PLUGIN="$ROOT/plugin/strategic-partner/skills/strategic-partner/references/startup-checklist.md"
STATUS_ROOT="$ROOT/commands/status.md"
STATUS_PLUGIN="$ROOT/plugin/strategic-partner/commands/status.md"
SIGNALS_ROOT="$ROOT/references/floor-signal-handling.md"
SIGNALS_PLUGIN="$ROOT/plugin/strategic-partner/skills/strategic-partner/references/floor-signal-handling.md"

# ---------------------------------------------------------------------------
# 1. ORDER — the opening checklist, both trees
# ---------------------------------------------------------------------------
for f in "$LIST_ROOT" "$LIST_PLUGIN"; do
  tag="checklist($(printf '%s' "$f" | grep -q '/plugin/' && echo plugin || echo root))"
  has "$tag names the opening sequence"            "$f" "## 🧭 The Opening Sequence"
  has "$tag Step 1 is the signal line"             "$f" "## 📣 Step 1: Signal Line — Before Any Tool Call"
  has "$tag Step 2 is one parallel batch"          "$f" "## 📥 Step 2: One Parallel Read Batch"
  has "$tag Step 3 renders the briefing"           "$f" "## 📋 Step 3: Render the Briefing"
  has "$tag Step 4 verifies on demand"             "$f" "## 🔍 Step 4: Verify on Demand"
  has "$tag Step 5 closes the opening"             "$f" "## 🙋 Step 5: Close the Opening"
  has "$tag forbids re-deriving the floor"         "$f" "Never re-derive the floor"
  has "$tag makes render-before-ask absolute"      "$f" "Render-before-ask is absolute"
  has "$tag caps the opening at nine calls"        "$f" "at most nine tool calls"
  has "$tag bars sub-agent substitution"           "$f" "relocation, not removal"
  has "$tag cites the harness text-drop hazard"    "$f" "#75034"
  has "$tag keeps the honesty constraint"          "$f" "⏳ checking…"
  # the old ordering must be gone: orientation no longer runs last
  lacks "$tag no longer orients after verification" "$f" "Compile results from Steps 3-4"
  lacks "$tag has no Step 1.5"                      "$f" "## 🔧 Step 1.5"
done

# ---------------------------------------------------------------------------
# 2. ORDER — SKILL.md body, both trees
# ---------------------------------------------------------------------------
for f in "$SKILL_ROOT" "$SKILL_PLUGIN"; do
  tag="SKILL($(printf '%s' "$f" | grep -q '/plugin/' && echo plugin || echo root))"
  has "$tag binds the opening order in every entry form" "$f" "### 🧭 Opening Order (binding in every entry form)"
  has "$tag orders the signal line first"                "$f" "Signal line first"
  has "$tag orders one batch, not a probe sequence"      "$f" "One batch, not a probe sequence"
  has "$tag orders render before ask"                    "$f" "Render before ask"
  has "$tag orders verify on demand"                     "$f" "Verify on demand, honestly"
  has "$tag requires a context echo on the closing ask"  "$f" "compact context echo"
  has "$tag forbids re-deriving the floor"               "$f" "Never re-derive the floor"
  has "$tag caps the opening at nine calls"              "$f" "at most nine tool calls"
done

# ---------------------------------------------------------------------------
# 3. ORDER — the status recenter, both trees
# ---------------------------------------------------------------------------
for f in "$STATUS_ROOT" "$STATUS_PLUGIN"; do
  tag="status($(printf '%s' "$f" | grep -q '/plugin/' && echo plugin || echo root))"
  has "$tag emits a signal line before any tool call" "$f" "### Step 0 — Signal Line (before any tool call)"
  has "$tag gathers in one parallel batch"            "$f" "### Step 1 — Gather State (one parallel batch)"
  has "$tag defers deeper reads past the briefing"    "$f" "### Step 2a — Deeper Reads, After the Briefing"
  has "$tag shows the briefing before asking"         "$f" "### Step 3 — Show The Briefing, Then Ask"
  has "$tag keeps the compact context echo"           "$f" "compact context echo"
  has "$tag forbids re-deriving the floor"            "$f" "**Never re-derive the floor**"
  has "$tag keeps the honesty constraint"             "$f" "⏳ checking…"
  # the removed per-source probe rows must not come back
  lacks "$tag no longer probes git status directly"   "$f" "| \`git status\` | Current branch"
  lacks "$tag no longer probes git log directly"      "$f" "| \`git log --oneline -5\` |"
  lacks "$tag no longer reads CLAUDE.md to recenter"  "$f" "| \`CLAUDE.md\` | Current conventions"
  lacks "$tag drops the stale Step 2a startup pointer" "$f" "| Aspect | Startup Step 2a | This Command |"
done

# ---------------------------------------------------------------------------
# 4. PARITY — light entry and full entry source the same facts
#
# Each fact must be named on BOTH surfaces. A fact that only one surface knows
# about is exactly the drift this fixture exists to catch.
# ---------------------------------------------------------------------------
parity_fact() {
  label=$1
  pattern=$2
  has_i "parity: full entry names $label"  "$LIST_ROOT"   "$pattern"
  has_i "parity: light entry names $label" "$STATUS_ROOT" "$pattern"
}

parity_fact "the floor results file"   'sp-floor-<KEY>\.txt'
parity_fact "the floor summary line"   'SP-FLOOR-COMPLETE'
parity_fact "git branch and tree state" 'branch'
parity_fact "project-rules size band"  'band'
parity_fact "memory presence"          'memory'
parity_fact "routing freshness"        'routing freshness'
parity_fact "version difference"       'version'
parity_fact "output style"             'output style'
parity_fact "backlog"                  'backlog'
parity_fact "findings"                 'findings'

# The plugin twins must carry the same parity vocabulary as their root files.
for pair in "$LIST_ROOT:$LIST_PLUGIN" "$STATUS_ROOT:$STATUS_PLUGIN"; do
  a=${pair%%:*}
  b=${pair##*:}
  name=$(basename "$a")
  has_i "twin parity: $name plugin twin names the floor results file" "$b" 'sp-floor-<KEY>\.txt'
  has_i "twin parity: $name plugin twin names the floor summary line" "$b" 'SP-FLOOR-COMPLETE'
done

# ---------------------------------------------------------------------------
# 5. The per-field verification-class map exists in both trees
# ---------------------------------------------------------------------------
for f in "$SIGNALS_ROOT" "$SIGNALS_PLUGIN"; do
  tag="signals($(printf '%s' "$f" | grep -q '/plugin/' && echo plugin || echo root))"
  has "$tag maps each floor field to a verification class" "$f" "## 🔍 Verification Classes"
  has "$tag keeps Class A free of tool calls"              "$f" "Class A — floor-verified"
  has "$tag defers Class C past the briefing"              "$f" "runs after the briefing has rendered"
  has "$tag keeps the honesty constraint"                  "$f" "⏳ checking…"
done

printf '\nResult: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
