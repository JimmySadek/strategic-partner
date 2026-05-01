# Strategic Partner — Project Rules

## Where to Look

| When | Resource |
|---|---|
| Running a release | `.scripts/release-publish.sh` — automates Step 7 (GitHub Release creation with CHANGELOG entry extraction) |
| Investigating past hook bugs or other archaeology | `claudedocs/INCIDENTS.md` — incident write-ups referenced from Provisional Guards and from Step 2a hook verification |
| Cross-referencing patterns or finding past lessons | `CHANGELOG.md` — searchable history of every feature, fix, and reactive entry |
| Confirming current version | `SKILL.md` line 12 (`version:` field), and the `version-X.Y.Z-blue` badge on `README.md` line 5 |

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

6. **Transcript lint (v5.14.0+)**: run the Layer 3 transcript lint backstop
   against recent `.handoffs/*.md` files and (if accessible) JSONL transcripts
   since the last release tag. This verifies no AUQ, tool-availability, or
   fence-write coupling violations slip through to users:
   ```
   bash tests/lint-transcripts.sh
   ```
   Exit 0 = clean. Exit 1 = violations found; address before proceeding.
   If the lint reports violations in historical transcripts that predate v5.14.0
   (before enforcement was added), document them as expected baseline and
   verify new transcripts are clean.

**Why**: Hook bugs are session-breaking — exit-code-2 blocks on every tool call. See the Provisional Guard *Don't use `${CLAUDE_*}` env vars in hook commands* at the bottom of this file; `claudedocs/INCIDENTS.md` has the v5.4.0→v5.4.1 archaeology. Layer 1 (the PreToolUse source-edit guard, predates v5.14.0) and Layer 3 (the release-time transcript lint) are the only enforcement layers in play; Layer 2 (a runtime PostToolUse / Stop validator family that was prototyped during v5.14.0) was pulled before release after the hook surface proved fragile, so the transcript lint is the sole post-execution backstop for the AUQ, tool-availability, and fence-write-coupling rules.

### 2b. Codex Pre-Release Review (Mandatory for non-docs-only pushes)

Before any non-docs-only push, run an adversarial review via
`/strategic-partner:codex-feedback` in Evidence Audit mode (Mode B)
asking four questions:

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
4. **Voice quality in this release's SP sessions** — did SP use
   internal jargon in user-facing chat (Direction N, Layer N,
   deliverable N, ritual audit, policy v1, Step 2b/2c, Path A/B/C,
   etc.) without plain-English description? The release-time voice
   lint catches the six mechanical regex patterns; this question
   catches the semantic jargon those regexes miss. Cite violations
   with direct quotes from the recent `.handoffs/` notes and the
   project's JSONL transcripts.

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

### 2c. Voice Lint (Mandatory for non-docs-only pushes)

The voice lint at `tests/lint-voice.sh` is a release-time backstop for the
User-Facing Voice Rules. It scans CHANGELOG.md, README.md, and
`commands/*.md` for jargon-loaded patterns that violate the rules:
function-call notation in prose, incident IDs, internal direction/layer
references, and raw line references.

```
bash tests/lint-voice.sh
```

Exit 0 = clean (or warnings only). Exit 1 = mechanical violations found;
address before proceeding.

The lint also emits warn-level findings for first-occurrence internal terms
without a gloss (envelope, ledger, Bootstrap, Router, Egress, Fast Lane,
etc.). Warnings are informational; they do not block the release.

If the lint reports baseline violations in entries that predate v5.15.0
(before enforcement was added), document them as expected baseline and
verify new entries are clean. New entries written for the current release
must pass the lint with zero mechanical violations.

For sections that legitimately use internal vocabulary (file trees,
architecture details), bracket them with skip-block markers:

```
<!-- voice-lint:skip-start -->
...content not scanned...
<!-- voice-lint:skip-end -->
```

Code blocks and blockquotes are auto-skipped. Same gating posture as
Step 2a's transcript lint — mechanical violations block; warnings inform.

### 3. Present to User (Mandatory Confirmation)

Before modifying any files, show:

- List of commits being pushed
- Proposed version: `current → new` with rationale
- Draft CHANGELOG entry (summary of changes)
- Files that will be modified: `SKILL.md`, `README.md`, `CHANGELOG.md`

**Wait for explicit user confirmation before proceeding.**

### 4. Review README Content

Before modifying version files, review README.md at TWO levels. **Both
levels are MANDATORY each release** — there is no "every 3rd minor"
exception. The README is the only artifact most prospective and existing
users will read between releases; stale or unclear copy is a real shipped
defect, not a docs nit.

**Level 1 — Factual accuracy:**
- File tree descriptions — do they match current state?
- Version numbers in example text — do they reference current versions?
- Feature descriptions — any new capabilities missing or removed features still listed?
- Stale claims — any behavioral descriptions that no longer match reality?

**Level 2 — First-time user clarity:**
- Read the README as a stranger. Does the opening explain what this is within 30 seconds?
- Is the information flow logical? (Why → What → How → Get started)
- Are there version-specific callouts that should be timeless? (e.g., "v4.0 brings..." → should describe current state)
- Is the two-session model explained clearly and without redundancy?
- Would a user be excited to install this after reading?
- Are features from the last 3+ releases represented (not just the latest)?

**Delegation to Codex** (recommended for releases with new user-facing features):

The README review may be delegated to Codex via
`/strategic-partner:codex-feedback` with a dedicated first-time-user
brief (separate from the Step 2b release-audit Codex run). The audit
asks Codex to read the README as a stranger and report factual drift,
structural ambiguity, stale references, and clarity gaps — with file:line
citations. When delegated, run the README audit BEFORE Step 3 (Present
to User) so any findings are folded into the release commits, not
deferred to a patch.

The SP/user may run Level 1 + Level 2 directly without Codex; delegation
is an option, not a requirement. But for releases with new user-facing
features (heuristic: any minor or major bump), Codex delegation is
recommended because adversarial first-time-user reading catches drift
the author cannot see.

**Findings disposition:**

Fix Level 1 issues as part of the version bump commit.

Fix Level 2 issues as a dedicated commit (may require a separate
implementation prompt). If Level 2 reveals issues warranting a README
rewrite, propose it as a separate deliverable in the release — not a
patch. Present findings to user via AskUserQuestion before proceeding.

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
.scripts/release-publish.sh X.Y.Z "one-line summary"
```

The script runs the same `gh release create` invocation that previously lived
inline here, with the matching CHANGELOG entry extracted automatically as
release notes. Pre-flight checks confirm `gh` is installed and authenticated,
the tag exists locally, and `CHANGELOG.md` is in the current directory. For
manual control over the release notes, invoke `gh release create` directly with
`--notes` and your own text.

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

### User-Facing Voice Rules

User-facing artifacts — CHANGELOG entries, README user-facing prose, and
subcommand descriptions in `commands/` — must read clean to a smart
non-developer. CHANGELOG content is linked from the README badge,
extracted into GitHub Release notes, and surfaced by
`/strategic-partner:update`; README is the first thing strangers see;
subcommand descriptions surface via `/strategic-partner:help`. Apply
SP's own voice rules:

- **Plain-English lead** — open each bullet with what changed for the user
  in plain language; technical name as a parenthetical or subordinate
  clause, not as the bullet's headline.
- **Define-Before-Use** — first mention of any project-internal vocabulary
  (envelope names, ledger states, trigger numbers, layer architecture, etc.)
  gets a one-line gloss in plain English. Subsequent mentions in the same
  entry can use the term as a handle.
- **No raw file paths or line numbers** in user-visible bullets unless they
  carry user-meaningful context.
- **Headline first, detail after** — a reader skimming should understand
  the change in 1-2 sentences. Engineering motivation, mechanism, and scope
  follow the headline, not the other way around.

GitHub Release notes derived from a CHANGELOG entry must pass the same
gate. If the entry doesn't read clean for a non-developer, rewrite the
entry — don't fork to a separate user-facing file.

**Bad:**

> **Typed Response Envelopes** — four-envelope response taxonomy
> (Conversational, Analytical, Packaged Prompt, Closure) maps response
> shape to appropriate formatting and visual density.

**Good:**

> **Different reply types now get different formatting** (typed response
> envelopes) — Brief acknowledgments stay short. In-depth recommendations
> get tables. Executor briefs get full ceremony. SP picks the right shape
> based on what kind of reply it's giving.

The rule applies to new content going forward. Existing content may be
rewritten as part of the next release that touches it; retroactive
rewrite is not required.

## Provisional Guards

Bug-driven rules. Each guard names the pattern, the past incident that
motivated it, and a date to revisit. See `claudedocs/INCIDENTS.md` for the
underlying archaeology.

### Don't use `${CLAUDE_*}` env vars in hook commands

Instead: inline the values, use deterministic path resolution, or grep
`CHANGELOG.md` for prior incidents with the variable name before relying on it.

- **Scope**: Hook commands in `SKILL.md` frontmatter and `hooks/` files.
  Specifically: `${CLAUDE_SKILL_DIR}`, `${CLAUDE_PROJECT_DIR}`,
  `${CLAUDE_TOOL_NAME}`, and any `CLAUDE_*` variable not explicitly verified in
  current Claude Code documentation as being set in the hook execution
  environment.
- **Source**: v5.4.1 (2026-03-31) — see `claudedocs/INCIDENTS.md` (`INC-2026-03-30 — Hook command relies on ${CLAUDE_SKILL_DIR}`)
- **Review**: 2026-07-28 (90 days from policy adoption on 2026-04-29; pre-existing reactive rule, eligible for permanence on review per Direction 4 lifecycle)

### Brief authors must re-read locked design files at brief-author time, not derived summaries

Instead: when scoping an executor brief that derives from a multi-source design lock (a `.prompts/[milestone]/design-*.md` file iterated across multiple Codex review rounds, a `decision_log` summary that rolls up the locked design's content, or a Phase task list documented after design lock), re-read the LOCKED design files directly. Summary lists are convenient but lossy — they may name smaller items individually while skipping the load-bearing implementation as a discrete sub-task.

- **Scope**: SP brief authoring — the `.prompts/[milestone]/[descriptor].md` files SP writes for executor dispatch — specifically when the brief covers work derived from a multi-iteration design that was locked through Codex review rounds or extended SP advisory work. Smaller mechanical briefs (single-file fixes, quick patches) are out of scope; this guard targets briefs that aggregate multiple components from a substantial design.
- **Source**: 2026-05-01 — v5.15.0 fan-out brief missed the 8-group closure floor entirely because the brief author worked from the `decision_log` Phase 3 task summary list rather than re-reading `.prompts/v5150-structural-fix/design-ab.md` directly. The summary listed smaller items individually (handoff doc backlog mention, identity-reset rule, startup-checklist refactor) but didn't repeat the closure-floor implementation as a discrete sub-task. User caught the gap mid-session; SP had to draft a second brief covering what the first missed. See `.handoffs/findings-0501.md` Issue 2 for the full journey.
- **Review**: 2026-07-30 (90 days from policy adoption on 2026-05-01)

### Deferred work needs durable artifacts (backlog item or reference doc), not just commit messages

Instead: when a release defers a planned feature or fix to a future release (e.g., "deferred to vX.Y+1" callouts in design Principle rewrites, Component rewrites, brief commit messages), document the deferral in BOTH (a) the relevant commit message or brief context, AND (b) a durable artifact that surfaces during normal SP scans. Acceptable durable artifacts: a `.backlog/[deferred-item].md` file with explicit `trigger:` field for re-engagement, OR a dedicated section in a reference doc (e.g., `references/closure-floor.md` § "Why we do not ship a SessionEnd hook"). The artifact must surface during SP orientation, `/strategic-partner:backlog`, or closure-floor Group 7a backlog hygiene scans — not only in commit history.

- **Scope**: Any explicit deferral within a release. Typical patterns include: design principles that name a v5.X+1 follow-up, Component rewrites that move a feature out of scope, "deferred to next release" notes in brief commit messages or release CHANGELOG entries.
- **Source**: 2026-05-01 — v5.15.0 closure-floor brief deferred Stop rule 6 (closure-walk-completeness) to v5.16.0 in Principle 5's rewrite + Component 7's commit message. Codex re-review (`.handoffs/codex-closure-floor-rereview-output-0501.md`) flagged: "the v5.16 deferral lives only in the brief's commit message — findable if you know to look, but not surfaced automatically when v5.16 work begins." SP created `.backlog/closure-walk-completeness-stop-rule.md` to make the deferral surface in normal SP backlog scans. See `.handoffs/findings-0501.md` Issue 2.
- **Review**: 2026-07-30 (90 days from policy adoption on 2026-05-01)
