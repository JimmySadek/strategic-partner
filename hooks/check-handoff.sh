#!/usr/bin/env bash
# Stop hook for strategic-partner
# Checks if a handoff was written during the session.
# Prints a warning if the session ended without preserving state.

HANDOFF_DIR=".handoffs"

# Check if .handoffs/ exists and has any file modified in the last 2 hours
if [ -d "$HANDOFF_DIR" ]; then
  recent=$(find "$HANDOFF_DIR" -name "*.md" -mmin -120 2>/dev/null | head -1)
  if [ -n "$recent" ]; then
    # Handoff was written recently — all good
    exit 0
  fi
fi

# No recent handoff found — warn
echo ""
echo "⚠️  SESSION ENDED WITHOUT HANDOFF"
echo "   No handoff file written in the last 2 hours."
echo "   Session state may be lost. Next time, run:"
echo "   /strategic-partner:handoff"
echo ""
