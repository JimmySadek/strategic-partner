# 🚀 Startup Checklist (Internal)

Reference file for the strategic-partner advisor. Full startup sequence with
identity setup, environment configuration, and fire-and-verify agents.
Do not display to user.

> **Floor sentinel protocol** — see `references/floor.md`. Direct plugin
> commands, model-invoked Skill activation, and resident-advisor SessionStart
> all enter through the same floor. UserPromptSubmit remains a compatibility
> fallback and previous-turn relay. The floor walk itself runs once per unique
> scope (session, cwd, skill version, prompt class). This file covers the
> broader orientation that follows activation.

```
┌──────────────────────────────────────────────────────────────────────────┐
│  SP Startup Flow                                                          │
│                                                                           │
│  Step 1            Step 2             Step 3             Step 4       │
│  Checks      →  Read exact state  →  Verify truth  →  📋 Orient       │
│  Plugin-native    $ARGUMENTS          Project path       + Context     │
│  Version ✓        Serena              Live Serena        advisory      │
│  Target model     CLAUDE.md           Floor agreement                  │
│  (inline)                                                               │
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

- Detect the active model and its context window at startup (Opus 4.8 or
  Opus 4.7 → 1M; opusplan's plan phase stays 200K; other current models →
  200K by default)
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

## 🔧 Step 1.5: Plugin Registration Check

Claude Code's plugin loader owns command registration and voice delivery. The
floor reports `commands_registered=plugin-native` and
`output_style_state=plugin-native`; both are informational and stay silent in
orientation. Do not inspect standalone command symlinks, run `setup`, or copy a
voice file. If plugin components are missing, surface a plugin load problem and
recommend `/reload-plugins` or reinstalling the plugin.

### Memory Health Check (inline, not an agent)

Quick checks run inline during startup. No agents needed — these are observations.

1. **Serena**: Call `initial_instructions` once when exposed, then verify the
   exact current repository path with `get_current_config`. If the active path
   is wrong and `activate_project` is exposed, activate by exact path and
   re-check. If activation is hidden in the single-project Claude context,
   route to the Serena steward instead of attaching a second server. On
   no basename match, SP surfaces the project list / onboarding path and asks.
   Details in the Step 3 Serena survey below.

2. **.claude/rules/**: Check if `.claude/rules/` directory exists in the project.
   If it exists, note in orientation: "{N} path-scoped rule files found."
   If it doesn't exist, don't mention it — it's optional.

3. **CLAUDE.md size**: Read `g2.claude_md` from the floor sentinel output (see `references/floor.md` Group 2). Claude Code's current guidance is to target under 200 lines; the band field combines line count and char count:
   - `under-soft` → silent
   - `soft-warn` → "💡 CLAUDE.md is {M} lines / {N} chars — growing toward the preferred under-200-line shape."
   - `warn` → "⚠️ CLAUDE.md is {M} lines / {N} chars. Consider running `/strategic-partner-plugin:context-file-scan` before adding anything."
   - `surface-loudly` → "🚨 CLAUDE.md is {M} lines / {N} chars — too large for an always-loaded instruction file. Run `/strategic-partner-plugin:context-file-scan` for refactoring guidance."

### Target Model Detection (inline, not an agent)

The SP detects the currently active Claude model from the environment to inform
prompt crafting. Default assumption: the executor running SP's crafted prompts
will be on the same model unless the user specifies otherwise.

Detection — match any of the following in the runtime declaration (case-insensitive):
- Friendly names: "Opus 4.8", "Opus 4.7", "Sonnet 4.6", "Haiku 4.5", "Fable 5"
- Exact model IDs:
  - `claude-opus-4-8` (Opus 4.8; the 1M-context build reports as `claude-opus-4-8[1m]`)
  - `claude-opus-4-7` (Opus 4.7)
  - `claude-sonnet-4-6` (Sonnet 4.6)
  - `claude-haiku-4-5-20251001` (Haiku 4.5)
  - `claude-fable-5` (Fable 5)
  - `claude-fable-5[1m]` (Fable 5, 1M-context build)
- If detected: store the normalized family (Opus 4.8 / Opus 4.7 / Sonnet 4.6 / Haiku 4.5 / Fable 5) as session-active target model
- If multiple models mentioned or unclear (including Fable 5 mixed with others): default to Opus 4.8 (current GA) with a note

Report in orientation ONLY if target model differs from Opus 4.8 default OR
user explicitly asked:
"📌 Target model for crafted prompts: [detected model]. Override per prompt if
executor will run on a different model."

The detection feeds `prompt-crafting-guide.md` § Model-Aware Block Selection —
the SP uses this to decide which reusable blocks to embed in crafted prompts.

**`/effort` guidance by model** (used when the SP recommends runtime flags,
not by hook):
- **Opus 4.8**: Claude Code defaults to `high`, not `xhigh`. Set
  `/effort xhigh` explicitly for coding/agentic work — it is the
  recommended starting point, not the silent default.
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
(anthropics/claude-code#34332, #42375, #43989). If autocompact is
observed firing at unexpectedly low context usage, those issues are the first
place to look. The SP does not ship a calibrator for this; the Step 5
"Context advisory" bullet surfaces the relevant situational awareness on
1M-window sessions so the user can plan handoff timing accordingly.

### Codex CLI Detection (inline, not an agent)

```
which codex >/dev/null 2>&1
  ├─ Found → Set internal flag: codex_available = true
  │         Do NOT mention in orientation output
  │         SP may offer reviews at trigger points (see /strategic-partner-plugin:codex-feedback)
  └─ Not found → codex_available = false
                 Feature never surfaces. Totally silent.
                 Only educates if user explicitly invokes the subcommand.
```

### Cross-Model Review Policy Detection (silent)

After project rules are loaded (`AGENTS.md`, `CLAUDE.md`, or `GEMINI.md`), silently detect
whether the project wants a different model to review work than the one that built it.

1. Declared marker:
   `review-policy: cross-model-go-no-go`
   → set `review_policy = cross-model-go-no-go`.
2. Directly linked project-local pointers:
   if the rules file links to a companion rules or release document, read the relevant
   linked section before declaring the policy unset. Stay scoped to project-local
   pointers; do not arm every project from global rules such as `~/.claude/CLAUDE.md`
   unless the project-local rules explicitly opt in or override the model/reviewer
   policy.
3. Clear prose mandate for cross-model, adversarial, GO/NO-GO, independent-model review,
   or a tool-named reviewer that implies a different model/provider (for example Codex
   pre-release review, GPT review, or Claude review of Codex-built work)
   → set `review_policy = suspected-cross-model-go-no-go`.
4. No marker, linked-doc mandate, or clear prose mandate
   → leave `review_policy` unset.

Do not add a separate shell grep. This is a policy read over rules already in context.
Do not ask the build/review direction during orientation. The direction question fires
only when implementation-shaped work reaches packaging or dispatch, uses
`AskUserQuestion`, and only appears after SP has checked which model paths are available.
When the user confirms a suspected mandate, promote it to
`review_policy = cross-model-go-no-go` for the session.

### Agent Teams Flag Detection (inline, not an agent)

The same-agent post-dispatch correction path (see `references/fast-lane.md`
§ SendMessage Correction Path) exists only when Claude Code's experimental
Agent Teams switch — the environment variable
`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` — is enabled. Detect it once at
startup and keep it silent, exactly like the Codex check above.

```
[ -n "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-}" ] && [ "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-}" != "0" ]
  ├─ True → Set internal flag: agent_teams_available = true
  │        Do NOT mention in orientation output
  │        SP may offer a same-agent correction at post-dispatch review
  │        (see references/fast-lane.md § SendMessage Correction Path)
  └─ False / unset → agent_teams_available = false
                     Feature never surfaces. Totally silent.
                     Post-dispatch review is unchanged — accept or
                     dispatch fresh, exactly as today.
```

### Output Style Detection (handled by the floor sentinel)

Output Style detection is handled by the floor sentinel's Group 8.
Orientation reads `g8.output_style` from the `SP-FLOOR-COMPLETE` line
and renders an always-visible status row per
`references/floor-signal-handling.md` § Pattern: output_style.

**Runtime authority lives on the model side.** The hook reads settings
files in precedence order (`.claude/settings.local.json` →
`.claude/settings.json` → `~/.claude/settings.json`); the model
compares that resolved value against the runtime `# Output Style:`
header in its own system prompt and surfaces any disagreement. Never
substitute a system-reminder or `additionalContext` block claim for
either source — plugin SessionStart hooks inject those unconditionally
and they are not authoritative.

See `references/floor.md` § Group 8 for the emission pattern, and
`references/floor-signal-handling.md` § Pattern: output_style for the
orientation rendering rules and the runtime-vs-settings reconciliation
logic.

### Version Check (handled by the floor sentinel)

Read `g6.local`, `g6.remote`, and `g6.diff` from the floor results. The plugin
floor self-locates from its bundled hook path, so startup must not resolve a
standalone install directory or repeat the GitHub request. If `g6.diff=behind`,
show the available version and explain that plugin updates follow the user's
plugin installation route. If the remote check is unreachable, stay silent.

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

**Command registration** is handled by Claude Code's plugin loader. Step 1.5
reads the plugin-native floor signal; there is no runtime setup path.

### Agent E: Removed

**Version check** is handled by the plugin floor sentinel. See the
"Version Check (handled by the floor sentinel)" section above.

### Agent D: 🗺️ Deferred Routing-Matrix Maintenance (mode: "acceptEdits", USER-CONFIRMED ONLY)

Full environment scan: skills, custom agents, MCP servers/plugins, and routing
matrix build. Agent D is not a startup prerequisite. Orientation continues from
visible capabilities or a conservative `bare: true` route.

**When to dispatch:** all four conditions must be true:

1. The floor reports `routing=stale ...` or `routing=missing`.
2. A later source-shaped task materially needs precise routing now.
3. The user's request permits project writes; read-only intent always wins.
4. The user selected the exact `[Dispatch now — general-purpose]` confirmation.

The floor signal is diagnostic evidence, never dispatch authority. When the
floor reports `routing=fresh hash=<short>`, use the cached matrix. When it is
missing or stale but the current work does not need it, acknowledge only when
relevant and continue without dispatch.

Earlier releases dispatched Agent D during startup, which caused multi-minute
delays and crossed the write boundary before users received an orientation.
Never restore that behavior.

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
next session start to classify freshness. A stale result never dispatches
maintenance by itself.

**Inventory hash scope (v5.16.0): agent filenames only.**
`inventory_hash = sha256(sorted basenames of ~/.claude/agents/*.md + count)`,
truncated to 16 hex chars. The matrix BODY still inventories skills, MCP
servers, and agent definitions for routing decisions, but ONLY agent
filenames feed the hash because the floor sentinel hook cannot reliably
enumerate skills or MCP servers from its `$payload` context — and the
hash must use inputs both Agent D and the floor can read identically.

**Trade-off**: pure skill or MCP installs without an accompanying agent
change are not auto-detected by the floor; an explicit refresh path
(currently the user's plugin update route, or any future explicit-refresh
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

   **Auto-activate first if no project is active.** If a Serena call returns
   "No active project," SP does not stop and recover by hand. SP compares the
   current working directory's basename against the projects already registered
   with Serena:
   - **Basename matches a registered project** → SP calls `activate_project`
     for that project, then proceeds with the survey. No prompt needed — this
     is the common case (returning to a project Serena already knows).
   - **No basename match** → SP falls back to current behavior: surface the
     registered-project list (or the onboarding route) and ask the user which
     to use. SP never auto-runs onboarding here; only `activate_project` is
     automatic.

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

**Note**: Use the cached matrix when the floor reports
`routing=fresh hash=<short>`. Missing or stale routing never blocks these state
reads or orientation. Agent D runs only later, after the four conditions in
its deferred-maintenance contract are satisfied.

---

## ✅ Step 4: Verify Agent Results (Gate)

Before presenting orientation, verify only agents already dispatched for other
independent work. Orientation never waits for Agent D. Verify Agent D only after
a later confirmed maintenance dispatch.

### 🗺️ Routing Matrix Source

| Floor signal | Source for orientation | Verification |
|---|---|---|
| `routing=fresh hash=<short>` | Cached matrix at canonical location (Agent D skipped) | None — the floor's hash match is itself the verification |
| `routing=stale ...` or `routing=missing` | Visible capabilities or `bare: true`; no startup dispatch | None during orientation |

### 🗺️ Agent D Verification (Required only after a confirmed maintenance dispatch)

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

### ⚡ Version Check Integration (from the floor sentinel)

| Result | Action |
|---|---|
| UP_TO_DATE or check failed silently | No mention to user |
| UPDATE_AVAILABLE:{version} | Show in orientation: "⚡ v{remote} available (you have v{local}). Update through the same plugin installation route you used." |

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
  - `routing=stale ...` or `routing=missing` → use visible capabilities and
    omit unavailable counts. Orientation never waits for maintenance.
- 📌 **Output Style status row** (always visible): read `g8.output_style`
  from the floor signal and render the permanent status row per
  `references/floor-signal-handling.md` § Pattern: output_style. The
  row reads `📌 Output Style: ✅ active` when `strategic-partner-voice`
  is active, or `📌 Output Style: ⚠️ not active (current: <name>)` plus
  a two-line activation hint when a different style is active or none
  is set. Compare against the runtime `# Output Style:` header in the
  model's own system prompt; if they disagree, append a brief
  settings/runtime mismatch line beneath the row. See the pattern doc
  for full reconciliation rules. (Backwards-compat fallback: if the
  floor signal does not carry `g8.output_style` — older sentinel during
  the transition — orientation falls back to a direct settings-file
  read using the same precedence order. Remove the fallback after 1-2
  release cycles past v6.3.) The "two-line activation hint" above is
  this exact text — render it verbatim, do not improvise or invent a
  command; the canonical activation path is `/config`:

  ```
  Activate: /config → Output Style → Strategic Partner Voice
  Or: set outputStyle: strategic-partner-voice in ~/.claude/settings.json
  ```
- 🟡 **Voice style delivery**: `g8.output_style_state=plugin-native` means
  the style ships with this plugin and cannot drift as a copied file. Stay
  silent. If another value appears, treat it as a plugin load problem, not a
  reason to run standalone setup.
- ⚡ Update available (from the floor version check): one line with the version diff and the user's plugin update route
- 🔧 **Context advisory** (1M-context sessions only): If the detected model
  has a 1M context window (Opus 4.8 or Opus 4.7, or any model running with
  `SP_CONTEXT_WINDOW=1M`), display this informational note in orientation:
  "📌 **1M context advisory:** Autocompact defaults to ~95% of your window
  (~950K tokens), and known Anthropic issues (#34332, #42375, #43989)
  cause erratic behavior above ~256K. For reliable retrieval and
  clean handoffs, consider wrapping up or triggering handoff around 250K
  tokens. The SP will prompt for handoff on session-end signals regardless;
  this note is just situational awareness. No settings are changed."

  On 200K-context sessions, skip this bullet entirely — the default ~95%
  threshold is reasonable at that window size. The floor's transcript-based
  model fallback feeds this advisory too — sessions whose model becomes known
  only via the transcript now correctly receive it.
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

- 🔍 **Context-file drift scan**: do not run the standalone skill's
  source-repository startup scan. A cached plugin install has no meaningful
  equivalent of the skill source project's `CLAUDE.md`, and plugin loading
  must not resolve command symlinks to find one. When the current project's
  instruction file is relevant to the user's question, offer
  `/strategic-partner-plugin:context-file-scan` explicitly; otherwise stay silent.

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

**Termination:** Finish after the useful orientation when no decision belongs
to the user. Use `AskUserQuestion` only for a concrete choice surfaced by the
live state; never manufacture a startup menu.

**Provider selection** (ask when the session topic involves implementation prompts):

If the session will involve crafting implementation prompts (most SP sessions do),
ask the user which model provider executors will target:

> "Which provider will run your implementation sessions?"
> Options: [Claude/Anthropic (Recommended)] [OpenAI/Codex] [Google/Gemini]

Store the answer for the session. When crafting prompts, load the matching
guide from `references/provider-guides/`. If the user doesn't know or says
"mixed", default to Claude format (most structured, degrades gracefully).

This question is asked ONCE per session, not per prompt.

**Cross-model carve-out:** if `review_policy` is set or suspected, do not ask this
provider-selection question during orientation. Ask the build/review direction at the
first build transition instead, after hiding unavailable directions.

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
- 📌 A concise project-wide convention is agreed and must load in every future session
- 🔄 A rule is being violated repeatedly and needs a reusable guardrail
- 🔖 A release or verification process changed in a way every session must know immediately

Do not propose a CLAUDE.md update for session journeys, implementation reports,
commit lists, ticket histories, file lists, browser-verification trails, local/unpushed
status, or detailed architectural rationale. Run the Instruction Placement Gate first:
those usually belong in `.handoffs/`, Serena memory, `.backlog/`, `.prompts/`, or
`.claude/rules/`.

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
│  CLAUDE.md         │  concise project-wide instructions needed in      │
│                    │  every session                                     │
├────────────────────┼───────────────────────────────────────────────────┤
│  .claude/rules/    │  path-specific rules                             │
│                    │  (e.g., "all files in src/api/ must...")          │
├────────────────────┼───────────────────────────────────────────────────┤
│  Auto-memory       │  session learnings, user preferences             │
├────────────────────┼───────────────────────────────────────────────────┤
│  .handoffs/        │  current session state, continuation prompts     │
│                    │  implementation reports, journey/status detail    │
├────────────────────┼───────────────────────────────────────────────────┤
│  .prompts/         │  implementation prompts organized by milestone   │
├────────────────────┼───────────────────────────────────────────────────┤
│  .scripts/         │  runnable operational scripts                    │
├────────────────────┼───────────────────────────────────────────────────┤
│  .sp-managed       │  repo-local contract for strategy/planning        │
│                    │  artifacts SP may manage after local activation   │
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
> "Placement gate says this belongs in CLAUDE.md because every future session must
> know the release rule. Preflight passes. Proposed text: [exact text]."
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
