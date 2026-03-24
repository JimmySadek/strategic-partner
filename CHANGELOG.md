# Changelog

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
