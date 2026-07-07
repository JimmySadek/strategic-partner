# Strategic Partner — Project Rules

═══════════════════════════════════════════════════════════════════

## 🎯 Project Facts

- **Versioning** — SemVer. The version-bump procedure keeps release metadata
  together: root `SKILL.md`, plugin `SKILL.md`, plugin manifest, `README.md`,
  `CHANGELOG.md`, and — when their content changed this release — the root or
  plugin voice files whose `style-version` stamps detect stale installed copies;
  see `claudedocs/release-process.md` Step 5 for the canonical "what changes
  where." (Where to Look points to the current version's location.)
- **Commit style** — Conventional commits (`feat:`, `fix:`, `refactor:`,
  `docs:`, `release:`). Release commits use `release: vX.Y.Z — one-line summary`
  per `claudedocs/release-process.md` Step 6.
- **User-facing voice** — CHANGELOG entries, README user-prose, and
  `commands/*.md` descriptions follow the User-Facing Voice Rules in
  `claudedocs/release-process.md` (plain-English lead, define-before-use, no
  raw paths). The voice lint at `tests/lint-voice.sh` enforces the mechanical
  patterns at release time.
- **macOS bash 3.2 in hooks** — Shell hooks must run under bash 3.2 — no
  associative arrays, no nameref variables. Tool name comes from stdin JSON
  (`tool_name`), never from `${CLAUDE_*}` env vars (see
  `claudedocs/provisional-guards.md`).

═══════════════════════════════════════════════════════════════════

## 📍 Where to Look

| When | Resource |
|---|---|
| Investigating past hook bugs or any reactive rule's archaeology | `claudedocs/INCIDENTS.md` — incident write-ups (one entry per `INC-YYYY-MM-DD` ID) referenced by every Provisional Guard and by the Step 2a hook verification in `claudedocs/release-process.md` |
| Cross-referencing patterns or hunting prior lessons across releases | `CHANGELOG.md` — searchable history of every feature, fix, and reactive entry; CHANGELOG content surfaces directly in GitHub Release notes |
| Running a release after the release commits land | `.scripts/release-publish.sh` — automates Step 7 of `claudedocs/release-process.md` (creates the GitHub Release with the matching CHANGELOG entry extracted as release notes) |
| Confirming the current SP version | `SKILL.md` line 11 (`version:` field) and the `version-X.Y.Z-blue` badge on `README.md` line 5 |

═══════════════════════════════════════════════════════════════════

## 🧠 Behavioral Guardrails

When editing SP source files, follow these behavioral principles:

   1. **Think Before Coding**   →  surface assumptions; reject sycophancy as
                                   a dark pattern; push back when warranted
   2. **Simplicity First**       →  no overengineering; minimum code; no
                                   speculative abstractions
   3. **Surgical Changes**       →  every changed line traces to the request;
                                   no drive-by refactoring
   4. **Verification, not Specification**  →  declarative verifiable outcomes
                                              over imperative step-by-step
                                              prescription
   5. **Voice Discipline**       →  plain English, deliberate visualization,
                                   functional emoji anchors, no internal
                                   jargon without first-mention gloss

📁 **Full rules + worked examples:** [`.claude/rules/source-editing.md`](.claude/rules/source-editing.md)
[Path-scoped rules maintained for Claude sessions; Codex sessions should read
 the file before editing SKILL.md, hooks/, references/, commands/, or tests/.]

═══════════════════════════════════════════════════════════════════

## ⚙️ Release Process (Mandatory Before Push)

review-policy: cross-model-go-no-go

Every push to remote MUST go through the full release process — fetch/compare,
backlog close-out scan, bump classification, hook + voice + tripwire lints,
Codex pre-release review, README review, the coordinated version bump, tag, and
GitHub Release.

**Exception — docs-only pushes:** if EVERY commit since the last push is
documentation-only (no functional changes to SKILL.md behavior, hooks,
commands, or runtime-affecting references), the push may skip the version bump,
tag, and GitHub Release. Users receive the fixes silently on next update.

📁 **Full procedure (all steps, lints, and gates):** [`claudedocs/release-process.md`](claudedocs/release-process.md)

═══════════════════════════════════════════════════════════════════

## 🚧 Provisional Guards

Bug-driven rules: each guard names a pattern, the past incident that motivated
it, and a date to revisit. Before relying on any `${CLAUDE_*}` env var or a
specific path-resolution pattern in a hook, grep `CHANGELOG.md` and
`claudedocs/INCIDENTS.md` for prior incidents with that variable or pattern —
the harness has broken hooks this way before.

📁 **Full guard list:** [`claudedocs/provisional-guards.md`](claudedocs/provisional-guards.md)
📁 **Incident archaeology:** [`claudedocs/INCIDENTS.md`](claudedocs/INCIDENTS.md)
