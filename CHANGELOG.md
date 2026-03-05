# Changelog

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
