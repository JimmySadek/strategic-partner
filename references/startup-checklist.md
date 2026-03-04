# Startup Checklist (Internal)

Reference file for the strategic-partner advisor. Complete before declaring ready.
Do not display this checklist to the user.

---

## Pre-Orientation Checks

- [ ] **Step 0 — Upgrade detection** (skip if `advisor_project_setup` memory exists)
  - `.handoffs/` exists → check for `.prompts/`
  - Mixed content in `.handoffs/` → offer categorization
  - `.prompts/` missing from `.gitignore` → flag
- [ ] **Step 1 — Mode detected** (initialization vs. continuation)
- [ ] **Step 2 — Ecosystem Registry Bootstrap**
  - Scan system context for: skills, MCPs, agent types, hooks
  - Read `references/skill-routing-matrix.md` + `references/mcp-routing-matrix.md`
  - Compare live inventory vs. matrices → flag uncatalogued/unavailable
  - Read or create Serena memory `ecosystem_registry`:
    - First time → create full registry (models, skills, MCPs, agent types, hooks)
    - Existing → validate 3 key entries:
      1. Pick 1 random skill from registry → verify in system context
      2. Pick 1 MCP → verify available
      3. Pick 1 agent type → verify in Agent tool options
    - Flag any changes to user in orientation question
- [ ] **Serena session protocol**:
  - `check_onboarding_performed` → onboard if needed
  - `list_memories` → read 2–3 most relevant
  - Staleness validation (concrete):
    1. Pick 2 file paths from `codebase_structure` memory → verify with `find_file`
    2. Pick 1 convention from `code_style_and_conventions` memory → verify with `search_for_pattern`
    3. If any fail → flag immediately, propose targeted memory update
- [ ] **CLAUDE.md read** — conventions and constraints noted
- [ ] **Partner profile check**:
  - Does Serena memory `partner_profile` exist?
  - If yes → read and adapt communication depth
  - If no → observe during session, write after 3+ exchanges
- [ ] **Handoff file read** (if continuation mode)
- [ ] **`.prompts/` check** — directory exists, in `.gitignore`
- [ ] **Versioning check** — scan for `VERSION`, `package.json`, `pyproject.toml`, release scripts

---

## Post-Orientation Checks

- [ ] `AskUserQuestion` prepared with orientation
- [ ] Implementation firewall active (contextual self-check protocol)
- [ ] Context monitor active:
  - 70% → soft trigger (prepare state summary)
  - 75% → hard trigger (propose handoff)
  - 85% → emergency (execute immediately)
  - Check cadence: after major deliverable, before new analysis, every 3rd exchange
  - NEVER recommend `/compact` — compaction is safety net only

---

## Serena Memory Monitoring

### When to Propose Memory Writes
- New convention or process agreed in conversation
- Architectural decision made with rationale
- Significant gotcha or lesson learned discovered
- Threshold values calibrated and confirmed
- Ecosystem change detected (new skill, MCP, or hook)

### When to Propose Re-Onboarding
- Memory references files/directories that no longer exist
- Memory describes module structure contradicting actual codebase
- Major architectural reorganization since last onboarding
- Memory content is internally inconsistent
- Ecosystem registry severely stale (>50% entries outdated)
- User explicitly says "memories are wrong" or "re-onboard"

### Re-Onboarding Protocol
1. Never re-onboard autonomously — it overwrites existing memories
2. AskUserQuestion: describe inconsistency + propose re-onboarding with rationale
3. Options: [Yes, re-onboard now] [Let me fix specific memories instead] [Keep going]
4. If confirmed: `onboarding` call refreshes codebase analysis and memories

---

## CLAUDE.md Monitoring Triggers

Propose an update when:
- A new convention or process is agreed upon in conversation
- A "lessons learned" emerges from an implementation report
- An architectural decision is made that should constrain future sessions
- A rule is being violated repeatedly (suggests missing guardrail)
- Version bump process is established or changed

Protocol:
- AskUserQuestion with: what to add, which section, exact proposed text, rationale
- Wait for confirmation before editing

---

## Memory vs. CLAUDE.md vs. Registry Decision

```
Serena memories     → architectural decisions, codebase structure, code conventions,
                      threshold values, known gotchas, design rationale
CLAUDE.md           → process rules, enforcement conventions, project-wide guardrails
.claude/rules/      → path-specific rules (e.g., "all files in src/api/ must...")
Auto-memory         → session learnings, user preferences (auto-managed)
ecosystem_registry  → skills, MCPs, agent types, hooks (SP-managed)
.handoffs/          → current session state, continuation prompts
.prompts/           → implementation prompts organized by milestone
```
