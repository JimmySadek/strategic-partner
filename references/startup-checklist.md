# 🚀 Startup Checklist (Internal)

Reference file for the strategic-partner advisor. Full startup sequence with
identity setup, environment configuration, and fire-and-verify agents.
Do not display to user.

> **Floor sentinel protocol** — see `references/floor.md`. The floor's
> UserPromptSubmit hook fires on every user prompt; the floor walk itself
> runs once per unique scope (session, cwd, skill version, prompt class)
> and is documented separately. This file covers the broader startup
> orientation that runs on the first invocation of `/strategic-partner` only.

```
┌──────────────────────────────────────────────────────────────────────────┐
│  SP Startup Flow                                                          │
│                                                                           │
│  Step 1          Step 2          Step 3       Step 4                    │
│  Checks    →  Spawn Agents  → Read State → Verify                      │
│  Self-repair    ┌─ Agent A     $ARGUMENTS    ✅ Agent D                 │
│  Version ✓     ├─ Agent B     Serena              │                     │
│  Target model  └─ Agent D     CLAUDE.md           │                     │
│  (inline)        🗺️ Matrix          │              │                     │
│                     │              │              ▼                     │
│                     │              │         Step 5                     │
│                     └──────────────┘         📋 Orient                  │
│                                              + Context advisory         │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 🔧 Step 1: Environment Configuration (SP does not manage autocompact)

Autocompact is **user-controlled**. The env var `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`
(https://code.claude.com/docs/en/env-vars.md) is read from the launching shell
at Claude Code startup; the default threshold is approximately 95% of the
session's context window. The SP does not set, install, or recommend a value
for this variable — see `hooks-integration.md` § 🚀 SessionStart for the full
investigation of why a skill-frontmatter SessionStart hook cannot set it
programmatically.

What the SP **does** do:

- Detect the active model and its context window at startup (Opus 4.7 → 1M;
  other current models → 200K by default)
- On 1M-context sessions, surface an informational advisory in orientation
  noting the ~256K retrieval reliability cliff — see Step 5 "Context advisory"
  bullet for the exact copy and trigger rules
- Let the user decide what to do with that awareness — wrap up earlier,
  trigger a handoff sooner, or accept the risk on a given run

The remaining Step 1 work is inline environment checks (self-repair, version,
target-model detection) — see Step 1.5 below.

📎 See `context-handoff.md` § Environment Baseline for the advisory framing
📎 See `hooks-integration.md` § 🚀 SessionStart for the lifecycle-incompatibility
   write-up and why the SP does not ship a calibrator

---

## 🔧 Step 1.5: Self-Repair Check

Before spawning agents, verify command registration is intact. This is a count-based
inline Bash check (not an agent) — it runs in ~15ms when everything is in sync.

```
# Resolve SP install dir via stable command symlinks (portable across install paths).
# ${HOME}/.claude/commands/strategic-partner/ is created by setup; each *.md is a
# symlink back to the source commands/ in the install dir.
SP_ANY_CMD=$(ls "${HOME}/.claude/commands/strategic-partner/"*.md 2>/dev/null | head -1)
if [ -n "$SP_ANY_CMD" ]; then
  SP_SKILL_DIR=$(dirname "$(dirname "$(readlink -f "$SP_ANY_CMD")")")
  CMD_COUNT=$(ls "${SP_SKILL_DIR}/commands/"*.md 2>/dev/null | wc -l | tr -d ' ')
  LINK_COUNT=$(ls "${HOME}/.claude/commands/strategic-partner/"*.md 2>/dev/null | wc -l | tr -d ' ')
  [ "$CMD_COUNT" = "$LINK_COUNT" ] || bash "${SP_SKILL_DIR}/setup"
fi
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
   "💡 CLAUDE.md is {N} lines (recommended: under 200). Consider splitting
   path-specific rules into .claude/rules/ files."

### Target Model Detection (inline, not an agent)

The SP detects the currently active Claude model from the environment to inform
prompt crafting. Default assumption: the executor running SP's crafted prompts
will be on the same model unless the user specifies otherwise.

Detection — match any of the following in the runtime declaration (case-insensitive):
- Friendly names: "Opus 4.7", "Sonnet 4.6", "Haiku 4.5"
- Exact model IDs:
  - `claude-opus-4-7` (Opus 4.7)
  - `claude-sonnet-4-6` (Sonnet 4.6)
  - `claude-haiku-4-5-20251001` (Haiku 4.5)
- If detected: store the normalized family (Opus 4.7 / Sonnet 4.6 / Haiku 4.5) as session-active target model
- If multiple models mentioned or unclear: default to Opus 4.7 (current GA) with a note

Report in orientation ONLY if target model differs from Opus 4.7 default OR
user explicitly asked:
"📌 Target model for crafted prompts: [detected model]. Override per prompt if
executor will run on a different model."

The detection feeds `prompt-crafting-guide.md` § Model-Aware Block Selection —
the SP uses this to decide which reusable blocks to embed in crafted prompts.

**`/effort` guidance by model** (used when the SP recommends runtime flags,
not by hook):
- **Opus 4.7**: `xhigh` is the Claude Code default for all plans — no action
  needed. `/effort high` only makes sense as a deliberate downgrade for
  latency-sensitive sessions.
- **Opus 4.6**: `/effort high` remains a reasonable upgrade for advisory
  sessions if the user wants maximum reasoning.
- **Sonnet 4.6**: defaults to `high` at the API level; no explicit
  recommendation needed.
- **Haiku 4.5**: `low`-to-`medium` depending on task complexity.

Do NOT surface these as startup-time prompts. They are reference for when
the user asks "what effort should I use?" or when SP crafts a prompt that
explicitly calls for a different setting than the default.

### Context Window Sanity Check (inline, one-time per session)

Known Anthropic-side autocompact bugs on 1M-context sessions remain open
(anthropics/claude-code#34332, #42375, #43989, #50204). If autocompact is
observed firing at unexpectedly low context usage, those issues are the first
place to look. The SP does not ship a calibrator for this; the Step 5
"Context advisory" bullet surfaces the relevant situational awareness on
1M-window sessions so the user can plan handoff timing accordingly.

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

### Version Check (inline, not an agent)

Quick check against GitHub releases. Runs inline because it's a single curl
returning one version string — agent overhead adds fragility with no benefit.

```
# Resolve SP install dir (same pattern as self-repair check)
SP_ANY_CMD=$(ls "${HOME}/.claude/commands/strategic-partner/"*.md 2>/dev/null | head -1)
if [ -n "$SP_ANY_CMD" ]; then
  SP_SKILL_DIR=$(dirname "$(dirname "$(readlink -f "$SP_ANY_CMD")")")
  local_version=$(grep '^version:' "${SP_SKILL_DIR}/SKILL.md" | head -1 | awk '{print $2}')
  remote_version=$(curl --max-time 8 -sf "https://api.github.com/repos/JimmySadek/strategic-partner/releases/latest" 2>/dev/null | grep -oE '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/^v//')
  if [ -z "$remote_version" ]; then
    echo "UNABLE_TO_CHECK"
  elif [ "$remote_version" = "$local_version" ]; then
    echo "UP_TO_DATE"
  else
    echo "UPDATE_AVAILABLE:${remote_version}"
  fi
fi
```

- If curl fails or GitHub is unreachable: `remote_version` is empty → emit `UNABLE_TO_CHECK` explicitly (no longer falsely declaring `UP_TO_DATE`)
- If versions match: emit `UP_TO_DATE`
- If versions differ: emit `UPDATE_AVAILABLE:${remote_version}` and orientation shows update notice
- Timeout: `curl --max-time 8` bounds the call (matches the v5.15.0 floor's Group 6 pattern); no retries needed
- The `grep -oE '"tag_name": *"[^"]*"'` regex tolerates whitespace between key and value, which GitHub's pretty-printed JSON includes by default

This replaces Agent E entirely. No WebFetch, no ToolSearch, no background agent.

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

### Agent E: Removed

**Version check** is handled inline in Step 1.5 via a single curl command.
See the "Version Check (inline, not an agent)" section above.

### Agent D: 🗺️ Environment Discovery + Routing Matrix (mode: "auto", DISPATCHED ONLY ON FLOOR-SIGNAL)

Full environment scan: skills, custom agents, MCP servers/plugins, and routing
matrix build. This is mechanical work — exactly what agents should handle.

**When to dispatch (v5.16.0+ contract):** Agent D is dispatched only when
the floor sentinel reports the matrix is not current — concretely, when
the `SP-FLOOR-COMPLETE` line carries `routing=stale ...` or
`routing=missing`. When the floor reports `routing=fresh hash=<short>`,
the cached matrix's `inventory_hash` matched the live filesystem
inventory, and Agent D is skipped — the SP uses the cached matrix.

Earlier releases dispatched Agent D unconditionally on every fresh
session, which is what caused the every-session rebuild waste this
release fixes. Treat the floor signal as authoritative.

**What it does:**

```
┌─ Environment Discovery + Routing Matrix ──────────────────────┐
│                                                                │
│  1. 📋 Skill inventory                                         │
│     ├─ Read system context's available skills list             │
│     ├─ Load task categories from skill-routing-matrix.md       │
│     ├─ Match each skill to a task category by description      │
│     └─ Count: total available, new since cache, removed        │
│                                                                │
│  2. 🤖 Custom agent discovery                                  │
│     ├─ Scan .claude/agents/ (project-level)                   │
│     │   └─ On failure → record "project_level_scan_failed"    │
│     ├─ Scan ~/.claude/agents/ (user-level)                    │
│     │   └─ On failure → record "user_level_scan_failed"       │
│     └─ Build routing entries for each custom agent found       │
│                                                                │
│  3. 🔌 MCP server / plugin inventory                           │
│     ├─ Read available MCP tools from system context            │
│     ├─ Identify active servers (Serena, Context7, Playwright,  │
│     │   and any others)                                        │
│     └─ Note which servers are available vs configured but off  │
│                                                                │
│  4. 🔀 Build routing matrix                                    │
│     ├─ Map discovered skills to task categories                │
│     ├─ Merge with built-in Agent types (always available)      │
│     └─ Annotate with MCP tool availability                     │
│                                                                │
│  5. 💾 Compute inventory_hash + persist + return summary       │
└────────────────────────────────────────────────────────────────┘
```

**Step 5 detail — `inventory_hash` and canonical persistence:**

After steps 1-4 complete, Agent D MUST emit an `inventory_hash` field in
the matrix footer. The floor sentinel (Group 7) reads this hash on the
next session start to decide whether to skip the rebuild — if the hash
still matches the live inventory, the matrix is current and no rebuild
dispatches.

**Inventory hash scope (v5.16.0): agent filenames only.**
`inventory_hash = sha256(sorted basenames of ~/.claude/agents/*.md + count)`,
truncated to 16 hex chars. The matrix BODY still inventories skills, MCP
servers, and agent definitions for routing decisions, but ONLY agent
filenames feed the hash because the floor sentinel hook cannot reliably
enumerate skills or MCP servers from its `$payload` context — and the
hash must use inputs both Agent D and the floor can read identically.

**Trade-off**: pure skill or MCP installs without an accompanying agent
change are not auto-detected by the floor; an explicit refresh path
(currently `/strategic-partner:update`, or any future explicit-refresh
command) handles those cases. In practice, agent changes are the most
common config delta when a user is iterating on their setup, and skill
installs typically arrive alongside an agent change — so agent
filenames serve as a reliable cross-context proxy for "the user's
config has shifted enough to warrant a rebuild."

Compute as follows:

```
inventory_hash = sha256(
  sorted(agent filenames basenames):
    ~/.claude/agents/*.md          (user-level)
  + count: agent_count
), truncated to 16 hex chars.
```

The shell shape (must match the Group 7 hook in SKILL.md):

```
agents_list=$(ls ~/.claude/agents/*.md 2>/dev/null \
              | xargs -n1 basename 2>/dev/null | sort)
agent_count=$(printf '%s' "$agents_list" | grep -c .)
printf 'agents:\n%s\ncount:%s\n' "$agents_list" "$agent_count" \
  | sha256sum (or shasum -a 256) | awk '{print $1}' | cut -c1-16
```

Emit as `inventory_hash: "sha256:<short>"` in the YAML footer alongside
the existing `routing_status`, `scan_timestamp`, `errors`, `counts`,
`category_counts`, and `notes` fields.

Note: Agent D may use the system-reminder skill list to BUILD the
matrix's task-category mappings (that's where the descriptions live),
but the inventory_hash MUST be computed from the agent-filenames input
above so the floor sentinel — which has no access to system-reminder —
can recompute the same hash on next session start.

**Canonical persistence — write to ONE source of truth:**

- If Serena is active in this project (memory tools available) → write
  the matrix to Serena memory `skill_routing_matrix`. This is the
  preferred source of truth; the floor sentinel reads it first.
- If Serena is absent → write to `.claude/skill-routing-matrix.md`. The
  `.claude/` directory is gitignored by default and is the canonical
  fallback location.
- Do NOT write to both. The matrix has one source of truth per project.
- Do NOT create `.claude/sp-routing-matrix.md` — that legacy companion
  file is DEPRECATED as of v5.16.0. Single canonical name:
  `skill-routing-matrix.md` everywhere it appears outside Serena memory.

**Return format:**
```
{
  skills: { total: N, new_since_cache: N, removed_since_cache: N },
  agents: { user_level: N, project_level: N, errors: [] },
  mcp_servers: { active: ["serena", ...], tool_count: N },
  routing_status: "built" | "cached" | "fallback",
  inventory_hash: "sha256:<short>",
  persistence_target: "serena" | ".claude/skill-routing-matrix.md"
}
```

The `errors` array captures scan failures without masking them as zero counts.
Examples: `["user_level_scan_failed"]`, `["project_level_scan_failed"]`.
The `routing_status` indicates how the matrix was constructed:
- `"built"` — full discovery succeeded (errors may still exist for non-critical scans)
- `"cached"` — discovery failed, using Serena cached matrix
- `"fallback"` — no cache available, routing from system context + task categories only

**Why an agent**: The SP operates at the decision layer. Scanning skills lists,
file system directories, and MCP tool inventories is mechanical — delegate it.
The SP should reason from the environment summary, not spend context building it.

**Failure handling (fallback chain):**
```
Agent D succeeds fully
  └─ routing_status: "built"
     Store matrix in Serena as skill_routing_matrix (or
     .claude/skill-routing-matrix.md if Serena absent)
     Footer includes inventory_hash for next-session freshness check

Agent D partial failure (e.g., agent scan fails, skills readable)
  └─ routing_status: "built" (with errors noted in agents.errors)
     Use what succeeded + note gaps in orientation
     inventory_hash still computed from successful portions

Agent D total failure
  └─ Read Serena cached matrix (skill_routing_matrix) or
     .claude/skill-routing-matrix.md
     routing_status: "cached"

No cached matrix exists anywhere
  └─ Match system-reminder skills to task categories + built-in Agent types
     routing_status: "fallback"
```

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
2. **Survey Serena memories, read on demand**: Call `list_memories()` at
   startup to see what is available — this is fast and populates your
   awareness of persistent project knowledge. Then read memories ON
   DEMAND, not eagerly: when a specific decision or advisory question
   requires their content, read the relevant memory at that moment.

   **Always read at startup** (high-value orientation context):
   - `project_overview` (what the project is, current state)
   - Most recent `decision_log` entries (recent commitments, context
     for current session direction)

   **Read on demand** (content depends on the specific task):
   - `codebase_structure` — read when exploring architecture or routing
     tasks to files
   - `code_style_and_conventions` — read when making recommendations
     that touch conventions
   - `partner_profile` (if exists) — read once per session to
     calibrate communication depth
   - Task or session memories from prior sessions — read when the
     current task relates to prior work

   This deferred-read pattern preserves token economy for long sessions
   and matches the behavior of healthy SP sessions in practice. If a
   memory is clearly relevant to the conversation's active thread, read
   it. If not, wait until it is.
3. **Read CLAUDE.md**: Check for project-level rules, conventions, guardrails

4. **Git state**: Run `git status`, `git branch --show-current`, and
   `git log --oneline -5` as **separate parallel Bash calls**. Never chain
   git commands with `echo "---"` separators — this triggers Claude Code's
   "quoted characters in flag names" safety warning.

**Note**: Custom agent scanning and routing matrix building are handled by
Agent D (Step 2). When the floor sentinel reports `routing=fresh hash=<short>`,
Agent D is skipped and the SP uses the cached matrix at the canonical
location (Serena memory `skill_routing_matrix` if active, else
`.claude/skill-routing-matrix.md`). When the floor reports `routing=stale ...`
or `routing=missing`, Agent D works in parallel with the state reads here.

---

## ✅ Step 4: Verify Agent Results (Gate)

Before presenting orientation, verify any agents that were dispatched.
**Agent D verification is required only when Agent D was dispatched** —
it is skipped on `routing=fresh hash=<short>`. Agents A and B provide
useful context but are not security-critical.

### 🗺️ Routing Matrix Source

| Floor signal | Source for orientation | Verification |
|---|---|---|
| `routing=fresh hash=<short>` | Cached matrix at canonical location (Agent D skipped) | None — the floor's hash match is itself the verification |
| `routing=stale ...` or `routing=missing` (Agent D dispatched) | Agent D's return summary | Per the table below |

### 🗺️ Agent D Verification (Required only when Agent D ran)

| Result | Action |
|---|---|
| ✅ `routing_status: "built"` (no errors) | Persist matrix per Step 5 detail (Serena memory if active, else `.claude/skill-routing-matrix.md`). Report: "N skills available, M agents detected. Routing matrix built." |
| ✅ `routing_status: "built"` (with errors) | Persist matrix, note gaps. Report: "N skills available, M agents detected (scan had issues — count may be incomplete)." |
| ⚠️ `routing_status: "cached"` | Using cached matrix from canonical location. Report: "Using cached routing matrix (environment scan failed). N skills in cache." |
| ❌ `routing_status: "fallback"` | No cache available. Report: "Limited routing — no cache available. Routing from system context only." |

### 🔍 Agents A/B Integration (Non-blocking)

| Result | Action |
|---|---|
| ✅ Staleness PASS | Proceed normally, no mention to user |
| ❌ Staleness FAIL | Flag in orientation, propose targeted memory update via `AskUserQuestion` |
| 🏗️ Architecture scan results | Incorporate into orientation context |
| ⚠️ Agent timed out / failed | Note limitation in orientation, proceed without that data |

### ⚡ Version Check Integration (from Step 1.5 inline check)

| Result | Action |
|---|---|
| UP_TO_DATE or check failed silently | No mention to user |
| UPDATE_AVAILABLE:{version} | Show in orientation: "⚡ v{remote} available (you have v{local}). Run `/strategic-partner:update`" |

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
- 🗺️ Environment summary: skill count, agent count (with any scan errors
  noted), active MCP servers. Source depends on the floor's routing signal:
  - `routing=fresh hash=<short>` → counts read from the cached matrix's
    `counts:` footer (Agent D was skipped, so use the existing matrix).
  - `routing=stale ...` or `routing=missing` → counts come from Agent D's
    return summary.
- ⚡ Update available (from inline version check in Step 1.5): one-liner with version diff and update command
- 🔧 **Context advisory** (1M-context sessions only): If the detected model
  has a 1M context window (Opus 4.7, or any model running with
  `SP_CONTEXT_WINDOW=1M`), display this informational note in orientation:
  "📌 **1M context advisory:** Autocompact defaults to ~95% of your window
  (~950K tokens), and known Anthropic issues (#34332, #42375, #43989,
  #50204) cause erratic behavior above ~256K. For reliable retrieval and
  clean handoffs, consider wrapping up or triggering handoff around 250K
  tokens. The SP will prompt for handoff on session-end signals regardless;
  this note is just situational awareness. No settings are changed."

  On 200K-context sessions, skip this bullet entirely — the default ~95%
  threshold is reasonable at that window size.
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

- 📋 **Backlog surfacing**: Scan `.backlog/*.md` (Glob). If files exist: read
  frontmatter, check each item's `trigger` against current state (git log, file
  existence, version numbers). Surface items with met triggers as callouts:
  "🔔 **[Title]** — trigger met: [reason]." If none actionable: one-liner count
  ("N backlog items parked, none actionable"). If `.backlog/` doesn't exist: skip
  silently — say nothing.

- 📝 **Session findings surfacing**: Scan `.handoffs/findings-*.md` (Glob). If
  files exist from a previous session: count unresolved items (entries in `## Issues`
  not listed under `## Promoted`). Surface as: "N unresolved findings from [date].
  Promote any to backlog, or continue — they carry forward."
  If no findings files exist: skip silently.

**Session setup recommendation** (include in orientation via `AskUserQuestion`):

Suggest the user rename the session for meaningful `/resume` retrieval.
This is a **user-only slash command** — the SP cannot execute it programmatically.

```
┌─ Recommended Session Setup ──────────────────────────────────────┐
│                                                                   │
│  /rename sp-init-MMDD  ← meaningful session name for /resume     │
│                                                                   │
│  💡 Present as a suggestion, not a claim of execution.           │
│  💡 The user must run it — skills cannot invoke slash commands.  │
└───────────────────────────────────────────────────────────────────┘
```

As the session topic crystallizes (after 2-3 exchanges), suggest the user
refine the name: `/rename sp-[topic]-MMDD` (e.g., `sp-auth-refactor-0316`).

**Mandatory termination:** Step 5 MUST end with an `AskUserQuestion` call.
The SP never finishes orientation with prose and waits passively. See SKILL.md
"Startup termination rule" for the specific questions by mode.

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
> corrected value from Round 1's wrong calibration and should survive session resets."
>
> `AskUserQuestion`: [Write this memory] [Not yet] [Adjust the content first]

**📝 CLAUDE.md update:**
> "I want to add a Dev Visibility Rule to CLAUDE.md requiring a CHANGELOG.json entry
> with every pipeline change. Rationale: we keep forgetting this across sessions.
> Proposed text: [exact text]."
>
> `AskUserQuestion`: [Add it] [Not yet] [Let me review the text first]

**📦 Git commit:**
> "Good checkpoint for a commit — the roadmap review is complete. Proposed message:
> `docs: player identity roadmap reviewed, regression gate baseline corrected`."
>
> `AskUserQuestion`: [Commit] [Not yet] [Adjust the message]

**⏳ Context handoff:**
> "We're approaching context limits and I want to preserve what we've built today
> before quality degrades. I'll write a handoff to `.handoffs/` — the continuation
> prompt will restore the advisor persona in the fresh session."
>
> `AskUserQuestion`: [Write the handoff] [Not yet — keep going] [Let me save notes first]

**🏷️ Session rename:**
> "Now that we've clarified the focus, I'll rename this session to
> `sp-jwt-middleware-0316` for easy retrieval."
