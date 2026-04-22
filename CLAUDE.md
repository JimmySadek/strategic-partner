# Strategic Partner — Project Rules

## Release Process (Mandatory Before Push)

Every push to remote MUST go through this process.

**Exception — docs-only pushes:** If ALL commits since last push are documentation-only
(README, CLAUDE.md, comments, internal references — no functional changes to SKILL.md
behavior, hooks, commands, or references that affect runtime), the push may skip version
bump, tag, and GitHub Release. Users receive the fixes silently on next update.
This avoids notification noise for trivial changes.

### 1. Fetch & Compare

```
git fetch origin
git log origin/main..HEAD --oneline    # commits to push
git log HEAD..origin/main --oneline    # commits we're missing
git diff origin/main..HEAD --stat      # files changed
```

### 2. Classify the Bump

| Change Type | Bump | Examples |
|---|---|---|
| Fixes, behavioral tweaks, docs-only | **patch** (X.Y.Z+1) | Bug fixes, wording changes, rule additions |
| New features, new capabilities | **minor** (X.Y+1.0) | New subcommand, new reference file, new protocol |
| Breaking changes, restructures | **major** (X+1.0.0) | SKILL.md rewrite, removed features, changed API |

### 2a. Hook Verification (if release touches hooks)

If the release modifies hook logic (frontmatter `hooks:` section or `hooks/` files):

1. **Test matcher scope**: verify the hook fires ONLY on intended tools, not on Read/Grep/Glob/etc.
2. **Test guard logic**: pipe sample JSON through the reference script and verify allow/block decisions:
   ```
   echo '{"tool_name":"Edit","tool_input":{"file_path":"/foo/bar.py"}}' | bash hooks/guard-impl.sh
   echo $?  # should be 2 (blocked)

   echo '{"tool_name":"Edit","tool_input":{"file_path":"/foo/.prompts/test.md"}}' | bash hooks/guard-impl.sh
   echo $?  # should be 0 (allowed)
   ```
3. **Test from a non-default path**: verify no hardcoded paths or undefined variables.
4. **Runtime-input fuzzing** (for hooks parsing JSON or env vars): vary
   whitespace in keys/values, quoting styles, missing optional fields, and
   non-JSON input. Pipe each through the reference script and confirm
   graceful handling (allow or block, not abort-on-error):
   ```
   echo '{ "tool_name" : "Edit" , "tool_input" : { "file_path" : "/foo/bar.py" } }' | bash hooks/guard-impl.sh
   echo '{"tool_name":"Edit"}' | bash hooks/guard-impl.sh
   echo 'not json at all' | bash hooks/guard-impl.sh
   ```
   The executor's own test set represents what the AUTHOR thought about; fuzzing
   represents what the RUNTIME will actually send.

5. **CHANGELOG cross-reference**: before endorsing any hook command that uses
   `${CLAUDE_*}` env vars or a specific path-resolution pattern, grep
   CHANGELOG.md for that variable or pattern. Prior release notes are
   authoritative on "what doesn't work in this harness." Example:
   ```
   grep -n 'CLAUDE_SKILL_DIR' CHANGELOG.md
   ```
   A historical entry explaining why the pattern failed before is the fastest
   way to avoid re-introducing the same bug.

**Why**: Hook bugs are session-breaking — exit-code-2 blocks on every tool call. v5.4.0→v5.4.1 was a reactive fix for exactly this class of bug.

### 2b. Codex Pre-Release Review (Mandatory for non-docs-only pushes)

Before any non-docs-only push, run an adversarial review via
`/strategic-partner:codex-feedback` in Evidence Audit mode (Mode B)
asking three questions:

1. **Diff matches CHANGELOG** — does the proposed CHANGELOG entry
   accurately describe the full `previous_tag..HEAD` delta? Any
   undocumented changes?
2. **No regressions vs last released version** — do all invariants
   from the prior release still hold? Specifically check hook path
   patterns, allow-list semantics, and setup behavior on
   macOS/Linux/WSL.
3. **Release worthiness from a user point of view** — is this a
   meaningful/welcomed update for the public? Does it improve,
   not-impact, or degrade experience for each supported user segment
   (macOS/Linux, Windows WSL, prospective users)? Would the CHANGELOG
   entry read as meaningful or as noise?

**Verdict handling:**
- **GO** — push approved
- **CONDITIONAL GO** — address the conditions, then re-run the
  audit. Push only after conditions are met (fixes committed;
  re-audit returns GO or reduced CONDITIONAL with only release-bump
  steps remaining)
- **NO-GO** — fix the release, then re-run

**Skip only for:**
- Docs-only pushes (covered by the docs-only exception above)
- Single-line bug fix patches with demonstrably nil blast radius
  (use judgment — if in doubt, run the review)

Document every Codex cycle in Serena `decision_log` with the
verdict(s), fixes applied, and final GO.

### 3. Present to User (Mandatory Confirmation)

Before modifying any files, show:

- List of commits being pushed
- Proposed version: `current → new` with rationale
- Draft CHANGELOG entry (summary of changes)
- Files that will be modified: `SKILL.md`, `README.md`, `CHANGELOG.md`

**Wait for explicit user confirmation before proceeding.**

### 4. Review README Content

Before modifying version files, review README.md at TWO levels:

**Level 1 — Factual accuracy (every release):**
- File tree descriptions — do they match current state?
- Version numbers in example text — do they reference current versions?
- Feature descriptions — any new capabilities missing or removed features still listed?
- Stale claims — any behavioral descriptions that no longer match reality?

**Level 2 — First-time user test (every 3rd minor release, or on any release with new user-facing features):**
- Read the README as a stranger. Does the opening explain what this is within 30 seconds?
- Is the information flow logical? (Why → What → How → Get started)
- Are there version-specific callouts that should be timeless? (e.g., "v4.0 brings..." → should describe current state)
- Is the two-session model explained clearly and without redundancy?
- Would a user be excited to install this after reading?
- Are features from the last 3+ releases represented (not just the latest)?

If Level 2 reveals structural issues, propose a README rewrite as a separate deliverable
in the release — not a patch. Present findings to user via AskUserQuestion before proceeding.

Fix Level 1 issues as part of the version bump commit.
Fix Level 2 issues as a dedicated commit (may require a separate implementation prompt).

### 5. Execute the Bump

Update these files (all three, every time):

| File | Location | What to Change |
|---|---|---|
| `SKILL.md` | Line 12, `version:` field | `version: X.Y.Z` |
| `README.md` | Line 5, badge URL | `version-X.Y.Z-blue` |
| `CHANGELOG.md` | Top of file, new section | `## [X.Y.Z] - YYYY-MM-DD` with categorized entries |

### 6. Commit, Tag, Push

```
git add SKILL.md README.md CHANGELOG.md
git commit -m "release: vX.Y.Z — [one-line summary]"
git tag vX.Y.Z
git push origin main --tags
```

### 7. Create GitHub Release

After pushing, create a GitHub Release (required for the version-check system):

```bash
gh release create vX.Y.Z --title "vX.Y.Z — [one-line summary]" --notes "[CHANGELOG entry for this version]"
```

Or extract the entry automatically:

```bash
gh release create vX.Y.Z --title "vX.Y.Z — [one-line summary]" \
  --notes "$(awk '/^## \['"X.Y.Z"'\]/{found=1; next} found && /^## \[/{exit} found' CHANGELOG.md)"
```

**Why**: The startup version check and `/strategic-partner:update` fetch
`/releases/latest` from GitHub API. Without a Release, users won't get
update notifications.

### CHANGELOG Entry Format

Follow the existing convention (Keep a Changelog style):

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Fixed
- **Description** — what was wrong and what was done

### Added
- **Description** — what's new

### Changed
- **Description** — what's different
```

Only include sections that have entries. Use `**bold lead**` with em-dash description.
