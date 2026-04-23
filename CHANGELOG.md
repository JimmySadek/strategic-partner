# Changelog

## [Unreleased]

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
- **Stale hook reference** — SKILL.md line 107 corrected to "inlined in SKILL.md frontmatter"
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
- **README restructured** — information flow redesigned for first-time users (Problem → How → Show Me → Quick Start); core insight moved from line 126 to line 15; two-session model explained once instead of four times; file tree collapsed to `<details>` block; 268 lines, down from 382

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
