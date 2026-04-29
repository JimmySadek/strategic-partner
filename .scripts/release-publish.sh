#!/bin/bash
# ============================================================
# Strategic Partner — Release Publish (Step 7 of release runbook)
#
# Creates a GitHub Release for the named version and extracts the
# matching CHANGELOG.md entry as release notes. Replaces the inline
# awk command previously documented in CLAUDE.md Step 7 — same
# behavior, harder error handling, simpler invocation.
#
# Usage:
#   .scripts/release-publish.sh <version> <one-line-summary>
#
# Example:
#   .scripts/release-publish.sh 5.14.1 "lint fixes + SP self-migration"
#
# Prerequisites:
#   - gh CLI installed and authenticated
#   - Git tag vX.Y.Z already pushed to remote (Step 6 of release runbook)
#   - CHANGELOG.md contains a matching ## [X.Y.Z] - YYYY-MM-DD section
# ============================================================
set -euo pipefail

# --------------------------------------------------
# Pre-flight checks
# --------------------------------------------------
if ! command -v gh >/dev/null 2>&1; then
  echo "Error: gh CLI not found. Install via 'brew install gh' or see https://cli.github.com/" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Error: gh CLI not authenticated. Run 'gh auth login' first." >&2
  exit 1
fi

if [ ! -f "CHANGELOG.md" ]; then
  echo "Error: CHANGELOG.md not found in current directory ($(pwd))." >&2
  echo "Run this script from the repo root." >&2
  exit 1
fi

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <version> <one-line-summary>" >&2
  echo "Example: $0 5.14.1 'lint fixes + SP self-migration'" >&2
  exit 1
fi

VERSION="$1"
SUMMARY="$2"
TAG="v${VERSION}"

# Verify the tag exists locally (must have been created and pushed in Step 6)
if ! git rev-parse --verify "${TAG}" >/dev/null 2>&1; then
  echo "Error: tag ${TAG} not found locally. Run Step 6 first (commit, tag, push)." >&2
  exit 1
fi

# --------------------------------------------------
# 1/2  Extract the CHANGELOG entry for this version
# --------------------------------------------------
echo "1/2  Extracting CHANGELOG entry for ${VERSION}..."

# awk: find a line starting with "## [<version>]", then print everything until the next "## [" line
NOTES=$(awk -v ver="${VERSION}" '
  $0 ~ "^## \\["ver"\\]" { found=1; next }
  found && /^## \[/ { exit }
  found { print }
' CHANGELOG.md)

if [ -z "${NOTES}" ]; then
  echo "  ⚠️  Warning: no CHANGELOG entry found for version ${VERSION}." >&2
  echo "  The release will be created with empty notes. Fix CHANGELOG.md and re-run if needed." >&2
else
  echo "  ✅ Extracted $(printf '%s' "${NOTES}" | wc -l | tr -d ' ') lines of release notes"
fi

# --------------------------------------------------
# 2/2  Create the GitHub Release
# --------------------------------------------------
echo "2/2  Creating GitHub Release ${TAG}..."
gh release create "${TAG}" --title "${TAG} — ${SUMMARY}" --notes "${NOTES}"

# --------------------------------------------------
# Done
# --------------------------------------------------
echo ""
echo "============================================================"
echo "✅  Release ${TAG} published"
echo "============================================================"
echo ""
echo "Verify at: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/releases/tag/${TAG}"
