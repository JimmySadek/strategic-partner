#!/usr/bin/env bash
# Stop hook for strategic-partner
# Auto-generates a partial handoff from git state when the SP didn't write one.
# A proper SP handoff includes conversation context, decisions, and continuation
# prompt. This auto-handoff captures only what the filesystem knows — but that's
# 80% better than losing everything.

set -euo pipefail

HANDOFF_DIR=".handoffs"

# Check if a proper handoff was already written in the last 2 hours
if [ -d "$HANDOFF_DIR" ]; then
  recent=$(find "$HANDOFF_DIR" -name "*.md" ! -name "auto-*" -mmin -120 2>/dev/null | head -1)
  if [ -n "$recent" ]; then
    # SP wrote a proper handoff — nothing to do
    exit 0
  fi
fi

# No proper handoff found — auto-generate a partial one
mkdir -p "$HANDOFF_DIR"
DATE=$(date +%Y-%m-%d)
SLUG="auto-$(date +%m%d-%H%M)"
FILE="$HANDOFF_DIR/$SLUG.md"

BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
STATUS=$(git status --porcelain 2>/dev/null | head -20 || echo "unable to read")
RECENT=$(git log --oneline -5 2>/dev/null || echo "unable to read")
DIFFSTAT=$(git diff --stat 2>/dev/null | tail -1 || echo "none")
AHEAD=$(git rev-list --count @{upstream}..HEAD 2>/dev/null || echo "?")

cat > "$FILE" << HANDOFF
# Auto-Generated Handoff — $DATE

> **⚠️ This handoff was auto-generated** by the Stop hook because the session
> ended without the SP writing a proper handoff. It contains git state only —
> not conversation context, decisions, or continuation prompt.

## Git State
- **Branch**: $BRANCH
- **Ahead of origin**: $AHEAD commits
- **Uncommitted changes**: $DIFFSTAT

### Recent Commits
\`\`\`
$RECENT
\`\`\`

### Working Tree
\`\`\`
$STATUS
\`\`\`

## What's Missing
- Conversation context and decisions made during the session
- Serena memory updates that should have been written
- Properly scoped continuation prompt
- /insights analysis

## Recovery
The SP can reconstruct partial context from:
1. Git history (commits above show what was done)
2. Serena memories (list_memories → read relevant ones)
3. This file (git state snapshot)

Start a new session with:
\`\`\`
/strategic-partner $FILE
\`\`\`
HANDOFF

echo ""
echo "📝 Auto-handoff saved: $FILE"
echo "   Resume with: /strategic-partner $FILE"
echo ""
