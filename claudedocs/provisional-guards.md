# Provisional Guards

Bug-driven rules. Each guard names the pattern, the past incident that
motivated it, and a date to revisit. See `claudedocs/INCIDENTS.md` for the
underlying archaeology.

### Don't use `${CLAUDE_*}` env vars in hook commands

Instead: inline the values, use deterministic path resolution, or grep `CHANGELOG.md` for prior incidents with the variable name before relying on it.

- **Scope**: Hook commands in `SKILL.md` frontmatter and `hooks/` files — including `${CLAUDE_SKILL_DIR}`, `${CLAUDE_PROJECT_DIR}`, `${CLAUDE_TOOL_NAME}`, and any other unverified `CLAUDE_*` variable.
- **Source**: `claudedocs/INCIDENTS.md` § INC-2026-03-30 — v5.4.0 → v5.4.1 hook breakage from two phantom env vars plus a permissive matcher.
- **Review**: 2026-07-28.

### Brief authors must re-read locked design files at brief-author time, not derived summaries

Instead: when scoping a brief that derives from a multi-iteration locked design, re-read the locked design files directly — summary lists are convenient but lossy and routinely drop load-bearing items.

- **Scope**: SP-authored executor briefs in `.prompts/[milestone]/[descriptor].md` that aggregate multiple components from a substantial locked design; small mechanical briefs (single-file fixes, quick patches) are out of scope.
- **Source**: `claudedocs/INCIDENTS.md` § INC-2026-05-01-A — v5.15.0 fan-out brief missed the 8-group closure floor because the author worked from a `decision_log` summary instead of re-reading the locked design.
- **Review**: 2026-07-30.

### Deferred work needs durable artifacts (backlog item or reference doc), not just commit messages

Instead: when a release defers a planned feature, document it in BOTH (a) the relevant commit/brief context AND (b) a durable artifact — a `.backlog/[item].md` file with an explicit `trigger:` field, or a dedicated section in a reference doc — so the deferral surfaces during normal SP scans, not only in commit history.

- **Scope**: Any explicit deferral within a release — design principles naming a v5.X+1 follow-up, Component rewrites that move work out of scope, "deferred to next release" notes in commit messages or CHANGELOG entries.
- **Source**: `claudedocs/INCIDENTS.md` § INC-2026-05-01-B — v5.15.0 closure-floor brief deferred Stop rule 6 to v5.16.0 with no surface artifact, so the deferral was findable only by reading the original commit message.
- **Review**: 2026-07-30.

### Brief verification commands and prose specs in the same brief must agree

Instead: when a brief includes prose describing a structural element AND verification grep/regex patterns checking for that element, the two must use literally identical patterns.

- **Scope**: Executor briefs in `.prompts/[milestone]/[descriptor].md` whose verification commands reference structures described in prose deliverables.
- **Source**: `claudedocs/INCIDENTS.md` § INC-2026-05-01-C — closure-floor brief's Component 1 prose said "Steps 1-8" while its verification grep `^### Group [1-8] —` required no "Step" prefix; two specs in the same brief disagreed.
- **Review**: 2026-07-30.

### Briefs with user-keyboard verification must enumerate three outcomes

Instead: when a brief's verification requires user-keyboard work (separate terminal, fresh CC session, manual `/exit` lifecycle), enumerate three outcomes — (a) all gates pass → ship; (b) any gate fails → defer with documented failure mode; (c) test couldn't run within executor scope → defer with explicit scope-limit documentation.

- **Scope**: Executor briefs whose verification depends on multi-process orchestration the agent cannot drive (separate terminals, fresh Claude Code sessions, manual lifecycle events).
- **Source**: `claudedocs/INCIDENTS.md` § INC-2026-05-01-D — closure-floor brief's Component 5 used binary "any gate fails → don't ship" framing that elided the "untested in this scope" third state.
- **Review**: 2026-07-30.

### Cross-file template token names must agree across all files in the same authored set

Instead: when authoring multiple template/specification files in sequence (template + renderer command + reference specification), use literally identical token names across all files.

- **Scope**: Multi-file authoring sessions where 2+ files share a templated token vocabulary — typically a template file in `assets/templates/`, a renderer command in `commands/`, and a reference spec in `references/`.
- **Source**: `claudedocs/INCIDENTS.md` § INC-2026-05-03-A — handoff template `[STATUS_EMOJI]` vs `commands/handoff.md` initial-draft `[STATE_EMOJI]` mismatch; one-word divergence, same renderer slot.
- **Review**: 2026-08-01.

### Routing matrix freshness is content-based (inventory hash), not time-based

Instead: compare an `inventory_hash` field in the matrix footer (sha256 of sorted `~/.claude/agents/*.md` basenames + count, truncated to 16 hex chars) against a recomputed hash; both the floor sentinel and Agent D must compute from the same filesystem source so the hashes agree. Never use file mtime + a fixed time threshold — the inventory only changes when agents change, not on a fixed cadence.

- **Scope**: SKILL.md frontmatter UserPromptSubmit hook Group 7; `references/floor.md` § Group 7; Agent D protocol in `references/startup-checklist.md` and `references/skill-routing-matrix.md`.
- **Source**: `claudedocs/INCIDENTS.md` § INC-2026-05-03-B — mtime + 1-hour staleness check + permanent rebuild loop in BAM-MVP, plus a Codex-caught hash-source bug in the first v5.16.0 dispatch.
- **Review**: 2026-08-01.

### User project files don't get SP-flavored framing

Instead: when SP evaluates, drafts, or rates a user project's `CLAUDE.md` / `AGENTS.md` / `GEMINI.md`, treat any SP-as-pillar declaration (a top-of-file heading framing SP as an always-active behavioral mode), or any operating-rules block duplicating SP's own behavioral defaults (the standard interaction-discipline directives that ship with SP itself), as a policy violation rather than a strength. SP is a skill — those defaults apply automatically when SP is invoked. Run `/strategic-partner:context-file-scan` against the project file to surface S9 findings; flag SP-flavored framing in user-authored content as something to remove or scope to a project-named overlay, never to endorse. The exact phrase set the scanner matches against lives in `.scripts/context-file-scan/rules/structural.sh` (the source of truth) — do not inline it here, since that would re-trigger the rule on SP's own context file.

- **Scope**: SP advisory turns evaluating, rating, drafting, or auditing a user's `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` — and the scanner rule S9 in `.scripts/context-file-scan/rules/structural.sh` that mechanically detects the same pattern.
- **Source**: `claudedocs/INCIDENTS.md` § INC-2026-05-06 — v6.0.1 BAM-MVP rating session scored "Strategic Partner Mode — ALWAYS ACTIVE" framing 9/10 as a strength when it was a policy violation; codified in v6.1.0 as scanner rule S9 plus this guard.
- **Review**: 2026-08-06.
