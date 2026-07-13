# Provisional Guards

Bug-driven rules. Each guard names the pattern, the past incident that
motivated it, and a date to revisit. See `claudedocs/INCIDENTS.md` for the
underlying archaeology.

### Floor signals describe state; they never grant write or dispatch authority

Instead: derive compact health from the detailed receipt, treat live tool state as
authoritative when it disagrees, and keep optional maintenance out of read-only or
startup critical paths. A missing or stale routing matrix may be acknowledged and
deferred; it can dispatch a write-capable worker only after a later task materially
needs the matrix and the user gives the existing exact agent confirmation.

- **Scope**: startup floor summary derivation, orientation instructions, routing
  matrix maintenance, onboarding suggestions, and any worker brief produced from a
  non-clean floor signal.
- **Source**: `claudedocs/INCIDENTS.md` § INC-2026-07-13-B — an empty Serena memory
  directory became `memory=ok`, then `routing=missing` triggered an unapproved
  write-capable worker during a read-only orientation and delayed the answer by
  nearly four minutes.
- **Review**: 2026-10-13.

### Utility-command exemptions must agree across every activation path

Instead: whenever a plugin subcommand is advisory-neutral, test its exact
plugin and legacy spellings through both `UserPromptExpansion` and the
`UserPromptSubmit` compatibility path. Neither path may create the active or
startup-pending advisory marker. A mutating utility may use a distinct
guard-only marker when it must preserve source protection without enabling
Stop-hook ceremony.

- **Scope**: Plugin command activation classifiers in `hooks/entry.sh` and
  `hooks/lib/session-ceremony.sh`, including any duplicated compatibility
  parser retained for older Claude Code event shapes.
- **Source**: `claudedocs/INCIDENTS.md` § INC-2026-07-13 — `:serena` was
  correctly exempt in command expansion but armed by prompt submission, so the
  Stop hook demanded an advisory recenter during a utility-only repair flow.
- **Review**: 2026-10-13.

### Join hook transcript events by tool-use ID, never row adjacency

Instead: pair `AskUserQuestion.id` with the matching
`tool_result.tool_use_id`, and bind authorization to the current PreToolUse
`tool_use_id`; treat metadata rows as unrelated events, not positions to skip.

- **Scope**: Any hook that reads a Claude Code JSONL transcript to authorize a protected action, including Agent/Task dispatch and `.sp-managed` activation.
- **Source**: `claudedocs/INCIDENTS.md` § INC-2026-07-10 — an exact agent confirmation was rejected because five metadata rows appeared between the question and its matching answer.
- **Review**: 2026-10-10.

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
