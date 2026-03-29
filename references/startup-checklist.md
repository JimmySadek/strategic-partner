# 🚀 Startup Checklist (Internal)

Reference file for the strategic-partner advisor. Full startup sequence with
identity setup, environment configuration, and fire-and-verify agents.
Do not display to user.

```
┌──────────────────────────────────────────────────────────────────────────┐
│  SP Startup Flow                                                          │
│                                                                           │
│  Step 1          Step 2          Step 3       Step 4                    │
│  Env Vars  →  Spawn Agents  → Read State → Verify                      │
│  AUTOCOMPACT    ┌─ Agent A     $ARGUMENTS    ✅ Agent D                 │
│  _PCT=70       ├─ Agent B     Serena         ⚡ Agent E                │
│                ├─ Agent D     CLAUDE.md           │                     │
│                └─ Agent E          │              │                     │
│                  🗺️ Matrix          │              ▼                     │
│                     │              │         Step 5                     │
│                     └──────────────┘         📋 Orient                  │
│                                              + Setup recs               │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 🔧 Step 1: Environment Configuration

Set environment variables that affect session behavior.

```
CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=70
```

**Purpose**: Lowers the auto-compaction trigger from the default (~95%) to 70%.
This gives the PreCompact hook a **reliable signal** at 70% instead of the SP
guessing its own context consumption.

```
┌──────────────────────────────────────────────┐
│  Default:   compaction at ~95% → too late     │
│  Override:  compaction at  70% → time to act  │
│                                               │
│  70% trigger → PreCompact hook fires          │
│             → SP intercepts for handoff prep  │
│             → session state preserved         │
└──────────────────────────────────────────────┘
```

📎 See `context-handoff.md` for the full threshold strategy
📎 See `hooks-integration.md` for PreCompact hook behavior

---

## 🔧 Step 1.5: Self-Repair Check

Before spawning agents, verify command registration is intact. This is a count-based
inline Bash check (not an agent) — it runs in ~15ms when everything is in sync.

```
CMD_COUNT=$(ls "${CLAUDE_SKILL_DIR}/commands/"*.md 2>/dev/null | wc -l | tr -d ' ')
LINK_COUNT=$(ls "${HOME}/.claude/commands/strategic-partner/"*.md 2>/dev/null | wc -l | tr -d ' ')
[ "$CMD_COUNT" = "$LINK_COUNT" ] || bash "${CLAUDE_SKILL_DIR}/setup"
```

The count-based check catches first install (no symlinks), updates that add new
commands, and removed commands — not just the existence of a single symlink.

If the check triggers setup, note it briefly in orientation:
"🔧 First-run setup complete — subcommands registered."

This replaces the old Agent C approach (removed in v4.9). The setup script is
idempotent and handles its own legacy cleanup warnings.

### Memory Health Check (inline, not an agent)

Quick checks run inline during startup. No agents needed — these are observations.

1. **Auto-memory**: Check if auto-memory is enabled (it is by default).
   If the user has disabled it, note in orientation:
   "⚠️ Auto-memory is disabled. User preferences and corrections won't persist
   across sessions. Consider enabling via /memory."
   Detection: the SP can observe whether auto-memory writes are happening
   during the session. No settings file check needed — if Claude isn't
   saving memories, it's likely disabled.

2. **Serena**: Existing check (`check_onboarding_performed`). Already in Step 2.

3. **.claude/rules/**: Check if `.claude/rules/` directory exists in the project.
   If it exists, note in orientation: "{N} path-scoped rule files found."
   If it doesn't exist, don't mention it — it's optional.

4. **CLAUDE.md size**: If CLAUDE.md exceeds ~200 lines, note in orientation:
   "⚠️ CLAUDE.md is {N} lines (recommended: under 200). Consider splitting
   path-specific rules into .claude/rules/ files."

### Codex CLI Detection (inline, not an agent)

```
which codex >/dev/null 2>&1
  ├─ Found → Set internal flag: codex_available = true
  │         Do NOT mention in orientation output
  │         SP may offer reviews at trigger points (see /strategic-partner:codex-feedback)
  └─ Not found → codex_available = false
                 Feature never surfaces. Totally silent.
                 Only educates if user explicitly invokes the subcommand.
```

---

## 🤖 Step 2: Spawn Background Agents (Fire-and-Verify)

Spawn these agents **in parallel**. All agents are read-only and use
`mode: "auto"`. Background agents **cannot prompt the user for permissions**,
so explicit mode selection is required to auto-approve operations without blocking.

### Agent A: 🔍 Staleness Check (mode: "auto")

Validates that Serena memories match the actual codebase.

**What it does** (see `orchestration-playbook.md`, Pattern A/B):
1. Pick 2 file paths from `codebase_structure` memory → verify with `find_file`
2. Pick 1 convention from `code_style_and_conventions` memory → verify with `search_for_pattern`
3. Return: ✅ PASS / ❌ FAIL + list of any failures

### Agent B: 🏗️ Architecture Scan (mode: "auto")

Quick scan for major structural changes since last session.

### Agent C: Removed

**Command registration** is handled by the `setup` script at install/update time,
not at runtime. See `setup` in the skill root. The self-repair check in Step 1.5
ensures commands are registered even if setup was never run manually.

### Agent D: 🗺️ Environment Discovery + Routing Matrix (mode: "auto", MANDATORY)

Full environment scan: skills, custom agents, MCP servers/plugins, and routing
matrix build. This is mechanical work — exactly what agents should handle.
**Never skip or defer.**

**What it does:**

```
┌─ Environment Discovery + Routing Matrix ──────────────────────┐
│                                                                │
│  1. 📋 Skill inventory                                         │
│     ├─ Read system context's available skills list             │
│     ├─ Load base matrix from skill-routing-matrix.md           │
│     ├─ Compare: skills in base → skip, NOT in base → delta    │
│     └─ Count: total available, base covered, new/delta        │
│                                                                │
│  2. 🤖 Custom agent discovery                                  │
│     ├─ Scan .claude/agents/ (project-level)                   │
│     ├─ Scan ~/.claude/agents/ (user-level)                    │
│     └─ Build routing entries for each custom agent found       │
│                                                                │
│  3. 🔌 MCP server / plugin inventory                           │
│     ├─ Read available MCP tools from system context            │
│     ├─ Identify active servers (Serena, Context7, Playwright,  │
│     │   and any others)                                        │
│     └─ Note which servers are available vs configured but off  │
│                                                                │
│  4. 🔀 Build routing matrix                                    │
│     ├─ Merge: base + delta skills + custom agents              │
│     └─ Annotate with MCP tool availability                     │
│                                                                │
│  5. 💾 Return: full environment summary                        │
│                                                                │
│  ⚡ ~80% cheaper than full matrix build from scratch           │
└────────────────────────────────────────────────────────────────┘
```

**Return format:**
```
{
  skills: { total: N, base: 30, delta: N, new: ["skill-a", ...] },
  custom_agents: { count: N, agents: ["agent-a", ...] },
  mcp_servers: { active: ["serena", "context7", ...], available_tools: N },
  routing_matrix: { total_entries: N }
}
```

**Why an agent**: The SP operates at the decision layer. Scanning skills lists,
file system directories, and MCP tool inventories is mechanical — delegate it.
The SP should reason from the environment summary, not spend context building it.

**If Agent D fails**: Fall back to the base matrix from `skill-routing-matrix.md`
plus real-time matching from system context. Note limitation in orientation.

### Agent E: ⚡ Version Check (mode: "auto")

Lightweight background check for skill updates.

**What it does:**

```
┌─ Version Check ────────────────────────────────────────────────────┐
│  1. Read SKILL.md frontmatter → extract repo field                  │
│  2. Use the WebFetch tool to fetch the URL:                         │
│     https://api.github.com/repos/{repo}/releases/latest             │
│     Do NOT use Bash, curl, or any shell command for HTTP requests.  │
│     Use WebFetch — do NOT fall back to Bash/curl.                  │
│  3. Extract tag_name → strip leading "v" if present                 │
│  4. Return: { latest_version: "X.Y.Z" }                             │
│     OR:     { error: "unreachable" }                                 │
│                                                                      │
│  ⚠️  Timeout: 5 seconds. No retries.                                │
│  ⚠️  If no Releases exist, try /tags?per_page=1 (also via WebFetch)│
│  ⚠️  If both fail → { error: "no_releases" }.                       │
│  ⚠️  If WebFetch is unavailable or denied →                         │
│       return { error: "webfetch_unavailable" }                       │
│       Do NOT fall back to Bash/curl.                                 │
└────────────────────────────────────────────────────────────────────┘
```

**Why an agent**: Network call output should not consume main context.
Agent returns a clean one-field result.

---

## 📖 Step 3: Read State (Parallel with Agents)

While agents are running, read session context in parallel:

```
┌─ Continuation Check ─────────────────────────────────┐
│  Does $ARGUMENTS contain a .handoffs/ path?           │
│  ├─ YES → read handoff file, enter continuation mode  │
│  └─ NO  → fresh session, enter initialization mode    │
└───────────────────────────────────────────────────────┘
```

1. **Check for continuation**: `$ARGUMENTS` → `.handoffs/` path?
2. **Read Serena memories**: `list_memories()` → read relevant ones
   - `project_overview`, `codebase_structure`, `code_style_and_conventions`
   - `partner_profile` (if exists)
   - Any task/session memories from prior sessions
3. **Read CLAUDE.md**: Check for project-level rules, conventions, guardrails

4. **Git state**: Run `git status`, `git branch --show-current`, and
   `git log --oneline -5` as **separate parallel Bash calls**. Never chain
   git commands with `echo "---"` separators — this triggers Claude Code's
   "quoted characters in flag names" safety warning.

**Note**: Custom agent scanning and routing matrix building are handled by
Agent D (Step 2). The SP reads state here while Agent D works in parallel.

---

## ✅ Step 4: Verify Agent Results (Gate)

Before presenting orientation, verify **Agent D** completed successfully.
This is a **blocking verification** — Agents A and B provide useful context
but are not security-critical.

### 🗺️ Agent D Verification (Required)

| Result | Action |
|---|---|
| ✅ Environment scanned + matrix built | Store matrix in Serena as `skill_routing_matrix`. Report environment summary in orientation: N skills (M new), K custom agents, MCP servers active. |
| ⚠️ Agent D timed out / failed | **Fall back to base matrix** from `skill-routing-matrix.md` + real-time matching. Note limitation in orientation: "Routing from base matrix only — environment scan failed." |

### 🔍 Agents A/B Integration (Non-blocking)

| Result | Action |
|---|---|
| ✅ Staleness PASS | Proceed normally, no mention to user |
| ❌ Staleness FAIL | Flag in orientation, propose targeted memory update via `AskUserQuestion` |
| 🏗️ Architecture scan results | Incorporate into orientation context |
| ⚠️ Agent timed out / failed | Note limitation in orientation, proceed without that data |

### ⚡ Agent E Integration (Non-blocking)

| Result | Action |
|---|---|
| ✅ Remote version = local version | No mention to user |
| ⚡ Remote version > local version | Show in orientation: "⚡ v{remote} available (you have v{local}). Run `/strategic-partner:update`" |
| ⚠️ Agent failed / timed out | Skip silently — no mention |

---

## 📋 Step 5: Present Orientation

Compile results from Steps 3-4 into the orientation briefing.

**🔄 Continuation mode**: Summarize restored state, highlight what changed since
last session, present next steps from handoff file.

**🆕 Initialization mode**: Present project overview, available capabilities,
and ask what the user wants to work on.

**Include in orientation:**
- ⚠️ Any agent warnings from Step 4
- ❌ Staleness check results (if FAIL)
- 🌿 Current branch and git state
- 🗺️ Environment summary from Agent D: skills (base + delta), custom agents, active MCP servers
- ⚡ Update available (from Agent E): one-liner with version diff and update command
- 🔌 **Serena not detected**: If Serena MCP is unavailable, display this block:

> **Serena MCP is not detected.** The Strategic Partner works without it but operates
> in degraded mode — losing cross-session memory, semantic code navigation, codebase
> structure awareness, and convention tracking. These capabilities make advisory sessions
> significantly more effective across projects and sessions.
>
> **Setup**: https://github.com/serena-ai/serena
>
> Serena is an investment that pays off across every project the SP touches.

This is a **firm, one-time recommendation** — not a nag. Display once in orientation,
then proceed normally in degraded mode.

**Session setup recommendations** (include in orientation via `AskUserQuestion`):

Suggest the user run these commands for optimal advisory experience.
These are **user-only slash commands** — the SP cannot execute them programmatically.

```
┌─ Recommended Session Setup ──────────────────────────────────────┐
│                                                                   │
│  /effort high          ← full reasoning power for advisory work  │
│  /rename sp-init-MMDD  ← meaningful session name for /resume     │
│                                                                   │
│  💡 Present these as a suggestion, not a claim of execution.     │
│  💡 The user must run them — skills cannot invoke slash commands. │
└───────────────────────────────────────────────────────────────────┘
```

As the session topic crystallizes (after 2-3 exchanges), suggest the user
refine the name: `/rename sp-[topic]-MMDD` (e.g., `sp-auth-refactor-0316`).

**Provider selection** (ask when the session topic involves implementation prompts):

If the session will involve crafting implementation prompts (most SP sessions do),
ask the user which model provider executors will target:

> "Which provider will run your implementation sessions?"
> Options: [Claude/Anthropic (Recommended)] [OpenAI/Codex] [Google/Gemini]

Store the answer for the session. When crafting prompts, load the matching
guide from `references/provider-guides/`. If the user doesn't know or says
"mixed", default to Claude format (most structured, degrades gracefully).

This question is asked ONCE per session, not per prompt.

---

## 🧠 Serena Memory Monitoring

### When to Propose Memory Writes
- ✅ New convention or process agreed in conversation
- ✅ Architectural decision made with rationale
- ✅ Significant gotcha or lesson learned discovered
- ✅ Threshold values calibrated and confirmed

### When to Propose Re-Onboarding
- ⚠️ Memory references files/directories that no longer exist
- ⚠️ Memory describes module structure contradicting actual codebase
- ⚠️ Major architectural reorganization since last onboarding
- ⚠️ Memory content is internally inconsistent
- ⚠️ User explicitly says "memories are wrong" or "re-onboard"

### Re-Onboarding Protocol
1. **Never** re-onboard autonomously — it overwrites existing memories
2. `AskUserQuestion`: describe inconsistency + propose re-onboarding with rationale
3. Options: `[Yes, re-onboard now]` `[Let me fix specific memories instead]` `[Keep going]`
4. If confirmed: `onboarding` call refreshes codebase analysis and memories

---

## 👤 Partner Profile

- Does Serena memory `partner_profile` exist?
- If yes → read and adapt communication depth
- If no → observe during session, write after 3+ exchanges

---

## 📝 CLAUDE.md Monitoring Triggers

Propose an update when:
- 📌 A new convention or process is agreed upon in conversation
- 💡 A "lessons learned" emerges from an implementation report
- 🏗️ An architectural decision is made that should constrain future sessions
- 🔄 A rule is being violated repeatedly (suggests missing guardrail)
- 🔖 Version bump process is established or changed

---

## 🗂️ Memory Placement Guide

```
┌────────────────────┬───────────────────────────────────────────────────┐
│  Location          │  What Goes There                                  │
├────────────────────┼───────────────────────────────────────────────────┤
│  Serena memories   │  architectural decisions, codebase structure,     │
│                    │  code conventions, threshold values, known        │
│                    │  gotchas, design rationale                        │
├────────────────────┼───────────────────────────────────────────────────┤
│  CLAUDE.md         │  process rules, enforcement conventions,         │
│                    │  project-wide guardrails                          │
├────────────────────┼───────────────────────────────────────────────────┤
│  .claude/rules/    │  path-specific rules                             │
│                    │  (e.g., "all files in src/api/ must...")          │
├────────────────────┼───────────────────────────────────────────────────┤
│  Auto-memory       │  session learnings, user preferences             │
├────────────────────┼───────────────────────────────────────────────────┤
│  .handoffs/        │  current session state, continuation prompts     │
├────────────────────┼───────────────────────────────────────────────────┤
│  .prompts/         │  implementation prompts organized by milestone   │
├────────────────────┼───────────────────────────────────────────────────┤
│  .scripts/         │  runnable operational scripts                    │
└────────────────────┴───────────────────────────────────────────────────┘
```

---

## 💬 Ask-Before-Act Examples

**🧠 Serena memory write:**
> "I want to record our decision to use cosine distance thresholds (T_ACCEPT=0.25,
> T_REJECT=0.55) in Serena as 'identity_threshold_decisions'. Rationale: this was a
> corrected value from Round 1's wrong calibration and should survive session resets.
> Shall I write this memory?"

**📝 CLAUDE.md update:**
> "I want to add a Dev Visibility Rule to CLAUDE.md requiring a CHANGELOG.json entry
> with every pipeline change. Rationale: we keep forgetting this across sessions.
> Proposed text: [exact text]. Shall I add it?"

**📦 Git commit:**
> "Good checkpoint for a commit — the roadmap review is complete. Proposed message:
> `docs: player identity roadmap reviewed, regression gate baseline corrected`.
> Shall I commit?"

**⏳ Context handoff:**
> "We're approaching context limits and I want to preserve what we've built today
> before quality degrades. I'll write a handoff to `.handoffs/` — the continuation
> prompt will restore the advisor persona in the fresh session. Shall I do it?"

**🏷️ Session rename:**
> "Now that we've clarified the focus, I'll rename this session to
> `sp-jwt-middleware-0316` for easy retrieval."
