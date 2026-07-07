# Release Process (Mandatory Before Push)

Every push to remote MUST go through this process.

**Exception — docs-only pushes:** If ALL commits since last push are documentation-only
(README, CLAUDE.md, comments, internal references — no functional changes to SKILL.md
behavior, hooks, commands, or references that affect runtime), the push may skip version
bump, tag, and GitHub Release. Users receive the fixes silently on next update.
This avoids notification noise for trivial changes. The backlog close-out scan
(Step 1a) is **not** skipped by this exception — a docs-only commit can still ship
a backlog item's scope.

### 1. Fetch & Compare

```
git fetch origin
git log origin/main..HEAD --oneline    # commits to push
git log HEAD..origin/main --oneline    # commits we're missing
git diff origin/main..HEAD --stat      # files changed
```

### 1a. Backlog close-out scan

Run the shared shipped-work scan against the release range
(`<previous-tag>..HEAD`, or `<last-push>..HEAD` for a docs-only push) to
catch backlog items whose scope shipped in this batch. This runs **even when
the docs-only exception applies** — a documentation commit can still close an
item. Algorithm and per-candidate confirmation live in
`references/backlog-cycle.md` ("Work ships" + the shipped-work scan
validation) and `/strategic-partner:backlog` Step 3.5. Surface candidates for
confirmation only; never auto-close.

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

7. **Frontmatter-hook lint (v6.10.0+)**: run the fail-closed check that no
   literal triple-dash (three or more hyphens, `---`) appears anywhere inside
   the `SKILL.md` YAML frontmatter except the two delimiter lines. A stray
   triple-dash there — even in an awk pattern or a comment — is read by the
   YAML parser as a document separator, truncating the inline session hook
   and blocking every new session:
   ```
   bash tests/lint-frontmatter-hook.sh
   ```
   Exit 0 = clean. Exit 1 = a triple-dash was found (or the frontmatter is
   malformed/unterminated); address before proceeding. Same blocking posture
   as the transcript lint above — a mechanical violation blocks the release.
   This guards the session-breaking incident introduced by commit `c53d530`
   and missed by its first fix `fd6dff7`, where every human and agent review
   layer inspected the change and missed the invariant.

**Why**: Hook bugs are session-breaking — exit-code-2 blocks on every tool call. See the Provisional Guard *Don't use `${CLAUDE_*}` env vars in hook commands* in `claudedocs/provisional-guards.md`; `claudedocs/INCIDENTS.md` has the v5.4.0→v5.4.1 archaeology. Layer 1 (the PreToolUse source-edit guard, predates v5.14.0) and Layer 3 (the release-time transcript lint) are the only enforcement layers in play; Layer 2 (a runtime PostToolUse / Stop validator family that was prototyped during v5.14.0) was pulled before release after the hook surface proved fragile, so the transcript lint is the sole post-execution backstop for the AUQ, tool-availability, and fence-write-coupling rules.

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

### 2d. Goal-Tripwire Lint (Mandatory for non-docs-only pushes)

The goal-tripwire lint at `tests/lint-goal-tripwire.sh` is a release-time backstop
for the never-execute-from-a-file rule (SKILL.md § Goal-Mode Option): SP may
recommend Claude Code's `/goal` autonomous-run command in chat, but must never write
an executable `/goal` line into a copyable or runnable artifact, where it could fire
on paste or resume. The lint fails closed if an executable `/goal` line (one that
starts, after optional whitespace, with `/goal`) appears in any of four covered locations:

1. a ══ COPY fence anywhere in source (`SKILL.md`, plus any file under `references/`, `commands/`, `assets/`),
2. `.handoffs/last-prompts/` — whole-file, recursive,
3. `.prompts/` — whole-file, recursive,
4. handoff prompt artifacts: ══ COPY fences inside `.handoffs/` Markdown files (recursive — subfolders included), plus top-level `.handoffs/*.txt` / `*.log` prompt dumps, scanned whole-file.

A backticked or mid-line `/goal` mention in prose is exempt — only a bare line-start
command is flagged.

```
bash tests/lint-goal-tripwire.sh
```

Exit 0 = clean. Exit 1 = an executable `/goal` line was found; move it out of the
artifact (the `/goal` line belongs in chat only) before proceeding.

This is its OWN mandatory step, run on every non-docs-only push — it is NOT folded
under Step 2a (which fires only when hooks change, so the tripwire would silently
skip on most releases). Same fail-closed posture as the Step 2c voice lint: a
mechanical violation blocks the release. The self-test fixtures live under
`tests/fixtures/goal-tripwire/` — one failing fixture per covered location plus a
prose pass-case; run the lint with `--root <fixture-dir>` to exercise them.

### 2e. Voice-Mirror Agreement Lint (Mandatory for non-docs-only pushes)

The voice-mirror lint at `tests/lint-voice-mirror.sh` is a release-time backstop for the
rule that SKILL.md is the single canonical home of SP's voice rules and the installable
output style (`output-styles/strategic-partner-voice.md`) is a derived mirror of it
(SKILL.md § Plain-English Default). The lint fails closed if the two files drift apart on
the declarations or on any tracked rule:

1. the style file is missing its `DERIVED MIRROR` header,
2. SKILL.md is missing its canonical-source declaration, or
3. any of a set of distinctive rule "anchors" (one short literal phrase per major voice
   rule) appears in one file but not the other.

```
bash tests/lint-voice-mirror.sh
```

Exit 0 = clean. Exit 1 = a missing header, a missing declaration, or an anchor that appears
in only one file; bring the two files back into agreement (edit SKILL.md first, then mirror
the change into the style file) before proceeding.

This is its OWN mandatory step, run on every non-docs-only push — like the Step 2d
goal-tripwire lint, it is NOT folded under Step 2a (which fires only when hooks change).
Same fail-closed posture as the Step 2c voice lint: a mechanical violation blocks the
release. [⚠️ RISK] anchor agreement is a drift tripwire, not proof of full equivalence — it
catches a rule going missing from one side, not every wording change. The self-test fixtures
live under `tests/fixtures/voice-mirror/` — one failing fixture per check (missing header,
missing declaration, one-file-only anchor) plus a passing pair; run the lint with
`--root <fixture-dir>` to exercise them.

### 3. Present to User (Mandatory Confirmation)

Before modifying any files, show:

- List of commits being pushed
- Proposed version: `current → new` with rationale
- Draft CHANGELOG entry (summary of changes)
- Files that will be modified: `SKILL.md`, `README.md`, `CHANGELOG.md` (and `output-styles/strategic-partner-voice.md` if the voice style content changed this release — bump its `style-version`)

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

**Hard structural constraints (forcing function):**

These apply BEFORE the Level 2 review fires. They prevent soft drift from
re-accumulating release by release.

- **Line ceiling: 300 lines.** README.md stays at or below 300 lines. If a
  release pushes it over, structural cuts are part of the release — not
  deferred.
- **"What's new" capped at the current release only.** Older releases roll
  into CHANGELOG.md (already linked from the badge). The README's "What's
  new" names what the CURRENT release adds; prior versions get one combined
  "see CHANGELOG for prior releases" pointer.
- **"Under the hood" capped at 5 bullets.** Technical implementation detail
  beyond that moves to a dedicated ARCHITECTURE.md or CONTRIBUTING.md. The
  README is for what the tool is and why; not how it's built.
- **SP-internal vocabulary forbidden without one-line gloss.** Terms like
  "PreToolUse hook," "exit code 2," "Layer 1," "Bootstrap stage,"
  "voice-lint skip block," and any term coined inside the project get a
  one-line plain-English description on first mention. Same rule as the SP
  voice rules; just explicit for README.

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

**Audit brief requirements:** When delegating to Codex, the brief MUST
include:

- The hard line ceiling and target reduction
- A forcing question: "Would you install this after reading? Yes or no,
  with the single biggest barrier to 'yes.'"
- A request for the top 5 ranked cuts by impact, each naming the section,
  the action, the line reduction, and one-line reasoning
- Imperative output mode: "do not soften," "do not list more than 5,"
  "do not use 'consider' or 'may want to'"

**Findings disposition:**

Fix Level 1 issues as part of the version bump commit.

Fix Level 2 issues as a dedicated commit (may require a separate
implementation prompt). If Level 2 reveals issues warranting a README
rewrite, propose it as a separate deliverable in the release — not a
patch. Present findings to user via AskUserQuestion before proceeding.

**Decision rule additions:**

- Act on all top-ranked cuts unless each one receives an explicit
  counter-argument documented in the release commit message or handoff.
- "Noted, but for now…" is not a valid disposition. Cut or counter-argue
  with reasoning.
- If the install-or-skip judgment returns "no," the release is BLOCKED on
  README revision. The single biggest barrier-to-install becomes the top
  priority for the release.

### 5. Execute the Bump

Update these files (all five, every time):

| File | Location | What to Change |
|---|---|---|
| `SKILL.md` | Line 11, `version:` field | `version: X.Y.Z` |
| `README.md` | Line 5, badge URL | `version-X.Y.Z-blue` |
| `CHANGELOG.md` | Top of file, new section | `## [X.Y.Z] - YYYY-MM-DD` with categorized entries |
| `output-styles/strategic-partner-voice.md` | Frontmatter `style-version:` field | Bump `style-version` **only if the voice style content changed this release** (the floor compares this stamp to the installed copy to flag staleness; an unchanged release leaves it as-is) |
| `plugin/strategic-partner/skills/strategic-partner/SKILL.md` | Line 11, `version:` field | `version: X.Y.Z` — bump every release, no exceptions. If this release changed root `SKILL.md` content (not just the version line), diff the two files' behavioral sections before shipping — this file silently fell two versions behind root before the gap was caught on 2026-07-07 |

### 6. Commit, Tag, Push

```
git add SKILL.md README.md CHANGELOG.md plugin/strategic-partner/skills/strategic-partner/SKILL.md
# Also stage the voice style file IF its content changed this release
# (its bumped style-version is what the floor uses to flag a stale
# installed copy):
# git add output-styles/strategic-partner-voice.md
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
