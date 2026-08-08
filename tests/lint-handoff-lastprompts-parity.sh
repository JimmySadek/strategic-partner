#!/usr/bin/env bash
# tests/lint-handoff-lastprompts-parity.sh — Release-time fail-closed lint:
# the handoff continuation prompt must be documented as reaching
# .handoffs/last-prompts/, in both the fence discriminator and the
# procedure that writes it.
#
# Why this exists
# ---------------
# SKILL.md's Fenced Prompt Emission Protocol Scope line already claims
# "continuation prompts in handoffs" are written to .handoffs/last-prompts/.
# The fence discriminator's "Handoff continuation" bullet, and
# commands/handoff.md Step 12, both used to omit that requirement — so
# :copy-prompt silently returned a stale, unrelated implementation prompt
# after every :handoff. Reproduced live on 2026-07-29 and 2026-08-04
# (.backlog/fix-handoff-continuation-not-written-to-last-prompts.md). This
# lint checks the fix mechanically so the spec/procedure gap cannot recur
# silently.
#
# The invariant (exact)
# ---------------------
# In each of SKILL.md and plugin/strategic-partner/skills/strategic-partner/SKILL.md:
#   the "Handoff continuation" discriminator bullet line must mention
#   "last-prompts".
# In each of commands/handoff.md and plugin/strategic-partner/commands/handoff.md:
#   Step 12 ("Write the Continuation Prompt") must mention "last-prompts"
#   before Step 13 begins.
#
# Fail-closed posture
# -------------------
# Any of these conditions exits non-zero (release-blocking):
#   - a covered file is missing or unreadable
#   - the "Handoff continuation" bullet is missing, or doesn't mention
#     last-prompts
#   - Step 12 is missing, or its body (up to Step 13) doesn't mention
#     last-prompts
#
# bash 3.2 compatible (macOS): no associative arrays, no mapfile, no nameref.
#
# Usage: bash tests/lint-handoff-lastprompts-parity.sh
# Exit 0 = both root and plugin copies documented consistently.
# Exit 1 = at least one covered file fails the check.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0

check_discriminator_bullet() {
  # $1 = file
  f="$1"
  if [ ! -r "$f" ]; then
    echo "FAIL  $f — not found or unreadable"
    FAIL=1
    return
  fi
  line=$(grep -n 'Handoff continuation' "$f" | head -1)
  if [ -z "$line" ]; then
    echo "FAIL  $f — no 'Handoff continuation' discriminator bullet found"
    FAIL=1
    return
  fi
  if ! printf '%s' "$line" | grep -q 'last-prompts'; then
    echo "FAIL  $f:${line%%:*} — Handoff continuation bullet does not mention last-prompts"
    FAIL=1
    return
  fi
  echo "PASS  $f — Handoff continuation bullet requires the last-prompts write"
}

check_step12() {
  # $1 = file
  f="$1"
  if [ ! -r "$f" ]; then
    echo "FAIL  $f — not found or unreadable"
    FAIL=1
    return
  fi
  step12_body=$(awk '/^### Step 12 /{flag=1; next} /^### Step 13 /{flag=0} flag' "$f")
  if [ -z "$step12_body" ]; then
    echo "FAIL  $f — Step 12 (Write the Continuation Prompt) section not found"
    FAIL=1
    return
  fi
  if ! printf '%s' "$step12_body" | grep -q 'last-prompts'; then
    echo "FAIL  $f — Step 12 does not mention writing to last-prompts before Step 13"
    FAIL=1
    return
  fi
  echo "PASS  $f — Step 12 writes the continuation prompt to last-prompts before Step 13"
}

check_discriminator_bullet "$ROOT/SKILL.md"
check_discriminator_bullet "$ROOT/plugin/strategic-partner/skills/strategic-partner/SKILL.md"
check_step12 "$ROOT/commands/handoff.md"
check_step12 "$ROOT/plugin/strategic-partner/commands/handoff.md"

if [ "$FAIL" -eq 0 ]; then
  echo "Handoff last-prompts parity lint: OK — discriminator and procedure agree in both root and plugin copies."
  exit 0
fi
echo "Handoff last-prompts parity lint: FAILED."
exit 1
