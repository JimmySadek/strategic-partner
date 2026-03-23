# Strategic Partner — Project Rules

## Release Process (Mandatory Before Push)

Every push to remote MUST go through this process. No exceptions.

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

### 3. Present to User (Mandatory Confirmation)

Before modifying any files, show:

- List of commits being pushed
- Proposed version: `current → new` with rationale
- Draft CHANGELOG entry (summary of changes)
- Files that will be modified: `SKILL.md`, `README.md`, `CHANGELOG.md`

**Wait for explicit user confirmation before proceeding.**

### 4. Review README Content

Before modifying version files, scan README.md for stale content:

- **File tree descriptions** (e.g., skill counts, feature claims) — do they match current state?
- **Threshold numbers or behavioral claims** — do they reflect the latest changes?
- **Feature descriptions** — any new capabilities missing or removed features still listed?

Fix any stale content as part of the version bump commit.

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
