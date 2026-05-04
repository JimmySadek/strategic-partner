# Changelog

## [5.17.0] - 2026-05-04

### Changed
- **SP's own project-rules file got reshaped to match SP's draft policy on rules-files** (migration #1, internal). SP has been drafting a policy on how project-rules files (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`) should be sized, sectioned, and trimmed over time. This release applies that policy to SP's own `CLAUDE.md` as the first of three to five projects that have to migrate before the policy ships publicly. The file now opens with a small "Project Facts" section (four non-default conventions like commit style and macOS bash compatibility), a polished "Where to Look" pointer table, the unchanged release runbook, and a tighter rules section at the bottom.

- **Bug-driven rules now sit in a 4-line shape pointing at the underlying incident write-ups.** Each Provisional Guard (the entries that record a rule SP added in response to a past incident) used to carry a multi-paragraph narrative explaining the original bug inline. Those narratives have moved to `claudedocs/INCIDENTS.md` — searchable, indexed, one entry per incident. The guards themselves keep only the rule, its affirmative alternative, the scope, the pointer to the incident write-up, and the review date. Same rules, less reading at session start.

### Added
- **Six new incident write-ups in `claudedocs/INCIDENTS.md`** — one for every Provisional Guard whose narrative just moved out of `CLAUDE.md`. Each entry follows the existing format: What happened / Why it broke / Fix shipped / Lesson formalized.

- **The release-time quality check now supports an explicit skip-list for old conversation transcripts** (a `.lint-allowlist` file at the repo root). Each non-comment line names a single transcript filename to exempt. Two transcripts from the v5.17.0 design-phase advisory sessions are added to the skip-list as a one-time bootstrap — those transcripts captured authoring drift that never reached any published file (CHANGELOG, README, CLAUDE.md, INCIDENTS.md are all clean). Future sessions are still scanned in full; the mechanism exists so a single old session does not block an otherwise-clean release.

### Note
- **The reshaped `CLAUDE.md` lands at 404 lines / 21K characters — healthy for a single-topic release runbook, not a length problem.** The draft policy explicitly endorses release-runbook files at this size when their content earns its space; this release confirms that's the realistic floor for SP's own runbook after every reasonable compression pass.

- **The rules-file policy itself stays unpublished for now.** It ships publicly when the matching auto-scan command exists and the policy gets referenced from SP's onboarding for new projects. Three more project migrations after this one will prompt a first-pass review of the policy itself.

- **The two allowlisted transcripts are documented in the `.lint-allowlist` file itself** with rationale comments. The allowlist is intended for deliberate, documented exemptions only — every entry should name the reason it's there and reference whatever follow-up work (if any) closes the underlying gap.

## [5.16.0] - 2026-05-03

### Fixed
- **The routing matrix no longer rebuilds every session.** Previously, a fresh SP session opened more than an hour after the last build triggered a full rebuild, burning ~4 minutes and ~85K tokens to inventory the same skills, agents, and MCP servers as before. The startup floor check now compares a compact fingerprint of the agent inventory (a sha256 over the sorted filenames in `~/.claude/agents/`) against a fingerprint stored in the cached matrix. If they match, the cached matrix is reused with no rebuild. If they differ, only then does a rebuild run — because something actually changed. The freshness check itself runs in ~150ms per invocation, well under the 200ms budget for the startup floor, and uses zero LLM tokens when nothing changed. The fingerprint covers agents only (not skills or MCP servers) because the startup hook can read `~/.claude/agents/` from the same filesystem location the rebuild does — that's the only inventory source where the two sides are guaranteed to compute identical hashes. Pure skill or MCP installs without an accompanying agent change are not auto-detected by the floor; an explicit refresh via `/strategic-partner:update` handles those cases.

- **A permanent rebuild loop in projects without Serena memory is now closed.** Previously, the floor only checked the Serena memory location, while the SP wrote the matrix to `.claude/` files when Serena was absent — so the floor saw "missing" every session and dispatched a rebuild every session. The floor now falls through Serena → `.claude/skill-routing-matrix.md` → missing, and the SP writes to one canonical location based on whether Serena is active. (User-flagged via the BAM-MVP project, where Serena memory was absent and two competing matrix files had accumulated.)

### Added
- **`inventory_hash` field in the routing matrix footer.** Each rebuilt matrix now records a 16-character sha256 fingerprint of the agent inventory alongside the existing `routing_status`, `scan_timestamp`, `errors`, and `counts` fields. The startup floor reads this field on the next session start to decide whether the cached matrix is current. The fingerprint covers sorted `~/.claude/agents/` filenames plus the agent count so the floor — which has no access to the in-conversation skill list — can recompute the same hash that the matrix builder wrote.

- **A new Provisional Guard in CLAUDE.md** — routing-matrix freshness must be content-based, not time-based. Codifies the inventory-hash decision so future floor work doesn't regress to mtime + time-window heuristics, and pins the hash inputs to filesystem sources both the floor and the matrix builder can see.

### Changed
- **Single canonical routing-matrix file when Serena is absent.** The matrix builder now writes to one source of truth per project: Serena memory `skill_routing_matrix` when Serena is active, else `.claude/skill-routing-matrix.md`. The legacy `.claude/sp-routing-matrix.md` companion is deprecated and no longer created. Existing legacy files in user projects remain on disk until natural rebuild via the canonical name.

## [5.15.2] - 2026-05-03

### Fixed
- **Voice lint now fails closed when it can't actually scan files** (`tests/lint-voice.sh` hardening) — Previously, an empty file collection (e.g., when `TMPDIR` is broken or expected directories go missing) would silently report "all clean" and exit 0. The release-time gate now aborts with exit 1 when expected files exist but zero were scanned. Header comment also updated to document the 7 mechanical patterns now in `hooks/lib/validators.sh`. Closes a hidden release-gate failure mode.

- **Codex CLI dispatch policy hardened end-to-end in `commands/codex-feedback.md`** — Locks in five policies covering every known misconfiguration class for SP-dispatched Codex reviews: (1) **mode-aware sandbox** — Mode A (decision review) uses `--sandbox read-only` for tightest analysis; Mode B (evidence audit) uses `--sandbox workspace-write` because read-only blocks `/tmp` writes that bash heredocs require; (2) **stdin closed via `< /dev/null`** to prevent 30+ min hangs in Codex CLI 0.124+; (3) **never override the model** via `-m`/`--model`/`-c model=*` — user's `~/.codex/config.toml` `model` setting wins (recommend `gpt-5.5` or latest, never `o4-mini` or older); (4) **never override reasoning effort** via `-c model_reasoning_effort=*` — user's config wins (recommend `high` minimum, `xhigh` for complex audits, never medium/low); (5) **generous timeout floors** — bumped to 480s/900s/1500s/2400s for small/moderate/large/full-repo audits, prefer over-allocating to wasting already-spent tokens on a timeout. Spec also documents required `~/.codex/config.toml` settings, `--add-dir` for audits that need transcripts outside the project dir, and minimum Codex CLI version 0.128.0+.

### Added
- **Placeholder-string check in voice lint** — Catches committed user-facing prose containing `[Populated at...]`, `[TODO]`, `[PENDING]`, `[FIXME]`, or `[XXX]` markers across `CHANGELOG.md`, `README.md`, and `commands/*.md`. Prevents incomplete drafts from shipping. Mechanical violation (release-blocking).
- **Cross-file token consistency Provisional Guard** in `CLAUDE.md` — Documents the rule that when authoring multi-file template sets (template + renderer + reference), all files must use IDENTICAL token names. Codifies the v5.15.0 closure-floor lesson where `[STATUS_EMOJI]` and `[STATE_EMOJI]` diverged across three files.

## [5.15.1] - 2026-05-01

### Fixed
- **Close-routine now properly tracks every loose end at session-end.** Previously the close-routine's parked-folder check just gave a count ("27 items total"). It now breaks down by status — how many are ready to act on (their wait condition fired), how many haven't moved in over 30 days, how many are recent, and how many are technically done but still showing as parked. The findings check also now lists what happened to every captured note, not just whether new ones got captured today.

- **Close-routine now closes finished items.** When work in this session finishes a parked item, the close-routine catches it and proposes archiving. Previously items piled up as "parked" even after the work was done.

### Changed
- **Close-routine status table now shows backlog, prompts, and scripts as independent rows.** The combined parked-folder check used to render as a single row in the table; if any of the three sub-checks was skipped, you couldn't tell. Now backlog hygiene, pending prompts, and pending scripts each get their own row.

- **Voice rules document now includes a checklist and worked examples.** The pre-send check now has an explicit list of patterns to scan for (Greek labels, bare letter options without named context, file paths in user prose, internal vocabulary without gloss). And a positive-examples section demonstrates what readable / clearly visual SP communication looks like in practice.

### Added
- **A short paragraph in the canonical close-routine documentation** names the noticed → tracked → done lifecycle as the SP's mental model for findings, backlog, and retired work. Concrete enough to anchor future protocol decisions.

- **Two new Provisional Guards in CLAUDE.md.** First: when an executor brief has both prose specs and verification grep patterns describing the same structural element, the two must use identical patterns. Second: when a brief's verification depends on user-keyboard work, the brief must enumerate three outcomes (pass / fail / couldn't-run-in-scope), not two.

## [5.15.0] - 2026-05-01

### Fixed

- **Update notifications work reliably on fresh sessions** (UserPromptSubmit floor sentinel — Group 6 GitHub release lookup) — The hook that checks GitHub for new SP releases was failing in two ways. First, a 2-second timeout: on a cold session (DNS not yet warm, TLS handshake fresh), the response consistently missed the window. Loosened to 8 seconds and dropped a redundant outer shell timeout. Second, the grep that pulled the version out of GitHub's response required no whitespace after the colon, but GitHub's pretty-printed JSON has a space (`"tag_name": "v5.14.0"`) — so even when curl succeeded, the version was never extracted. Pattern is now whitespace-tolerant. Fresh sessions now see real version status (`current` / `behind` / actual version string) instead of a silent "unreachable".

- **Rhythm enforcer no longer flags SP describing its own rule patterns** (Stop rhythm enforcer — rule 4 fence-write-coupling) — When SP walked through what its own hooks check (e.g., explaining "rule 4 catches `══ START 🟢 COPY ══` fences emitted without a handoff write"), the rule was triggering on the inline-code mention of the fence pattern in SP's prose, not on actual fence emission. The fence detection now strips inline code (single-backtick spans) before matching — same treatment the tool-availability rule already applied. False positive eliminated.

- **Update notifications now correctly handle unreachable releases on the SP body version-check** (`references/startup-checklist.md`) — The version check that fires during SP orientation had the same bugs the floor sentinel's Group 6 fix patched: a regex that didn't tolerate whitespace in GitHub's pretty-printed JSON, and an if/else that fell through to a misleading "UP_TO_DATE" when the regex returned empty. Now whitespace-tolerant, and explicitly emits "UNABLE_TO_CHECK" when GitHub is unreachable instead of falsely declaring the SP up to date.

- **Hooks no longer silently degrade on stock macOS** (SKILL.md frontmatter — UserPromptSubmit floor sentinel + Stop hook) — `timeout` is a GNU coreutils utility not present on macOS by default. Hook calls to `timeout 1 git ...` and `timeout 1 tail ...` were silently failing on stock macOS, causing the floor's git-state check to report `g5.status=clean` even with a dirty working tree. Now uses portable detection (`gtimeout` from Homebrew coreutils first, then `timeout` for Linux, then no-bound fallback if neither is available). Floor remains functional on stock macOS — bounded when the utility is present, unbounded but functional when it isn't.

- **Voice lint no longer false-fires on quoted lint-pattern descriptions** (`tests/lint-voice.sh` tool-availability rule) — When the lint scanned text containing italic-quoted or plain-quoted spans of the lint's own patterns (e.g., a CLAUDE.md section explaining "the voice lint catches *I can run* and *I have access to* patterns"), the rule was triggering on the quoted spans rather than on actual first-person tool-availability claims. Now strips italic-quoted and plain-quoted spans before matching.

- **Voice lint suppresses harmless integer-expression warnings** (in `tests/lint-voice.sh`) — A multi-line guard that compared file count to a threshold could produce shell warnings when the count was an empty string (split-empty edge case). Counts are now defaulted to zero before comparison; warnings eliminated; lint behavior unchanged.

### Added

- **Session facts now arrive automatically at session entry and on subcommand transitions** (UserPromptSubmit floor sentinel) — When you start a session or invoke an SP subcommand, a hook gathers a snapshot of the things SP needs to know to advise you well: which model is running, whether your project has a CLAUDE.md and any rule files, what's in your Serena memories, how many findings and parked backlog items exist, current git state, and whether the SP is up to date. The summary is injected into SP's context as a single line, so SP can't miss it. The hook deduplicates within a session — once SP has the snapshot for a given context (session, project, subcommand mode), repeat prompts skip the gather to avoid noise. This replaces the previous documentation-only approach where SP had to remember to check on its own. Mechanically enforces the startup floor that prose alone has been failing to ensure.

- **Per-turn rhythm enforcer** (Stop rhythm enforcer) — At the end of every assistant turn, a hook scans the response for four common drift patterns: questions buried in prose (instead of using the Ask-User-Question tool), missing identity-reset announcements after returning from a dispatched agent, first-person tool-availability claims without an actual tool call, and execution fences emitted without the expected handoff file write. When SP slips, the violation gets carried into the next turn's context as a one-line note — and SP self-corrects on the next prompt. Five rounds of adversarial review with Codex GPT-5.5 converged on this design.

- **The strategic partner now catches itself when it sees a problem and silently moves on** (Stop rhythm enforcer — new rule 5 floor-signal-acknowledgment) — When the startup floor reports any non-clean signal (project conventions missing, Serena memories missing, git tree dirty, version behind, routing matrix missing or stale), the model must either dispatch a remediation agent or explicitly acknowledge the signal in its response. Silent ignores are now logged and surfaced on the next turn — same shape as the existing rule 2 (identity-reset announcement after dispatch returns).

- **Documentation for what to do with each non-clean startup-floor signal** (SKILL.md Floor-Signal Handling section, plus new `references/floor-signal-handling.md`) — Clear guidance per signal field on whether the model auto-dispatches a remediation agent (e.g., routing matrix gets a background Opus 4.7 agent immediately), gates on user confirmation first (e.g., Serena onboarding for missing memory is heavier and asks first), or just acknowledges in orientation (e.g., dirty git state). Default model for any auto-remediation is Opus 4.7 — these are load-bearing decisions that propagate to every downstream session.

- **Standalone reference for the startup-floor protocol** (`references/floor.md`) — The full spec for what the seven floor groups check, the SP-FLOOR-COMPLETE summary line format, and the carve-out rules for lightweight subcommands now lives in its own reference file. Keeps the broader startup-orientation protocol (mode detection, agent fire-and-verify) separate from the per-prompt floor walk.

- **Closure floor — eight procedural groups walked at session end** (`commands/handoff.md` body, with new `references/closure-floor.md`) — When you invoke `/strategic-partner:handoff` (or signal session end), the SP now walks eight verification groups before writing the handoff file: staleness check on Serena memories, architecture drift scan, routing matrix verification, persistent memory ledger, project conventions ledger, working memory ledger (findings), workspace ledger (with active backlog management), and working tree closure. Each group runs a verification command, marks one of six states, and either takes hygiene actions automatically or asks you only when there's a genuine call to make. Silent skips are no longer possible.

- **Backlog hygiene as a first-class step in the closure walk** (Group 7a in `commands/handoff.md`) — The closure walk scans your `.backlog/` items, surfaces ones whose triggers have fired against current project state, asks about stale items (more than 30 days, no movement) via grouped summary + opt-in per-item review, and promotes unresolved findings from the session that have clear "park this" intent. Bulk-appending to backlog without surfacing what's filed is now an explicit anti-pattern.

- **Visual prescription for the closure walk** (`assets/templates/handoff-template.md` Closure Walk Status section + `commands/handoff.md` inline render + `references/closure-floor.md` Visual Output Specification) — Both the inline closure walk output and the persisted handoff file now render an 8-row Closure Walk Status table with row-anchor emojis (🧠/🏗️/🗺️/💾/📝/📋/📦/🔀) and state emojis (✅/🔄/🟡/⏸️/⏭️/🚨). Matches the init-mode orientation style users already expect. Visual consistency between init and closure orientation is now structurally prescribed.

- **Post-Handoff Verification gates the handoff close** (`commands/handoff.md` terminal step) — Four lightweight checks confirm the continuation prompt is present and intact, the SP invocation is in it, the findings file is surfaced, and `.gitignore` covers the four session-work directories. Catches silent gaps in the handoff contract before the session ends.

- **Backlog stewardship documented in handoff command + reference** — Both the `/strategic-partner:handoff` subcommand and `references/context-handoff.md` now describe the relationship between session findings (lightweight, automatic, session-scoped) and curated backlog items (project-scoped, with structured frontmatter and triggers). Findings carry forward to the next session by default; the handoff bridges them via per-item promotion AskUserQuestions only when scope is unclear.

- **Cross-references between subcommands** — Each of the seven SP subcommands (backlog, codex-feedback, copy-prompt, handoff, help, status, update) now points to related ones in a "See Also" section. Helps users discover the right tool for adjacent needs without running help every time.

- **Deferred Floor Signals section in handoff template** (`assets/templates/handoff-template.md`) — Startup-floor signals that were acknowledged during the session but not addressed (e.g., "version=behind, release ceremony scheduled for tomorrow") now carry forward as continuation context.

- **Identity-reset announcement is now a shared validator function** (`hooks/lib/validators.sh`) — The check that catches missing "Back in advisory mode" or "Dispatch complete" phrases after agent returns is now a shared library function used by the release-time transcript lint. The Stop hook (rule 2) keeps its inline implementation in v5.15.0 to avoid hook-frontmatter sourcing complexity; both detect the same patterns. Future release may converge them onto the shared library.

- **Release-time voice lint** (`tests/lint-voice.sh`, plus `tests/fixtures/v5.15.0/voice-lint/` and `tests/fixtures/v5.15.0/voice-transcript/`) — Mechanical scanner that catches the six jargon-loaded patterns (raw line refs, "Layer N" without gloss, "Direction N", "deliverable N", function-call notation in prose, incident IDs) in user-facing artifacts (CHANGELOG, README, commands/). Scope expanded to also scan SP's chat output in JSONL transcripts and the Codex pre-release review brief. Mechanical violations block release; warnings inform. Skip-block markers (`<!-- voice-lint:skip-start -->` / `<!-- voice-lint:skip-end -->`) bracket sections that legitimately use internal vocabulary (file trees, architecture details).

- **GitHub Release publishing script** (`.scripts/release-publish.sh`) — Wraps the `gh release create` invocation that previously lived inline in CLAUDE.md release ceremony Step 7. Pre-flight checks confirm `gh` is installed and authenticated, the tag exists locally, and CHANGELOG.md is in the current directory. Extracts the matching CHANGELOG entry as release notes automatically.

- **Past-incident archaeology consolidated** (`claudedocs/INCIDENTS.md`) — New file capturing detailed write-ups of past hook bugs and process incidents (currently covering the v5.4.0 → v5.4.1 `${CLAUDE_SKILL_DIR}` hook archaeology). Referenced from the Provisional Guards in CLAUDE.md so the rules and their evidence stay connected.

### Changed

- **Two new hook integrations alongside the existing source-edit guard** (SKILL.md frontmatter) — The strategic-partner skill now ships three hooks that work together: the existing PreToolUse guard that blocks SP from editing source files, plus the two new hooks above. Hook commands resolve their own install path via the stable command symlinks Claude Code creates at `~/.claude/commands/strategic-partner/`, with no dependency on environment variables that aren't reliably set in hook execution contexts.

- **CLAUDE.md project-rules file restructured to policy v1** (Where to Look + Provisional Guards + script extraction) — Top-level "Where to Look" table maps recurring questions to their source-of-truth files. New Provisional Guards section captures bug-driven rules with explicit source incident, scope, and 90-day review date (currently 4 guards: env-var hook hazard from the v5.4.1 incident, brief-author-must-re-read-locked-design lesson from today's closure-floor work, deferred-work-needs-durable-artifacts lesson from today's Codex re-review, and the existing voice-rule scope). Inline shell scripts extracted to `.scripts/release-publish.sh` for maintainability.

- **Voice rules generalized to user-facing scope** (CLAUDE.md § User-Facing Voice Rules) — Voice rules now apply to all user-facing artifacts (CHANGELOG entries, README user-facing prose, subcommand descriptions in `commands/`), not only CHANGELOG. Plain-English lead, define-before-use for project-internal vocabulary, no raw line refs, headline first. The release-time voice lint mechanically catches violations on the artifacts; the rule reads to a smart non-developer.

- **Layered-architecture references rewritten in plain English** (CHANGELOG and README) — Past CHANGELOG and README entries that referred to numbered enforcement layers without describing what each layer actually does have been rewritten to lead with the plain-English description. The numbered layer is parenthetical, not the headline.

- **Hooks integration reference aligned with 2026-04-30 audit findings** (`references/hooks-integration.md`) — Updated to reflect the empirical findings from the 2026-04-30 hook audit: PreToolUse, PostToolUse, UserPromptSubmit, and Stop fire reliably from skill frontmatter on Claude Code 2.1.123; matcher syntax must be literal tool name (not regex `.*` or pipe-alternation) for new registrations; hooks register on skill invocation, not file mtime; settings.json hot-swap is broken on this version.

- **Transcript-lint output shape change** (in `tests/lint-transcripts.sh`) — Output line changed from `across N file(s)` to `across N of M file(s)` to surface how many of the eligible files contained findings vs how many were scanned. Backward incompatibility with prior parsers is intentional — the new shape carries strictly more information. Downstream consumers should update to read both numbers.

### Not Shipped

- **SessionEnd evidence-capture hook** — The locked v5.15.0 design named SessionEnd as an optional last-gasp evidence capture (forensic snapshot to a durable file on session termination). Empirical verification of SessionEnd from skill frontmatter could not be completed within executor scope (the verification protocol requires multi-process orchestration: open separate terminal, invoke skill in fresh CC session, exit via `/exit`, repeat). Conservative default applied: SessionEnd hook NOT added to SKILL.md. Gap documented in `references/closure-floor.md` § "Why we do not ship a SessionEnd hook (as of v5.15.0)" with the manual protocol you can run to verify and ship in v5.16.0+. The handoff body's 8-group closure floor remains the canonical closure path; SessionEnd was always non-load-bearing.

- **Stop rule 6 (closure-walk-completeness)** — Originally scoped as an optional v5.15.0 component. Deferred to v5.16.0 because detection patterns require real `/handoff` transcripts in the new closure-floor format to inform robust pattern matching (none exist yet). Re-engagement triggered once ≥5 real handoff transcripts in the new format exist for empirical pattern matching.

- **Voice-quality compliance claim for SP chat** — v5.15.0 ships voice-related features (release-time voice lint extended to scan transcripts, identity-reset shared validator, dryness ban list documented in v5.14.0+) but does NOT claim that SP's chat across all sessions is jargon-free. Historical transcript lint runs find ~143 baseline voice violations in older sessions that predate v5.15.0 enforcement; new behavioral compliance is gradual, not an instant cutover. The features improve the situation; they don't certify it as solved.

## [5.14.0] - 2026-04-29

### Added

- **Typed Response Envelopes** — four-envelope response taxonomy (Conversational, Analytical, Packaged Prompt, Closure) maps response shape to appropriate formatting and visual density. Fence discriminator and Insight-block suppression rules included. Different envelopes get different formatting: low density for conversational acks, medium-high for analytical advisory turns, maximum for executor briefs, medium-high for closure handoffs.
- **Closure Evidence Ledger** — six-state ledger (RESOLVED / RESOLVED-AUTO / DECISION / SKIPPED-USER / SKIPPED-AUTO / DIRTY) replaces the prior 8-row Visual Closure Checklist. AUQ fires only on DECISION rows. Reconciles the SKILL.md hygiene-vs-decision boundary at category-vs-operation level.
- **Premise Challenge trigger #5** — fires when SP is acting on a derivative finding from a previous session (auto-fires on findings/backlog reads). Walk-through Scope Discipline subsection added separately.
- **V1–V7 regression fixtures + release-time transcript checker** — `tests/fixtures/v5.14.0/V1-V7-*.md` covering structural rule violations and friend-perspective jargon failures; `tests/lint-transcripts.sh` enforces AUQ-must-be-AUQ, tool-availability claims, and fence-write coupling rules against post-tag JSONL transcripts and SP-internal handoffs. RUNBOOK extended with manual-review procedure for fixture grading.
- **Voice-fix pass** — Define-Before-Use extended to all v5.14.0 SP-internal vocabulary (envelope names, ledger states, trigger numbers, the layered enforcement architecture); Plain-English Default rule renamed to Plain-English Whole-Response Gate with a concrete pre-send re-read mechanism named explicitly; eight-item dryness ban list added (covering jargon-laden tables, numbered-work-item framing in advisory chat, AUQ-as-ceremonial-padding, code-style spec framing in conversation, friend-perspective failures from V7 fixture, and more); warm partner tone made REQUIRED (folded into the existing rule, not a separate target); Anti-Sycophancy Protocol gains contrarian-theater symmetric failure mode; envelope-appropriate visual density principle named explicitly.

### Changed

- **CLAUDE.md release Step 2a** — hook verification expanded with matcher-scope tests, guard logic verification, runtime-input fuzzing, CHANGELOG cross-reference for env-var patterns, and the release-time transcript-checker backstop. Scoped to the source-edit guard (which predates v5.14.0) and the release-time transcript checker only — runtime enforcement was deferred.

### Fixed

- **`tests/lint-transcripts.sh:333` cwd encoding** — script was doing `tr '/' '-'` only; harness encoding also requires `tr '.' '-'`. Lint was silently scanning a non-existent path and finding zero transcripts. Fix mirrors the SKILL.md startup checklist's encoding pattern.

### Known Limitations (queued for v5.14.1)

- **Release-time lint over-flags meta-discussion** — `tests/lint-transcripts.sh` TOOL-CLAIM rule matches first-person tool-availability substrings inside transcript lines that *quote the lint's own patterns* or discuss its findings, rather than making live first-person tool-availability claims. Two known false positives surfaced in v5.14.0 development sessions during release verification. Fix queued for v5.14.1: add backtick-context awareness or sentence-context scoping to the TOOL-CLAIM matcher.
- **`tests/lint-transcripts.sh:597` integer expression warning** — script emits `0: integer expression expected` warnings during transcript scanning. Output is noisy but violation counts remain correct. Fix queued for v5.14.1.

### Deferred to v5.15.0

- **Runtime enforcement layer** (Stop hook + PostToolUse tracker) — prototyped during v5.14.0 development but pulled before release after a read-only mining of 105 JSONL transcripts (314 stop-hook-summary records inspected) found zero observable firings of the validator. Production observability was insufficient to verify the < 2% false-positive target the design called for. The source-edit guard (existing) and the release-time transcript checker are the only enforcement layers in v5.14.0. Runtime SP behavior is unchanged versus v5.13.0 except for the Theme A/C/D additions and the voice-fix improvements documented above. Runtime enforcement returns in v5.15.0+ once observability is in place.

## [5.13.0] - 2026-04-28

### Added

- **Plain-English Default section** (`SKILL.md`) — three subsections keeping SP's *voice* user-facing alongside Output Style's label translation. **Plain-English Opening Gate**: first 1–2 sentences of every response must be parseable by a non-technical reader; **Define-Before-Use**: project IDs (B-040, P1-002, §17, etc.) glossed on first mention, identifier as handle thereafter; **Housekeeping vs User Status**: SP-internal bookkeeping (memory writes, decision-log appends) no longer surfaces as user output.
- **Multi-Step Workflow Decomposition rule** (`SKILL.md` Core Advisory Loop) — when a path contains multiple discrete deliverables or transitions (write artifact → test → dispatch), pause and ask between each. Don't bundle "do task → return → next step → next step" into one response.
- **Token Efficiency Override** (`SKILL.md` Plain-English Default) — global `MODE_Token_Efficiency.md` style does NOT apply to SP user-facing prose unless explicitly invoked (`--uc`, `--ultracompressed`, or >75% context). Carves SP voice out of the global compression bias regardless of in-context examples.
- **Comprehension fixtures** (`tests/fixtures/v5.13.0/`) — five new fixtures (C1-C5) testing voice quality via reader-perspective Y/N criteria, complementing the existing label-pattern fixtures (F1-F5). C1: Plain-English Opening + glossing. C2: Housekeeping vs User Status. C3: Position + Greek + Visual Aids. C4: Multi-Step Workflow Decomposition. C5: Partner Profile General User Default. New `tests/RUNBOOK.md` section explains in-role grading procedure (reviewer reads SP's response as a non-technical user, answers Y/N criteria).

### Changed

- **Position First reframe** (`SKILL.md`) — Position line capped at one plain sentence readable in isolation. Rationale, trade-offs, and supporting detail go on subsequent lines, not crammed into the Position line itself.
- **Greek option labels banned** (`SKILL.md` Plain-English Default) — A/B/C only. The justification given for Greek labels (avoiding ordering implication) does not survive contact with users who don't read math; A/B/C is universally readable.
- **Visual aids default** (`SKILL.md` Communication and Consent) — replace previous "2-3 symbols max" rule with ASCII diagrams / tables / structured bullets as default for non-trivial responses (2+ options, flows, comparisons, status summaries). Emoji used as functional anchors (status, scanability), not decoration; no artificial symbol-count cap. Visual aids NOT used for trivial answers.
- **Bolding guidance** (`SKILL.md` Communication and Consent) — bolding is encouraged for key terms on first definition, the recommendation in a Position line, and decision points the user should focus on; not for whole sentences or whole paragraphs.
- **Partner-profile default** (`references/partner-protocols.md`) — default profile is now **General user / Product-minded user** (was: Engineer). Engineer/PM/Founder remain as profiles detected from user signals; the default — until signals emerge — leads with outcomes in plain English. Activation header and Profile Detection table updated to match.

## [5.12.0] - 2026-04-27

### Added
- **AUQ Materiality Gate** — SP now decides whether to surface a decision as an AskUserQuestion based on (a) whether it's your call and (b) whether it's actually material — meaning irreversible, high-cost, genuinely ambiguous, or explicitly flagged. Decisions resolved by canonical artifacts (CLAUDE.md rules, Serena memories, `.claude/rules/`) or owned by SP/executor terminate silently. AUQs fire at real partnership moments, not for SP-internal mechanics.
- **Attention Steward (Asking Pattern stage)** — A depth-modulation layer that tunes AUQ framing (must-ask vs. likely-ask vs. could-skip) based on signal strength. The right level of partnership friction for the situation.
- **Protocol-mandated AUQ whitelist** — 3 entries always emit AUQs regardless of gate outcome: Advisory Completion Gate, user-override checkpoint, and Codex review verdict synthesis. Whitelist extension requires version bump + CHANGELOG + regression fixture + Codex approval — preventing it from becoming a silent bypass.
- **Calendar-native routing prior** — When CLAUDE.md declares `project_type: calendar-native`, SP biases calendar-shaped decisions toward user-channel partnership AUQs (likely-ask depth) by default. The prior is overridden by user-authored standing rules in CLAUDE.md, Serena memories, or `.claude/rules/`.
- **F1-F5 regression fixtures** (`tests/fixtures/v5.12.0/`) — Five reproducible scenarios exercising each pipeline stage with PASS criteria. Includes `tests/RUNBOOK.md` for reviewer-driven manual validation.
- **Output Style mandate** (`references/pipeline/user-output-style.md`) — Canonical translation layer mapping internal pipeline vocabulary (Bootstrap/Router/Egress, channel names, materiality signal names, criteria labels) to plain English. Internal labels remain in SP's reasoning chains; user-visible output stays plain English.

### Changed
- **Premise Challenge format** — Trigger evaluation discipline preserved (still evaluates all 4 conditions internally on every task), but user-facing output uses plain prose ("You're starting with Redis — let me check the goal first") instead of `Triggers: #N fired` numbering.
- **Silent-log discipline** — When the SP resolves a decision without an AUQ, it no longer narrates the classification path in user-facing prose. Internal logging continues; user-facing surface stays focused on the substance.
- **Codex CLI references** — Updated from GPT-5.4 to GPT-5.5 following the 2026-04-23 release. README first-time-user flow patches applied per Codex review (`d733f40`).

### Fixed
- **SKILL.md pipeline heading** — Now matches the 4-stage diagram: `Bootstrap → Router → Egress → Asking Pattern`.
- **Pipeline frontmatter scope** (`references/pipeline/router.md`, `egress.md`) — Updated from "v5.12.0 minimal vertical slice (Brief 1)" to reflect the complete v5.12.0 specification.
- **`tests/RUNBOOK.md` init-prompt navigation** — Clarification that fresh SP orientation presents project-specific AUQs; reviewers should select "Type something" / freeform input to paste fixture transcripts cleanly.

## [5.11.0] - 2026-04-23

### Fixed
- **PreToolUse hook allow-list now matches relative paths** (hooks/guard-impl.sh + SKILL.md frontmatter inlined copy) — previously the case patterns required an absolute-path prefix (`*/.handoffs/*`), which blocked Write/Edit tool calls using relative paths against otherwise-allow-listed directories. The Fenced Prompt Emission Protocol (9c65b47) instructs writes to `.handoffs/last-prompts/[N].md` (relative) — the hook now correctly permits those. Added bare-form and relative-form patterns per allow-list entry. Bash and Serena guards were already correct; only Guard 1 needed the fix.
- **setup script now prunes stale symlinks** — previously setup only
  added missing symlinks but never removed orphaned ones. A stale
  `sync-skills.md` symlink (dating from pre-v5.2.1 removal of
  sync-skills) masked the self-repair count check and delayed
  discovery that `/strategic-partner:copy-prompt` had no registered
  symlink. Setup now prints `🧹 Removed stale symlink: {name}` when
  pruning.

### Added
- **/strategic-partner:copy-prompt subcommand** — copies a recently emitted fenced prompt to the OS clipboard, eliminating mouse-select friction on SP's primary handoff mechanism. Single-prompt direct copy; multi-prompt AskUserQuestion picker. Cross-OS clipboard via `pbcopy` / `xclip` / `xsel` / `clip.exe`.
- **Fenced Prompt Emission Protocol** (SKILL.md) — SP now writes each fenced prompt to `.handoffs/last-prompts/[N].md` at emission time so `copy-prompt` can retrieve them. Wipe-and-rewrite per response; no history.
- **Subcommand-Adding Briefs checklist** (references/prompt-crafting-guide.md)
  — new mandatory checklist for feature briefs that add subcommands:
  must include setup invocation, symlink verification, restart
  requirement note, and end-to-end invocation test as acceptance
  gates. Closes a process gap discovered during copy-prompt delivery.
- **Notify on Backgrounded Completion** (SKILL.md rule) — SP now fires a
  single PushNotification when any agent dispatched with
  `run_in_background: true` completes. Leads with verdict / headline
  finding (≤200 chars). Eliminates the walk-away dead zone during
  Codex reviews and other long-running dispatches. Fast Lane
  (foreground) dispatches explicitly do not notify.
- **README note on new subcommand discovery** — documents that users must restart their Claude Code session after running `./setup` (or `/strategic-partner:update`) to pick up new subcommands introduced by the release. Prevents confusion when upgrading to a version that adds commands like `/strategic-partner:copy-prompt`.

### Changed
- **Release process: mandatory Codex pre-release review** (CLAUDE.md Step 2b, commit 8829bb5) — codified as a gate equivalent to hook verification. Every non-docs-only push must pass `/strategic-partner:codex-feedback` Evidence Audit (Mode B) with the three mandatory questions (diff-matches-CHANGELOG, no-regressions-vs-prior-version, release-worthiness-per-user-segment) before the version bump is applied. Previously documented as optional dual-review guidance; now treated as mandatory release step.
- **Notify on Backgrounded Completion rule tightened** (SKILL.md) — replaced loose "≤200 chars" guidance with 4 explicit templates (`[<project>] SP — <event>: <detail>` shape), a 40–100 char target range, project-name derivation via `basename "$(git rev-parse --show-toplevel)"`, and an anti-pattern showing the failure mode (verbose comma-separated summary). Addresses user feedback that notifications were "messy and verbose" in real-world use.
- **Startup hygiene rules elevated to SKILL.md** — the no-echo-chain
  rule for git state commands (and similar compound commands) now lives
  in SKILL.md body with a concrete anti-example, not just
  `references/startup-checklist.md`. Reduces recurrence of the drift
  pattern where startup-checklist.md's rule was violated because the
  reference wasn't always loaded before orientation commands ran.
- **Serena memory reads clarified as on-demand default**
  (`references/startup-checklist.md`) — spec now documents deferred-
  read-on-demand as the approved default, with explicit always-read
  exceptions for `project_overview` and the most recent
  `decision_log` entries. Matches healthy session behavior and
  preserves token economy for long sessions.
- **Notify rule refined with "action, not process" principle** (SKILL.md) — new guidance at the top of the Message format templates block: lead with what the user needs to do, not what the tool did. Partial/timed-out dispatches report the effective outcome (e.g. "CONDITIONAL GO, 3 findings") rather than the process failure ("timed out at synthesis"). Includes a real anti-example from v5.11.0 prep.
- **commands/codex-feedback.md aligned with new Notify templates** — replaced the legacy "Codex review complete: {verdict} — {findings}" format with SKILL.md template #2 and resolved the foreground/background contradiction (was both; now consistently `run_in_background: true, mode: "acceptEdits"`).
- **SKILL.md Notify rule Step 3b no longer duplicates examples** — inline legacy examples removed in favor of a pointer to the authoritative "Message format (templates)" block in the same section.
- **copy-prompt now detects WSL and routes to clip.exe** (commands/copy-prompt.md) — WSL was previously treated as generic Linux (uname -s = Linux) and fell through to xclip/xsel, which are often absent on WSL. New detection: if `uname -r` contains `microsoft` or `WSL` (case-insensitive), use `clip.exe` via WSL interop.

## [5.10.0] - 2026-04-23

### Added
- **Fail-loud detection for native Windows Git Bash in `setup`** — On `$OSTYPE` matching `msys|cygwin|MINGW`, setup exits 2 with an experimental warning and WSL recommendation unless `SP_ALLOW_NATIVE_WINDOWS=1` is set. **Behavior change for existing Windows Git Bash users**: set `SP_ALLOW_NATIVE_WINDOWS=1` when running `bash setup` to acknowledge the experimental posture. Prevents silent degradation (symlinks → copies, broken install-dir resolution) on native Windows installs. WSL2 is the recommended Windows path.
- **Supported platforms matrix in README** — Clarifies macOS/Linux/WSL as fully supported; native Windows (Git Bash / MSYS2 / Cygwin) as experimental/best-effort; native cmd/PowerShell as unsupported.

### Fixed
- **H-3: Hook path normalization (conditional)** — Inline PreToolUse hook in SKILL.md frontmatter and `hooks/guard-impl.sh` normalize backslashes to forward-slashes ONLY for Windows-origin paths (drive-letter `C:\...` or UNC `\\...`). Unix paths, including those with literal backslashes in filenames, pass through unchanged. Preserves v5.9.0 semantics for Unix filenames; defensive against Windows `file_path` formats.
- **M-1: Python interpreter probe in `setup`** — Setup probes `python3` → `python` (with Python 3 version check) → `py -3` and uses the first that resolves. Allows `audit-permissions` to run on default Windows Python installations without requiring a `python3` alias.

### Changed
- **CLAUDE.md Step 2a hook verification extended** — Added items 4 (runtime-input fuzzing for hooks parsing JSON / env vars) and 5 (CHANGELOG cross-reference for `${CLAUDE_*}` env vars and path-resolution patterns) to the pre-release hook verification checklist. Codifies two preventive-action lessons from the v5.9.0 release review cycle. Originally landed as docs-only commit `8771c89` between v5.9.0 and this release.

### Context
Phase 1 of the Windows compatibility work from the 2026-04-22 cross-OS audit (`.handoffs/os-compatibility-audit-0422.md`, gitignored). Decision D (WSL-first + cheap hardening + fail-loud native detection) was selected via three-way synthesis (user + SP + Codex Decision Review on 2026-04-23). Pre-release Codex Evidence Audit + release-worthiness judgment returned CONDITIONAL GO on first pass; fixes applied (commits `a7b055b`, `b754636`); re-audit returned RELEASE-WORTHY + CONDITIONAL GO with conditions reduced to standard release-bump steps.

Deferred pending native-Windows demand evidence: H-1 (setup symlinks → file copies on Git Bash), H-2 (readlink -f cascade), GHA windows-latest CI matrix. Follow-up captured: `.backlog/hook-parser-fail-closed.md` — pre-existing fail-open behavior of the hook tool_name parser on pathological-whitespace JSON (not a regression from this release).

## [5.9.0] - 2026-04-21

### Removed
- **SessionStart hook from SKILL.md frontmatter** — Investigated and removed. The intent was to set `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` adaptively based on detected model. Anthropic's hooks documentation (https://code.claude.com/docs/en/hooks) states skill-frontmatter hooks "are scoped to the component's lifecycle and only run when that component is active" — and SessionStart fires at Claude Code session start, before any skill activates. Empirical test confirmed the hook never fires: a trace-log line added to the hook, a fresh session invoked, and `/tmp/sp-hook-trace.log` never appeared. The architecture is incompatible with the event, not a bug that can be patched.
- **Standalone `hooks/session-start.sh`** — Deleted. Was reference documentation for the now-removed inline hook; serves no purpose without it.

### Fixed
- **False precedent claim in `references/hooks-integration.md`** — The documentation previously stated that "gstack and other well-established skills use the same pattern" for SKILL.md frontmatter hooks. Empirically false: an audit of installed skills at `~/.claude/skills/` found that only strategic-partner had a `SessionStart:` block in SKILL.md frontmatter. gstack, the cited precedent, has no `hooks:` section at all. Rewritten to document the architectural incompatibility correctly, citing Anthropic's hooks documentation.
- **Stale adaptive-PCT claims in `references/context-handoff.md` and `references/startup-checklist.md`** — Both files previously described SP as setting `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` adaptively. Rewritten to reflect the correct reality: autocompact threshold configuration is entirely user-owned; the SP's role is informational only.
- **PreCompact section in `references/hooks-integration.md`** — Previously coupled to the (removed) SessionStart section with "how they cooperate" language. Rewritten as a standalone description of a user-owned hook users may optionally configure in their own `settings.json`. No user-facing shell commands or configuration walkthroughs.

### Added
- **Context Advisory for 1M-context sessions** — `startup-checklist.md` Step 5 orientation now surfaces a one-time informational note on 1M-context sessions (Opus 4.7): autocompact defaults to ~95% (~950K), upstream Anthropic 1M autocompact bugs (#34332, #42375, #43989, #50204) cause inconsistent behavior above ~256K, and users can consider wrapping up or triggering handoff around that threshold for reliable retrieval. Pure advisory — no settings changed, no commands recommended.
- **Closure Checklist (SKILL.md § Continuity Stewardship)** — New 8-row pass/fail table the SP displays before writing any handoff, verifying every persistence layer: Serena memories, CLAUDE.md proposals, session findings, backlog promotions, `.prompts/`, `.scripts/`, git state, `.handoffs/` file. Items marked "action needed" get addressed via `AskUserQuestion` before the handoff is finalized. Makes closure completeness auditable.
- **Auto-dispatch on session-end signals (SKILL.md § Context Handoff)** — New paragraph formalizing that when the SP detects session-end signals (explicit wrap-up keywords, periodic-awareness signals, or `/strategic-partner:handoff` invocation), it proactively runs the Closure Checklist → addresses gaps via `AskUserQuestion` → invokes the handoff protocol → runs Post-Handoff Verification. The SP does not wait for a separate user request after a session-end signal fires. User can decline any individual item, but the flow is auto-dispatched.
- **Post-Handoff Verification (SKILL.md § Context Handoff)** — New subsection with grep-based verification commands run after the handoff file is written: confirms the continuation prompt format is present, the `/strategic-partner` invocation is included, findings file exists (or absence was explicitly acknowledged), and all four session-work dirs are in `.gitignore`. If any check fails, surfaces the gap via `AskUserQuestion`.

### Context

This release consolidates v5.7.0 (intentionally skipped), v5.8.0 (Claude 4.x compatibility refresh, reusable prompt block library, model-aware generation — see v5.8.0 entry below), and v5.9.0 (SessionStart investigation + strip + closure hardening) into a single public release. The latest prior public release was v5.6.0 (2026-04-07); users updating from v5.6.0 receive the full delta.

The SessionStart investigation was adversarially reviewed via the `/strategic-partner:codex-feedback` subcommand (GPT-5.4 at xhigh effort) in two focused passes. The Part A review covered the v5.7/v5.8 committed work (Opus 4.7 refresh, block library, target-model detection). The Part B review covered this v5.9.0 uncommitted work (strip + advisory + closure hardening). The strip + advisory decision was informed by authoritative sources: Anthropic's hooks and env-vars documentation, verified lifecycle constraints, empirical testing of the hook, and the user's explicit UX preference that user-facing SP docs contain no shell commands or settings walkthroughs.

### Known limitations documented in release

- Anthropic's open 1M autocompact bugs (#34332, #42375, #43989, #50204) remain outside SP's control — the release documents them as context, not workarounds
- The `setup` script does not currently prune orphan command symlinks; the self-repair check detects mismatches but relies on `setup` to converge (pre-existing limitation, tracked for future release)
- Context-window detection for Opus 4.6 / Sonnet 4.6 is plan-dependent (200K default, 1M on Max/Team/Enterprise) — not applicable to current shipping SP paths since SP's advisory surface is 1M-only

## [5.8.0] - 2026-04-20

### Added
- **Reusable Prompt Block Library** — 7 Anthropic-authored XML blocks (`<investigate_before_answering>`, `<avoid_over_engineering>`, `<subagent_usage>`, `<use_parallel_tool_calls>`, `<conservative_actions>`, `<scope_explicit>`, `<context_awareness>`) codified in `references/prompt-crafting-guide.md`. Each block has a trigger condition and target-model note.
- **Template default blocks** — `assets/templates/prompt-template.md` now includes `<investigate_before_answering>` and `<avoid_over_engineering>` by default so every crafted prompt inherits hallucination prevention and scope discipline.
- **Model-aware block selection** — SP detects the currently active Claude model at startup and picks blocks + effort recommendations per target model (Opus 4.7 / Sonnet 4.6 / Haiku 4.5). Target can be overridden per prompt.
- **Opus 4.7 patterns subsection** — `references/provider-guides/anthropic.md` now documents Opus 4.7-specific patterns with pointers to relevant blocks.
- **13th Post-Craft Verification check** — "Relevant blocks included for target model/task." Ensures block coverage alongside existing quality gates.
- **Haiku 4.5 model ID** — `claude-haiku-4-5-20251001` now documented in the routing matrix.
- **Visible Post-Craft Checklist directive** — The checklist must be shown as a pass/fail table before the fence block, not inlined as invisible reasoning (Opus 4.7's "reasons more, tools less" tendency created audit risk). Fixed placement: checklist → 🎯 Routing blockquote → fenced prompt(s).
- **Mandatory git verification after dispatch** — `git log --oneline -3` and `git diff HEAD~1` are now explicitly mandatory Bash calls, not optional or inferred from commit messages.
- **`/context` sanity check note** — Startup flags known autocompact-on-1M-context bugs (anthropics/claude-code#34332, #18843, #27189) and recommends `/context` verification on Opus 4.7 sessions.

### Changed
- **Opus 4.6 → Opus 4.7 references** — Updated across `references/orchestration-playbook.md`, `references/prompt-crafting-guide.md`, `references/provider-guides/anthropic.md`, `assets/templates/prompt-template.md`, and `SKILL.md`. Sonnet 4.6 references preserved (still current GA).
- **Removed obsolete `/effort high` startup recommendation** — `/effort xhigh` is now Claude Code's default on Opus 4.7 plans, and Sonnet 4.6 defaults to `high` at the API level. Explicit recommendation was redundant.
- **Relabeled "Claude 3.x workarounds" → "pre-4.x holdovers"** — Anti-sycophancy rule is still relevant (more so on 4.7's direct tone); only the version label was outdated.
- **Renamed "Self-check verification blocks" → "Executor verification contract"** — Reflects what `<verification>` actually is (testable commands for the executor), not model self-reflection scaffolding.

### Demoted (not removed)
- **`<orchestration>` tag — mandatory → conditional** — Required only when subtasks are clearly independent, user explicitly requested multi-agent decomposition, or latency-hiding is primary goal. Opus 4.7's "fewer subagents by default" and "more literal instruction following" invalidated the always-on mandate.
- **Parallelization check — hard gate → thinking tool** — The 4-question check stays as a design-time thinking aid, but prompts no longer FAIL solely for lacking an `<orchestration>` section.

### Fixed
- **Orchestration-playbook consistency** — `references/orchestration-playbook.md` still described the parallelization check as "🔴 mandatory" after the v5.8.0 demotion. Now aligned with the thinking-tool framing and conditional `<orchestration>` criteria used in `prompt-crafting-guide.md` and the Anthropic provider guide.
- **Block-placement guidance** — `references/prompt-crafting-guide.md` "How to use this library" incorrectly pointed block authors to a nonexistent `<task>` section. Updated to match `<instructions>` (the actual template section) with BEFORE-instructions placement.
- **Visible-checklist placement rule** — Resolved contradiction between SKILL.md's "visible pass/fail table in the response" mandate and the crafting guide's "nothing outside the fences" rule. Explicit pre-fence order is now specified in both files: checklist table → 🎯 Routing blockquote → fenced prompt(s).

### Context
This release was produced via full audit (24 findings in `.handoffs/opus47-audit-0420.md`) + three-way synthesis (SP + Codex GPT-5.4 adversarial review + Anthropic primary-source research) in response to the Claude Opus 4.7 release on 2026-04-16.

The v5.7.0 tag was skipped intentionally — mid-audit the user correctly flagged that SP's crafting guide had drifted from Anthropic's published 4.x prompting guidance; expanding scope to address that gap produced v5.8.0. A final Codex adversarial review before tagging caught three internal inconsistencies that were fixed in the same release window (see Fixed section).

Kept intact: all identity gates (Position mandate, AskUserQuestion protocol, Premise Challenge, Advisory Completion Gate, cognitive patterns) and belt-and-suspenders rules (explicit model+mode on agent spawns). These are SP's product, not model compensation.

## [5.6.0] - 2026-04-08

### Added
- **Backlog stewardship** — two-layer system: lightweight session findings (.handoffs/findings-*.md) with automatic capture, and curated backlog (.backlog/*.md) with trigger-based surfacing at startup
- **Backlog subcommand** — `/strategic-partner:backlog` for reviewing parked items with type-grouped display and trigger evaluation
- **Bug awareness in backlog** — backlog items support `type: bug` with severity field and bug summary line in display

### Changed
- **Auto-capture redesign** — replaced language-detection heuristic with unconditional capture-first, triage-at-boundaries approach (Codex-recommended)
- **XML structural tags** — reference loading uses `<reference_files>`, `<gate>`, and `<load_reference>` tags for machine-parseability
- **Checkpoint 1 reconciled** — direct requests trigger "craft prompt"; feedback-shaped input routes to Immediate Reframe Rule

### Fixed
- **Inline XML prompts** — Anthropic-format prompts wrapped in backtick code fence to prevent Claude Code's markdown renderer from stripping XML tags
- **Codex CLI hangs** — `codex exec` now disables MCP servers (`-c 'mcp_servers={}'`) to prevent startup stalls
- **Cross-reference consistency** — 5 gaps resolved via Codex pre-release audit: allowed-paths prose, subcommand table, findings-to-backlog directive, wrapper terminology, Checkpoint 1 tension
- **Stale cadence reference** — removed "every 5th exchange" from context-handoff.md
- **Fence marker verification** — Post-Craft check #10 now catches missing 🟢/🛑 markers

## [5.5.0] - 2026-04-01

### Added
- **Permission audit** — `setup --audit-permissions` checks `~/.claude/settings.json` for SP-required permissions (3 mandatory, 9 recommended, defaultMode), detects redundancies, recommends deny entries based on tech stack scanning, and offers to apply with backup. Supports `--dry-run` and `--verbose` flags
- **Quick permission check** — setup now checks for Serena and Context7 permissions after command registration, with a one-line 💡 hint if missing

### Changed
- **Emoji severity hierarchy** — standardized three-tier system across all SP files: ❌ (error/failure), ⚠️ (warning/degraded), 💡 (suggestion/informational)
- **[✅ SAFE]/[⚠️ RISK] labels** — recommendation labels now include emoji for visual consistency. Updated in definitions, examples, and all prose references
- **WebFetch(*)/WebSearch(*) documentation** — updated to starred form in orchestration-playbook and README for audit consistency

### Fixed
- **skillshare → skills CLI** — replaced all `skillshare` references with Vercel `skills` CLI. Removed broken `npx skillshare install` from README
- **Stale hook reference** — SKILL.md guidance corrected to "inlined in SKILL.md frontmatter"
- **Hook verification in release process** — CLAUDE.md gains Step 2a for testing matcher scope and guard logic before release
- **Docs-only push exception** — CLAUDE.md release process allows docs-only pushes to skip version bump and GitHub Release

## [5.4.1] - 2026-03-31

### Fixed
- **Hook fires on every tool call** — matcher `""` changed to targeted `Edit|Write|MultiEdit|NotebookEdit|Bash|mcp__plugin_serena_serena__`. Hook no longer executes on Read, Glob, Grep, Skill, and other non-guarded tools.
- **Hook errors on non-default install paths** — guard logic inlined directly in SKILL.md frontmatter. Eliminates dependency on external `hooks/guard-impl.sh` path resolution. Works on any install path (skillshare default, git clone, alternate directories). `CLAUDE_SKILL_DIR` was not a real Claude Code variable; fallback path was fragile for distributed users.

## [5.4.0] - 2026-03-30

### Added
- **PreToolUse structural enforcement** — `hooks/guard-impl.sh` blocks Edit, Write, MultiEdit, and Bash file mutations on source files via harness-enforced exit code 2. Allowed paths: `.prompts/`, `.handoffs/`, `.scripts/`, `CLAUDE.md`, `CHANGELOG.md`, `README.md`, `SKILL.md`, `.claude/`, `.gitignore`
- **Immediate Reframe Rule** — when user provides implementation-shaped feedback, SP's first response is to craft a prompt or ask a clarifying question, not investigate the code
- **Guard 3 (Serena writes)** — blocks Serena code-editing tools (`replace_content`, `replace_symbol_body`, etc.) on source files while preserving full memory layer access
- **Debug mode** — set `SP_HOOK_DEBUG=1` to log hook decisions to `/tmp/sp-hook-debug.log`

### Changed
- **Override rewritten** — "implement yourself" → "dispatch to executor"; resolves the fundamental contradiction between "never implement" and "just do it yourself on small tasks"
- **Checkpoint expansion** — Checkpoint 1 (REQUEST) now catches implicit implementation triggers (bug reports, visual complaints, "looks wrong")

### Fixed
- **Hook tool name extraction** — was reading `CLAUDE_TOOL_NAME` env var (not set by Claude Code); now parses `tool_name` from stdin JSON payload
- **Hook path resolution** — `${CLAUDE_SKILL_DIR}` fallback added for environments where the variable isn't expanded

### Removed
- **"Trivial — Just run [X] directly" branch** — was the biggest identity escape hatch; all tasks now go through prompt crafting or agent dispatch
- **Self-waiver in prompt-crafting-guide** — "proceed directly" option replaced with prompt-only paths

## [5.3.0] - 2026-03-30

### Changed
- **Advisory identity restored as dominant force** — SKILL.md restructured from 1,139 lines to 762 lines with advisory-first section ordering; first 4 sections (38%) are purely advisory with no delivery mechanics
- **"Your default is advisory-only" → "You are not allowed to implement"** — boundary language changed from defeasible preference to present-tense prohibition
- **Primary deliverable redefined** — from "prompt crafting" to "decision-ready advisory brief"; prompts are secondary packaging
- **Cognitive patterns wired to decision points** — 14 patterns now have mandatory triggers and actions at specific decision points (was a decorative reference table); Reversibility Spectrum removed (duplicated One-Way Doors)
- **Fast Lane extracted to reference file** — mechanics moved to `references/fast-lane.md`; core SKILL.md keeps a 17-line stub that emphasizes "Dispatch, Not Identity"

### Added
- **Advisory Completion Gate** — hard gate with 5-point checklist (problem framed, alternatives explored, trade-offs surfaced, user confirmed, done defined) that must pass before ANY prompt, dispatch, or script is crafted
- **Advisory Reset After User Execution** — explicit identity recovery when user returns from implementation: "Back in advisory mode. I am reviewing the result, not continuing the build."
- **Post-Dispatch Identity Recovery** — explicit snap-back after Fast Lane agent returns: "Dispatch complete. I am back in strategic-partner mode."
- **Mission statement** — "Your mission is to slow the process down just enough to get it right"
- **`references/fast-lane.md`** — new reference file containing simplicity scoring, consent flows, dispatch protocol, and agent definition guidance
- **Advisory loop diagram** — Think → Challenge → Recommend → [Gate] → Package → Execute → Reset → Think

### Fixed
- **"brainstorm" appeared 0 times** in v5.2.1 SKILL.md — now appears 6 times with advisory vocabulary throughout
- **Implementation creep** — users reported SP jumping from brainstorming to prompt crafting mid-conversation and directly editing source code; the 3 new gates structurally prevent both failure modes
- **Persistence Router** — restored full 3-column table with Why column and specific Serena memory names
- **Anti-sycophancy gap** — restored missing banned phrase "I can see why you'd think that"

### Removed
- **~415 lines of implementation mechanics** from core SKILL.md (relocated to reference files or removed as dead code)
- **Reversibility Spectrum** cognitive pattern (duplicated One-Way Doors)
- **Partner Adaptation** subsection (soft/dead — no enforcement mechanism)
- **Non-enforceable cadence triggers** ("after EVERY exchange", "after every 5th exchange")

## [5.2.1] - 2026-03-30

### Fixed
- **AskUserQuestion compliance** — fixed self-contradicting prose question examples in Ask-Before-Act section, extended Response Completion Gate to cover mid-response questions, added open-ended AUQ pattern for clarification questions, added "user save request" persistence trigger for backlog/note/park directives
- **Version check reliability** — replaced background Agent E (WebFetch, intermittently blocked by sandbox permissions) with inline curl check that always works

### Removed
- **Agent E (background version check)** — replaced by inline curl in Step 1.5; agent overhead added fragility with no benefit for a single API call
- **`/strategic-partner:sync-skills` subcommand** — redundant after dynamic routing architecture replaced the static skill matrix

## [5.2.0] - 2026-03-30

### Changed
- **Dynamic routing architecture** — removed ~200 lines of hardcoded author-local skill mappings from routing matrix; replaced with dynamic discovery protocol that builds from each user's actual installed skills and agents at startup
- **Two-step consent model** — Fast Lane now uses Solution Ambiguity Gate: when Q1/Q2/Q3 indicate open solutions, SP presents solution options before delivery options; when solution is unambiguous, mandatory Position statement shows WHAT before asking HOW
- **Agent D return format** — now includes errors array and routing_status field for transparent partial-failure handling; orientation uses user-friendly language instead of "base + delta" jargon
- **Continuation re-confirmation** — when dispatch is planned in a continuation session, Q1 is re-confirmed via AskUserQuestion (handoff provides context, not consent)

### Added
- **Post-dispatch acceptance gate** — mandatory AskUserQuestion after both user-run and agent-run prompts before proposing next task
- **Solution Ambiguity Gate** — uses existing simplicity scoring Q1/Q2/Q3 to determine one-step vs two-step consent, proportional to solution openness
- **Fallback chain** for routing — Serena cached matrix → system context + task categories → built-in agents only

### Fixed
- **Orientation clarity** — removed internal "base/delta" jargon; environment summary now shows actionable status (built/cached/fallback)
- **Agent detection** — partial scan failures now reported with specific error context instead of silently returning 0

## [5.1.0] - 2026-03-29

### Added
- **`/strategic-partner:codex-feedback` subcommand** — Cross-model adversarial review via Codex CLI (GPT-5.4). Two modes: Decision Review (attack assumptions on a curated brief) and Evidence Audit (repo-aware claim verification with file:line citations). Includes trigger gate, anti-injection rule, three-way synthesis (User | SP | Codex), and 6-scenario failure handling
- **Codex CLI detection** — silent inline check at startup (Step 1.5); feature surfaces only when Codex is installed, never mentioned in orientation

### Fixed
- **Implementation Boundary renamed** — "Firewall" → "Boundary" for honest framing; boundary allows documented single-use override
- **AskUserQuestion contradiction resolved** — fresh sessions MUST use AskUserQuestion for Q1/Q4; continuation sessions verify from handoff
- **Auditable artifact markers** — mandatory grep-able format markers (`**Triggers:**`, `**Position:**`, `**Simplicity:**`) make protocol compliance verifiable in session transcripts
- **Mandatory simplicity scoring gate** — score marker required BEFORE presenting delivery options; delivery gate enforced by threshold (score ≤2/5 blocks dispatch)
- **Stop hook documentation cleaned** — removed false safety claims; replaced with "no automated backstop" in handoff reference
- **NOT-in-scope full specification** — definition, when-required rules, good/bad examples, identification guide added to prompt-crafting-guide.md

### Changed
- **README rewritten** — driven by cross-model evidence audit (Codex CLI / GPT-5.4); added executive summary, "Who is this for" section, accessible context dilution framing, all v5.0.0 features represented, file tree and subcommands updated for 6 commands

## [5.0.0] - 2026-03-29

### Changed (Breaking)
- **Delivery model restructured** — Agent C (dashboard fix, gitignore check, command symlinks), Step 1.5 (permission pre-flight), and `.claude/settings.json` hooks all replaced by an idempotent `setup` script following gstack's proven pattern
- **Memory Architecture restored** — unified 4-layer stewardship (CLAUDE.md, .claude/rules/, auto-memory, Serena) replaces the 2-layer system (Serena + CLAUDE.md only) that regressed during v3.4.0-v4.0.0

### Added
- **`setup` script** — idempotent bash script for command registration; runs on install and after every update; self-locating, portable across macOS/Linux
- **Count-based self-repair** — startup checks command count vs symlink count; auto-runs setup if mismatch detected (covers first install, updates, and removed commands)
- **Persistence Router** — decision table routing information to the correct layer (CLAUDE.md for rules, .claude/rules/ for path-scoped rules, auto-memory for user prefs, Serena for project knowledge)
- **Memory health checks** — startup verifies auto-memory enabled, .claude/rules/ scanned, CLAUDE.md size checked
- **.claude/rules/ protocol** — path-scoped rules with `paths:` frontmatter, migration guidance from bloated CLAUDE.md
- **Auto-memory awareness** — hands-off protocol; verify enabled, understand types, route correctly
- **Premise challenge triggers** — 4 trigger conditions on every task request; forced evaluation
- **Forced alternatives** — 3-path presentation (Minimal/Recommended/Lateral) before routing
- **NOT-in-scope sections** — explicit exclusions in multi-file prompts
- **[✅ SAFE]/[⚠️ RISK] labels** — confidence signals on non-trivial recommendations
- **Position-first rule** — state position before presenting options
- **Decision log enforcement** — auto-log after every confirmed AskUserQuestion

### Removed
- **Agent C** — replaced by `setup` script (install-time) + self-repair (startup)
- **Step 1.5 permission pre-flight** — no longer needed without Agent C
- **`.claude/settings.json` hooks** — Stop hook fires every turn, wrong mechanism for session-end detection
- **`hooks/check-handoff.sh`** — script deleted; behavioral protocol handles session-end detection

### Fixed
- **Graceful degradation** — removed vague "auto-memory files for persistence" promise; replaced with honest description of what each layer can/cannot replace
- **Stale Stop hook reference** — removed from handoff section after hook deletion

## [4.8.1] - 2026-03-26

### Fixed
- **Pre-Craft Discovery Protocol** — 4 mandatory questions (goal, prior work, constraints, definition of done) before routing to a skill; closes "asking the right questions" promise gap
- **Decision Log Protocol** — structured `decision_log` Serena memory format with entry schema, when-to-log/read rules, and archive strategy; closes "tracking decisions across sessions" promise gap
- **Prompt crafting pipeline updated** — Discovery Protocol added as Step 0 before Routing Decision Tree

## [4.8.0] - 2026-03-26

### Added
- **Anti-sycophancy protocol** — Communication Style expanded with 8 banned phrases, direct replacement alternatives table, 5 pushback patterns, position mandate, and partner adaptation rules
- **Cognitive patterns library** — new reference file (`references/cognitive-patterns.md`) with 15 named thinking heuristics across 4 categories: Decision Classification, Architecture Thinking, Strategic Thinking, Advisory-Specific
- **Two-level README review gate** — release process now distinguishes factual accuracy checks (every release) from first-time user tests (every 3rd minor or new user-facing features)

### Changed
- **README restructured** — information flow redesigned for first-time users (Problem → How → Show Me → Quick Start); core insight moved from buried in the middle to near the top; two-session model explained once instead of four times; file tree collapsed to `<details>` block; 268 lines, down from 382

## [4.7.0] - 2026-03-26

### Added
- **Permission pre-flight** — new startup step (1.5) detects missing permissions (`WebFetch *`, `Bash(ln -s *)`, `Bash(mkdir -p *)`) and proposes adding them via AskUserQuestion; one-time fix that persists across all sessions
- **Session-end mandatory handoff** — SP detects session-end signals ("done", "wrapping up", etc.) and triggers the full handoff protocol instead of summarizing and exiting; Stop hook serves as backstop

### Fixed
- **Agent C mode mismatch** — changed from `mode: "auto"` to `mode: "acceptEdits"`; uses Edit/Write for file modifications, Bash only for symlinks (covered by pre-flight permissions)
- **Agent E tool selection** — explicitly uses WebFetch for HTTP requests instead of Bash/curl; covered by pre-flight WebFetch permission
- **Orchestration playbook mode guidance** — mode decision tree now distinguishes read-only agents (`auto`) from config-writing agents (`acceptEdits`)

## [4.6.0] - 2026-03-26

### Added
- **Simplicity scoring model** — Fast Lane now uses a 5-question negative-test assessment instead of rigid file-count criteria; file count becomes a signal, not a gate
- **Agent definition file awareness** — SP checks for `.claude/agents/` definitions before dispatch, recommends creating them for recurring patterns; comparison table added to orchestration playbook
- **Provider-specific prompt format guides** — dedicated guides for Claude (XML), OpenAI (GPT-5.4), and Gemini (Markdown) extracted to `references/provider-guides/`
- **Copy-safe formatting rules** — inline prompts use XML + plain text only to survive markdown rendering on copy-paste
- **Delivery routing in pre-craft** — format selection and delivery routing integrated as mandatory pre-craft steps

### Changed
- **Fast Lane criteria** — replaced "≤2 files, single deliverable, mechanical, unambiguous, reversible" with simplicity scoring (5/5 = dispatch, ≤2/5 = full prompt)
- **Prompt-crafting guide refactored** — provider-specific format details extracted to dedicated guides, reducing main guide ~160 lines

### Fixed
- **README file tree** — added `references/provider-guides/` directory
- **README "What this is not"** — corrected "doesn't spawn agents" claim (Fast Lane dispatches agents)

## [4.5.0] - 2026-03-24

### Added
- **Fast Lane protocol** — three-lane delivery model for implementation prompts: small, mechanical tasks (≤2 files, single deliverable, unambiguous) can be dispatched to a sub-agent directly instead of requiring a copy-paste cycle to a new session
- **Delivery Decision step** in prompt-crafting-guide — gates whether a crafted prompt goes to agent dispatch, ══ fences, or direct user action
- **Post-Dispatch Review** — verification protocol for agent-dispatched tasks (git log, diff review, lesson extraction) with failure handling
- **"Fast lane for small tasks"** subsection in README explaining the three-lane model

### Fixed
- **Implementation Firewall** — "Two checkpoints" corrected to "Three checkpoints" (Checkpoint 3 existed but count was never updated)

### Changed
- **Implementation Firewall flow diagram** — now shows three lanes (LARGE → manual session, SMALL → agent dispatch, TRIVIAL → direct action) instead of single path
- **"No exception" text** — updated from absolute prohibition to reference the Fast Lane for qualifying tasks

## [4.4.1] - 2026-03-24

### Fixed
- **Hardcoded Serena config path** — replaced `~/.serena/serena_config.yml` with dynamic discovery chain (get_current_config → ~/.serena/ → ~/.config/serena/) in SKILL.md, startup-checklist, and orchestration-playbook
- **Hardcoded skill directory paths** — commands/handoff.md, sync-skills.md, and update.md now use `{skill-dir}` notation instead of `~/.claude/skills/strategic-partner/`
- **Hardcoded hooks config path** — hooks-integration.md updated from legacy `~/.claude/hooks.json` to `~/.claude/settings.json` with `$CLAUDE_CONFIG_DIR` fallback
- **Hardcoded companion script path** — uses `$SKILLSHARE_SCRIPTS_DIR` env var with fallback
- **README manual install** — now shows multiple location options instead of single hardcoded path

### Changed
- **Serena unavailable → firm recommendation** — graceful degradation no longer silently "notes in orientation"; now displays a firm, one-time recommendation explaining concrete capability losses (cross-session memory, semantic navigation, codebase structure model) with install link
- **Agent C dashboard check** — now uses Serena config discovery chain and reports `serena_not_detected` status when no config found

## [4.4.0] - 2026-03-24

### Added
- **Version check agent (Agent E)** — background startup check fetches latest GitHub release; shows one-liner in orientation if outdated
- **`/strategic-partner:update` subcommand** — checks version, shows changelog, detects install method (skillshare or git), runs update with confirmation
- **Commands distribution** — subcommand files now bundled in `commands/` directory and auto-linked to `~/.claude/commands/` via Agent C on first run
- **GitHub Releases step** — added step 7 to release process in CLAUDE.md; required for version-check system
- **`repo:` frontmatter field** — SKILL.md now declares the GitHub repo for version checks
- **"Staying updated" section in README** — documents automatic checks, update command, and GitHub Watch

### Changed
- **Agent C expanded** — now performs 3 checks: dashboard fix, gitignore, and commands symlink verification
- **Self-delegation list updated** — version check and commands check added to "always delegate" tier
- **Startup checklist** — Steps 2, 4, and 5 updated for Agent E integration

## [4.3.2] - 2026-03-24

### Added
- **Pattern E: Diagnostic Audit** — orchestration playbook now includes a formal audit protocol with 5-step intent-check gate (Chesterton's Fence principle) preventing ~30% false positive rate at Important+ severity

### Fixed
- **Cross-reference step number** — context-handoff.md referenced "Step 3" for env var setup; corrected to "Step 1"
- **Stale checklist count** — prompt-crafting-guide anti-patterns referenced "8-item checklist"; corrected to 9-item (format selection added in v4.2.0)
- **README loading description** — added "at startup" to reference file loading description (previously excluded startup-checklist from on-demand list)
- **/insights fallback alignment** — SKILL.md "no exceptions" softened to include manual fallback when /insights unavailable, aligning with existing template guidance

### Changed
- **Mode cross-reference** — skill-routing-matrix agent table now links to orchestration playbook's Agent Permission Modes section

## [4.3.1] - 2026-03-24

### Added
- **Failing prompt example** — prompt-crafting guide now includes Example 3 showing common mistakes with a failures table mapping each issue to the post-craft verification checklist
- **Rollback strategy section** — prompt template now includes a commented-out `<rollback>` section for changes that could regress existing behavior
- **Hybrid profile examples** — partner-protocols now includes a table of hybrid user profiles (Engineer-PM, Technical Founder, PM who codes)

### Fixed
- **README "Why two sessions?" deduplication** — collapsed redundant conclusion paragraphs into a single sentence; intro + table + one-liner now covers the argument without repetition
- **CHANGELOG "Checkpoint 3" phrasing** — renamed to "user override" for clarity without needing to read SKILL.md
- **README stale line count** — second reference to SKILL.md line count updated from ~440 to ~540

### Changed
- **Internal pattern separation** — orchestration playbook Patterns A-D now have an explicit "Internal patterns only" callout preventing confusion with Patterns 1-4 used in crafted prompts

## [4.3.0] - 2026-03-24

### Added
- **Agent permission mode guidance** — new "Agent Permission Modes" section in orchestration playbook with mode reference table, background agent warning, and decision tree for mode selection
- **Mode parameter on all agent patterns** — Patterns 1-4 (implementation) and Patterns A-D (self-delegation) now specify mode alongside model
- **Troubleshooting: sub-agent permission failures** — README now covers the scenario where background agents fail silently due to missing mode parameter

### Changed
- **Post-craft verification expanded** — item 5 now requires both explicit model AND mode on every agent spawn
- **Anti-patterns expanded** — both orchestration playbook and prompt-crafting guide now flag missing mode specification

## [4.2.0] - 2026-03-23

### Added
- **GPT-5.4 format support** — prompt-crafting guide now supports three target formats (Claude XML, GPT-5.4, Gemini) with a 3-target format decision tree
- **Agent failure and timeout handling** — orchestration playbook now covers failure modes, retry logic, and fallback paths for spawned agents
- **Serena memory updates field** — handoff template now includes a dedicated section for tracking which Serena memories need updating

### Fixed
- **Explicit routing matrix file paths** — prompt-crafting and orchestration guides now reference skill-routing-matrix.md by exact path
- **Environment-specific skill counts removed** — routing matrix and README no longer hardcode skill counts that vary by installation
- **Precision variance note** — companion-script-spec heuristics KB estimates now document ±20% variance
- **Local audit path removed** — implementation-decisions.md no longer references a local-only file path

### Changed
- **README adaptation claim softened** — removed unverifiable behavioral claims
- **README troubleshooting section added** — covers Serena, skills, hooks, and executor failure scenarios
- **SKILL.md line count updated** — README file tree description updated from ~440 to ~540 lines

## [4.1.0] - 2026-03-23

### Changed
- **Context management: removed strategic compact tier** — the SP no longer suggests `/compact`; context pressure is now managed exclusively via structured handoffs. Two-tier thresholds (🟢 0-60% normal, 🟡 60-70% monitor, 🔴 70%+ handoff) replace the previous three-tier system. Rationale: compaction produces lossy summaries that contradict the fresh-session philosophy
- **Routing matrix expanded from ~30 to ~87 entries** — 11 new categories added (Project Lifecycle, UI/Frontend, Workflow & Process, Git & DevOps, Content & Publishing, Configuration & Meta, Behavioral Modes, Recurring & Scheduled Tasks, Personal Automation). Base coverage increased from ~37% to ~95%
- **Agent subagent_types visually distinguished** — all Agent entries now prefixed with ⚙️ to prevent confusion with slash commands

### Fixed
- **Hook config examples labeled as signal stubs** — SessionStart and Stop hook configs now clearly marked as intentional signal stubs, not broken/incomplete hooks
- **Companion-script thresholds documented** — explicit 5% guard band delta between companion script and SP self-assessment thresholds now documented
- **PreCompact framing** — reframed as "system compacts regardless, SP's job is done" across all reference files

### Added
- **F6 reversal annotation** — v4.0-implementation-decisions.md F6 section annotated to note the compact tier was later removed
- **Gitignore entries** — `.handoffs/`, `.prompts/`, `.scripts/` added to .gitignore
- **README review step in release process** — project CLAUDE.md now mandates README content review during version bumps

## [4.0.1] - 2026-03-23

### Fixed
- **Saved-prompt launcher format** — added `══` fenced prompt launcher for saved `.prompts/` files, matching the inline prompt display convention
- **Implementation firewall user override** — one-time user override ("just do it") with mandatory reset to advisory mode after the single action completes
- **Handoff continuation prompt display** — enforced fenced display rules in SKILL.md core so they survive context pressure (not just in reference files)
- **Ask-before-act two-tier model** — hygiene ops (git, gitignore) execute autonomously, decision ops (Serena, CLAUDE.md, handoffs) always ask first
- **Bash echo-separator ban** — chaining commands with `echo "---"` separators triggers Claude Code's "quoted characters in flag names" safety warning; elevated to global "You always" rule requiring separate parallel Bash calls

### Added
- **Project CLAUDE.md** — release process definition ensuring version bump, changelog entry, and git tag on every push to remote

## [4.0.0] - 2026-03-16

### Post-Release Fixes (same day)

- **Routing matrix build step restored to startup** — v3.5.3 had an explicit startup checklist item ("Skill + MCP inventory → routing matrix built → stored in Serena") that was lost during the v4.0 restructure. Added Step 5.5 to `startup-checklist.md` with full delta-update procedure: load base matrix → scan system context skills → build delta entries for new skills → merge with custom agents → store in Serena
- **Hardcoded skill names removed from routing instructions** — `(e.g., /gsd:quick)` and `(e.g., /gsd:debug)` replaced with `(from routing matrix)` / `(look up in routing matrix)` placeholders in SKILL.md heuristics table and prompt-crafting-guide.md decision tree. Restores the v3.5.2 fix that prevented anchoring bias. Concrete skill names remain only in the curated base matrix (their correct location)
- **Anti-pattern warnings rewritten** — removed specific skill names from "don't do this" warnings in prompt-crafting-guide.md to avoid negation-by-example reinforcement
- **Core SP behaviors restored after over-trimming** — Self-Delegation Principle, 10-point prompt quality list, ══ fence format, Ask-Before-Act examples, Communication Style details, and Post-Prompt report-back steps restored to SKILL.md core after gap analysis showed they were removed during initial lean hub restructure

### Critical Fixes

- **F1: Context monitoring env var baseline** — set `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=70` at startup to lower auto-compaction trigger from ~95% to 70%, giving the PreCompact hook a reliable system signal instead of unreliable self-assessment
- **F4: Mandatory parallelization check** — 4-question checklist required before writing any prompt; if Q1-3 answer YES and prompt lacks `<orchestration>`, the prompt fails the quality gate
- **F4: Routing decision tree** — replaced flat matrix lookup with structured scope + complexity tree that must be walked before selecting a skill
- **F4: Post-craft self-verification** — 8-item mandatory checklist after writing any prompt; all items must pass before presenting
- **F9: Fire-and-verify pattern** — replaced silent fire-and-forget agents with fire-and-verify; Agent C (dashboard fix + gitignore check) verified before orientation; gitignore failure triggers immediate user warning (security concern)

### High Improvements

- **F2: Progressive session naming** — lifecycle from `sp-init-MMDD` to `sp-[topic]-MMDD` to `sp-[refined]-MMDD`; treated as identity management (no ask-before-act)
- **F3: Hooks integration** — new `references/hooks-integration.md` with phased rollout: Phase 1 (SessionStart, PreCompact, Stop), Phase 2 (SubagentStart/Stop, PostToolUse, UserPromptSubmit), Phase 3 (ConfigChange, PostToolUseFailure, custom hooks)
- **F5: Effort/color identity** — `/effort high` + `/color red` set unconditionally at startup Step 1 for full reasoning power and visual advisory identity
- **F6: /compact guardrailed protocol** — replaced absolute `/compact` ban with guardrailed protocol; bare `/compact` still prohibited; strategic compaction with mandatory focus instructions allowed at 65-72% context via AskUserQuestion

### Medium Enhancements

- **F7: Custom agent discovery** — startup scans `.claude/agents/` and `~/.claude/agents/` for user-defined agents to include in routing matrix
- **F7: Worktree isolation** — new section in orchestration-playbook.md for recommending `isolation: worktree` on risky implementations
- **F8: /insights integration** — run `/insights` before every handoff; dedicated section added to handoff template capturing project areas, patterns, friction points
- **F10: Curated base matrix** — skill-routing-matrix.md ships ~30 pre-mapped skills across 7 categories; delta-update procedure builds entries only for NEW/unknown skills (~80% startup cost reduction)
- **F11: Lean hub architecture** — SKILL.md restructured from ~700 lines to ~440 lines (41% reduction); procedural content moved to lazy-loaded reference files while retaining all core behaviors (Serena edge cases, Git Custody, Self-Delegation, prompt quality list) inline

### Low Additions

- **F12: /fork and /btw awareness** — documented as available native features in partner-protocols.md (mention only, no formal protocols)
- **F1: Companion script spec** — new `references/companion-script-spec.md` with full Python monitor architecture for power users wanting external context tracking

### Added

- `references/hooks-integration.md` — comprehensive hooks strategy with JSON configs and phased rollout
- `references/companion-script-spec.md` — Python context monitor architecture specification
- `docs/v4.0-implementation-decisions.md` — full decision log for all 12 audit findings
- Curated base routing matrix with ~30 pre-mapped skills in `skill-routing-matrix.md`
- Parallelization heuristics with concrete examples (when to parallelize vs when not) in `orchestration-playbook.md`
- Model selection cost-effectiveness guidance (Opus for coordinators/synthesis, Sonnet for parallel workers)

### Changed

- SKILL.md restructured as lean hub (~440 lines) with core behaviors inline and reference dispatch table
- Version bumped from 3.5.3 to 4.0.0
- Context handoff thresholds updated: 50-65% no action, 65-72% strategic compact, 72%+ full handoff
- Fire-and-forget agents replaced with fire-and-verify pattern throughout
- `/compact` ban replaced with guardrailed protocol (focus instructions mandatory)
- Startup sequence expanded: identity commands (Step 1), progressive naming (Step 2), env var (Step 3), fire-and-verify agents (Step 4), state reading (Step 5), verification gate (Step 6), orientation (Step 7)
- Reference files table expanded from 6 to 8 entries (hooks-integration.md, companion-script-spec.md)
- Handoff template updated with `/insights Analysis` section
- Prompt crafting guide: routing decision tree, parallelization check, and post-craft verification are now mandatory gates (not optional guidance)
- Orchestration playbook: added worktree isolation, concrete parallelization examples, anti-examples

### Removed

- Absolute `/compact` ban (replaced with guardrailed protocol)
- Fire-and-forget agent pattern (replaced with fire-and-verify)
- Context self-assessment as sole monitoring mechanism (supplemented with env var + hooks)

## [3.5.3] - 2026-03-05

### Added
- **Version badge in README.md** — shields.io badge linking to CHANGELOG for instant version visibility on GitHub
- **Git tags for release history** — first tagged release (`v3.5.3`); prior versions remain file-based only

### Fixed
- **Split-brain in post-prompt protocol** — `prompt-crafting-guide.md` had a condensed "verify > review > assess > plan next" summary that omitted the full 5-step report-back checklist from SKILL.md. Expanded to include all 5 steps (Verify, Review, Assess, Extract, Then propose next) so both files carry identical protocol detail

## [3.5.2] - 2026-03-05

### Added
- **Post-Prompt Protocol: Wait for Report Back** — mandatory behavioral section in SKILL.md enforcing the partnership loop. After delivering a fenced prompt, the SP must STOP and wait for the user to report back before offering next steps. Includes ASCII flow diagram, report-back review checklist, and explicit anti-pattern callout
- **Routing rationale line (`> 🎯 Routing:`)** — mandatory one-liner BEFORE every fenced prompt explaining why the chosen skill was selected (or why no skill was needed). Educates the user on SP routing decisions so they learn to anticipate which tools fit which tasks
- Routing rationale added to all 3 prompt format templates (inline, launcher, script) in both SKILL.md and prompt-crafting-guide.md — using generic placeholders, not hardcoded skill names
- New rule in fence format rules: routing rationale is mandatory before fences
- Two new anti-patterns in prompt-crafting-guide.md: "Missing routing rationale" and "Premature what's next?"
- **Fire-and-forget block in BOTH Step 2a and Step 2b** — Serena dashboard fix and .gitignore auto-add now explicitly listed in both continuation AND initialization PARALLEL blocks. Previously only referenced in the internal checklist, causing the dashboard fix to be missed in continuation mode

### Fixed
- **Partnership loop broken** — SP was presenting prompts then immediately offering "What's next?" menus instead of waiting for user to execute and report back. Root cause: no explicit stop instruction after prompt delivery. The Post-Prompt Protocol now enforces the wait
- **Dashboard fix skipped in continuation mode** — `web_dashboard_open_on_launch` auto-fix was only implicitly referenced via the internal startup checklist, not woven into the Step 2a/2b PARALLEL blocks. Now explicit in both modes
- **Hardcoded skill names in routing rationale examples** — removed `/sc:implement`, `/feature-dev`, `/gsd:quick` from template examples to prevent anchoring bias. Rationale examples now use `[skill-from-routing-matrix]` placeholder, forcing the model to consult the actual routing matrix every time

## [3.5.1] - 2026-03-05

### Added
- **Summary flows at top of all 6 reference files** — single-line ASCII arrow chains for instant orientation before diving into detail
- **❌ anti-pattern prefixes** in prompt-crafting-guide (17 items) and orchestration-playbook (11 items) for instant visual "don't do this" signal
- **`---` dividers between spawn patterns** in orchestration-playbook for cleaner visual separation
- **Git custody verification flow** — replaced prose list with branching ASCII diagram in SKILL.md
- **Version bump decision tree** in partner-protocols using `├─ Yes / └─ No` pattern
- **`startup-checklist.md`** added to SKILL.md Reference Files table (was orphaned)
- **Pending Scripts section** added to handoff-template.md (was missing, causing script references to be lost during handoffs)

### Fixed
- **`.gitignore` handling contradiction** — handoff subcommand said "ask before modifying" while context-handoff.md and SKILL.md said "auto-add silently". Aligned all files to auto-add (enforced guardrail, not discretionary)
- **Stale "Step 0" and "Step 1.5" references** in status.md and sync-skills.md — these steps were removed in v3.3.0 but references survived. Now removed
- **Prompt quality requirements numbering** — reference guide order now matches SKILL.md canonical order (model spec is #6 in both)
- **Anti-pattern format divergence** — orchestration-playbook now uses bold labels matching prompt-crafting-guide style

## [3.5.0] - 2026-03-05

### Added
- **Subagent delegation for context preservation** — SP delegates mechanical scanning to Explore agents during startup, keeping main context free for strategic reasoning
- **Parallel startup patterns** — initialization and continuation modes both spawn background agents for staleness checks and docs scanning
- **Fire-and-forget operations** — Serena dashboard fix and .gitignore auto-add run without waiting for results
- **Pre-prompt file delegation** — agent reads 3+ files and returns structured summary before SP crafts prompt
- **Self-Delegation Principle section** — explicit rules for what to delegate vs keep in main context
- **Delegation Decision Rules** — 4-question decision tree for routing work to agents vs doing it directly
- **Agent prompt templates** in orchestration-playbook (Patterns A/B/C/D) for consistent agent spawning

### Changed
- Startup sequence now spawns parallel agents alongside main SP work
- Orchestration playbook expanded with advisor-specific delegation patterns (distinct from implementation patterns)

## [3.4.0] - 2026-03-05

### Added
- **Graceful degradation section** — explicit fallback behavior for Serena unavailable, user declining separate sessions, and minimal skill inventory
- **Runtime routing matrix** — matrix is now built at startup from system context, stored in Serena memory, and diffed on subsequent sessions
- **Context measurement caveat** — documented that self-assessed context % can be off by 5–10%, recommending early handoff bias
- **Skill validation instruction** — prompt crafting now requires verifying skills exist in system context before recommending them
- **`references/partner-protocols.md`** — new reference file for version bump ownership and partner adaptation protocols
- **Expanded description triggers** — frontmatter now includes natural-language phrases ("plan my project", "advise on architecture", etc.)

### Changed
- **Routing matrix portability overhaul** — replaced 26-entry hardcoded inline matrix with universal layer (Agent subtypes + model heuristics + MCP rules + composition patterns)
- **`references/skill-routing-matrix.md`** rewritten as template/example format with auto-generation procedure; removed all hardcoded skill entries and project-local (`jimmy:*`) entries
- **Power Combinations** rewritten as abstract composition patterns ("Explore → Design → Build → Review") instead of hardcoded skill chains; SP fills in concrete skills at runtime
- **`/strategic-partner:sync-skills`** now rebuilds Serena routing matrix from system context and shows diff against previous matrix (was: scan-and-flag)
- **Version Bump Ownership** (Responsibility §7) compressed to 3-line summary + pointer to reference file (was: 15 lines inline)
- **Partner Adaptation** compressed to 3-line summary + pointer to reference file (was: 10 lines + table inline)
- **Reference Files table** updated with new `partner-protocols.md` entry and revised `skill-routing-matrix.md` description
- **Startup checklist** updated with routing matrix build step

### Removed
- 60+ hardcoded skill entries from `skill-routing-matrix.md`
- Project-local skill section (`jimmy:*` entries)
- "Last synced" tracking in routing matrix (no longer relevant — matrix is auto-built)
- Hardcoded skill names in Power Combinations section

## [3.3.0] - 2026-03-05

### Added
- **Git state capture at startup** — branch, uncommitted changes, ahead/behind captured before orientation
- **Post-implementation commit verification** — SP verifies commits landed after user reports back from implementation sessions
- **Partner adaptation** — Engineer/PM/Exec profile detection with concrete adaptation guidance per audience
- **Response structure standard** — status briefings, analysis templates, diagram format selection, symbol discipline
- **Git state in handoff template** — branch, status, ahead/behind, last commit now preserved across sessions
- **Target branch requirement** — implementation prompts now specify the branch in `<context>` section

### Changed
- **Hybrid rewrite** — merged old version's lean body structure with v3.2.0's genuinely valuable features
- SKILL.md body reduced from 708 → 517 lines (-27%) while retaining all capabilities
- Inline skill routing matrix restored (26 core tasks + MCP routing always in context, no startup file loading)
- Startup simplified from 6 steps to 2 steps + git state capture
- Removed ecosystem registry bootstrap (system context already provides full inventory)
- Removed Step 0 upgrade detection (unnecessary startup complexity)
- Removed Six Pillars conceptual framework (behaviors preserved without the naming layer)
- Merged `mcp-routing-matrix.md` into `skill-routing-matrix.md` (one file, not two)
- Simplified `startup-checklist.md` to supplementary detail only (body IS the checklist now)
- Ask-before-act examples restored inline (moved back from ref file for always-available access)
- Reference files now loaded on-demand only (zero ref files loaded at startup vs 2 before)
- Estimated context savings: ~2,900 tokens per session (~1.5% of context window)

### Removed
- `references/mcp-routing-matrix.md` — merged into skill-routing-matrix.md
- Ecosystem registry Serena memory pattern — replaced with direct system context reading
- Count-based diff at startup — removed with ecosystem registry

## [3.2.0] - 2026-03-04

### Added
- **Tiered context handoff** — three escalation levels (67% gentle, 72% strong, 77% urgent) replace the old 70/75/85 thresholds that rarely triggered in practice
- **Script generation** — SP now generates runnable `.scripts/*.sh` for deterministic terminal tasks (config edits, installs, setup) alongside `.prompts/` for AI-judgment tasks
- **Deliverable type routing** — decision tree in prompt-crafting-guide to route between scripts, prompts, or both based on task characteristics
- **Script quality standards** — `set -euo pipefail`, pre-flight checks, progress output, idempotent operations
- **RUN-IN-TERMINAL display block** — parallel to the existing COPY-INTO-NEW-SESSION launcher format

### Changed
- Context check cadence tightened from "every 3rd exchange" to "every 2nd exchange after 60%"
- 67% tier is now **visible** to user (inline note) — old 70% "soft trigger" was invisible (internal prep only)
- 77% tier executes handoff immediately — no permission needed, only topic-slug confirmation
- Implementation Firewall now allows `.scripts/` alongside `.handoffs/` and `.prompts/`
- Handoff split-writes now capture pending scripts in addition to prompts
- Continuation prompt template includes "Pending Scripts" section

### Fixed
- Threshold discrepancy between handoff subcommand (60/75/85) and SKILL.md (70/75/85) — unified to 67/72/77
- Stale 70% reference in orchestration-playbook.md

## [3.1.0] - 2026-03-03

### Added
- Initial published release
- Full advisor persona with implementation firewall
- Engagement protocol with mandatory AskUserQuestion
- Seven responsibilities (strategic oversight, CLAUDE.md ownership, Serena memory management, git custody, prompt crafting, context handoff, version bump)
- Six pillars (Claude Code mastery, proactive intelligence, ecosystem awareness, prompt engine, orchestration playbook, continuous improvement)
- Four subcommands (help, sync-skills, handoff, status)
- Reference files: skill-routing-matrix, mcp-routing-matrix, context-handoff, orchestration-playbook, prompt-crafting-guide, startup-checklist
- Cross-agent compatibility (Claude Code, Cursor, Gemini CLI, Windsurf, Codex)
