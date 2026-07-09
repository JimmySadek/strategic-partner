# 🔗 Hooks Integration Guide

Reference file for the strategic-partner advisor. Comprehensive hooks strategy
for proactive session management. Phased rollout from essential to advanced.

## Current Plugin Event Map (Claude Code 2.1.205)

This plugin does not depend on skill-frontmatter lifecycle timing. Its
`hooks/hooks.json` uses the current plugin hook surface documented by Anthropic:

| Boundary | Official event | Authoritative input | Plugin behavior |
|---|---|---|---|
| Typed slash command | `UserPromptExpansion` | `command_name`, `command_args`, `prompt` | Arm startup and inject the floor before expansion reaches Claude |
| Model-invoked skill | `PreToolUse` on `Skill` | `tool_name`, `tool_input.skill` | Arm startup and inject the same floor before the Skill runs |
| Resident advisor | `SessionStart` | `source`, optional `agent_type` | Use `agent_type` first; settings-file detection is compatibility fallback |
| Older/direct fallback | `UserPromptSubmit` | `prompt` | Preserve older activation behavior and relay prior log-only rhythm findings |
| Assistant response end | `Stop` | `last_assistant_message`, `stop_hook_active` | Block once when startup or closure is wholly absent; all older rhythm findings remain log-only |

Hook commands use exec form: `command: "bash"` plus an `args` array containing
`${CLAUDE_PLUGIN_ROOT}/hooks/entry.sh` and the event name. Anthropic recommends
this shape for plugin paths because it passes each argument without shell
quoting. `UserPromptExpansion` covers typed commands that bypass Skill
`PreToolUse`; Stop returns `{"decision":"block","reason":"..."}` on exit 0
and checks `stop_hook_active` before any second block.

Current references:
- https://code.claude.com/docs/en/hooks
- https://code.claude.com/docs/en/hooks-guide
- https://code.claude.com/docs/en/plugins-reference

The historical skill-frontmatter sections below remain useful for the
standalone install's archaeology. They are not the plugin's runtime map.

```
┌──────────────────────────────────────────────────────────────────────┐
│  SP Hooks Rollout                                                     │
│                                                                       │
│  Phase 1 (Essential)      Phase 2 (Monitoring)    Phase 3 (Advanced) │
│  ┌───────────────────┐   ┌──────────────────┐    ┌────────────────┐  │
│  │ 🛡️ PreToolUse    │   │ 🤖 SubagentStart │    │ 🔧 ConfigChange│  │
│  │    (identity) ✅  │   │ 🤖 SubagentStop  │    │ ❌ PostToolUse │  │
│  │ 🚨 PreCompact     │   │ 💬 UserPrompt    │    │    Failure     │  │
│  │    (user-owned)   │   │    Submit ✓     │    │ 🔌 Custom      │  │
│  │ 🚀 SessionStart   │   └──────────────────┘    └────────────────┘  │
│  │  (unverified)     │                                                │
│  │ 🛑 Stop ✓        │                                                │
│  └───────────────────┘                                               │
│  ✅ = shipping in SKILL.md frontmatter  ✓ = confirmed-viable        │
│  ◄── implement first    ◄── visibility      ◄── power users         │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 🔧 Hook Delivery

Hooks are delivered via **SKILL.md frontmatter** (skill-scoped — see limitations
below). Claude Code reads the `hooks:` section at skill load time and registers
them for the **active lifecycle of that skill**. Per Anthropic's hooks
documentation (https://code.claude.com/docs/en/hooks), these hooks are scoped
to the component's lifecycle and only run while that component is active.

This is appropriate for PreToolUse hooks that fire during tool calls made
while the skill is invoked (the SP's identity guard is exactly this pattern —
see Phase 1 below), but **NOT for SessionStart hooks**, which fire once at
Claude Code session start before any skill activates. v5.9.0 investigated
shipping a SessionStart hook via SKILL.md frontmatter, confirmed empirically that
it never fires (the skill is not yet active at session start), and removed it —
see the 🚀 SessionStart section below for the full write-up.

### Why Frontmatter (not settings.json)

| Approach | Ships with skill? | Scope | Maintenance |
|---|---|---|---|
| SKILL.md frontmatter ✅ | Yes — travels with the skill file | Session (active while skill is loaded) | Zero — automatic on skill load |
| `.claude/settings.json` ❌ | No — gitignored, per-machine | Persistent (all sessions) | Manual install + update |

Frontmatter hooks are the correct mechanism for skill-owned behavior. Settings.json
hooks are appropriate for user-owned customizations that should persist independently
of any skill.

### Skill-dir resolution (there is no `CLAUDE_SKILL_DIR`)

`${CLAUDE_SKILL_DIR}` is **NOT** a real Claude Code runtime variable. v5.4.1
confirmed it is unset in hook execution contexts (which is why the PreToolUse
guard was inlined into SKILL.md frontmatter rather than delegated to an external
script). Empirical testing in the SP model's Bash runtime confirms it is also
unset there — `echo "$CLAUDE_SKILL_DIR"` returns an empty string. `CLAUDE_PROJECT_DIR`
and `CLAUDE_PLUGIN_ROOT` are similarly unset in SKILL.md frontmatter hooks and
the SP model's own Bash runtime. Plugin hooks are different: Claude Code sets
`CLAUDE_PLUGIN_ROOT` there, and SP's plugin packaging uses it to reach
`hooks/entry.sh`.

Two patterns work in place of it:

1. **Inside SKILL.md frontmatter hooks** — INLINE the hook logic directly in the
   `command: |` block. Do NOT reference external scripts via any env var. The
   PreToolUse guard in SKILL.md follows this pattern. A standalone script file
   may coexist in `hooks/` for testing and documentation (see
   `hooks/guard-impl.sh`), but the inline version is the execution path.

2. **Inside prose Bash snippets the SP model runs at startup** — resolve the
   install dir via the stable command symlinks created by `setup`:

   ```bash
   SP_ANY_CMD=$(ls "${HOME}/.claude/commands/strategic-partner/"*.md 2>/dev/null | head -1)
   if [ -n "$SP_ANY_CMD" ]; then
     SP_SKILL_DIR=$(dirname "$(dirname "$(perl -MCwd=abs_path -e 'print abs_path(shift)' "$SP_ANY_CMD" 2>/dev/null)")")
     # ... use $SP_SKILL_DIR ...
   fi
   ```

   The positive-if-block wrapper (rather than an early-exit guard with a
   bare `return`) keeps the snippet copy-safe: `return` only works inside a
   function or a sourced script, so a user pasting it into a standalone
   `bash script.sh` invocation would hit an error. This is the same pattern
   used by `references/startup-checklist.md`.

   The `perl -MCwd=abs_path` call resolves the symlink chain to the actual
   command file path; two `dirname` calls walk up from `commands/some.md` to
   the install dir. `perl` is base on every macOS and Linux, so this works
   without GNU coreutils — unlike `readlink -f`, whose `-f` flag is a GNU
   extension that stock/older macOS `readlink` lacks. This works on all
   install paths (skillshare, git clone, alternate dirs) because `setup`
   always creates the symlinks at that canonical
   `$HOME/.claude/commands/strategic-partner/` location.

> **Historical note:** CHANGELOG v5.4.1 documents the discovery that
> `${CLAUDE_SKILL_DIR}` is not honored by Claude Code; the PreToolUse guard was
> inlined that release. CHANGELOG v5.9.0 documents the completion of its removal
> from all non-historical references (startup-checklist.md prose snippets and
> this section) and the investigation/removal of the SessionStart hook
> attempt — see the 🚀 SessionStart section below.

---

## 🔴 Phase 1: Essential Hooks

These hooks provide the **minimum viable integration** for reliable session management.
Implement these first.

**2026-04-30 update:** The confirmed-working set from skill frontmatter is broader than
originally framed. PreToolUse is shipping. UserPromptSubmit and Stop are additionally
confirmed as firing from skill frontmatter on CC 2.1.123 — see the Stop section below
and the validated canonical pattern section further down.

### 🛡️ PreToolUse — Identity Guard (shipping)

**Event**: Fires before Edit / Write / MultiEdit / NotebookEdit / Bash /
Serena write-mutating tools, **only while the SP skill is active**.

**SP Behavior**: Blocks implementation source-file mutations with exit code 2
unless the path is in SP's built-in managed set or in an activated repo-local
`.sp-managed` stewardship contract. Built-ins include `.prompts/`, `.handoffs/`,
`.scripts/`, `.backlog/`, docs-shaped `specs/` artifacts, context files,
release docs, `.claude-plugin/plugin.json`, and
`output-styles/strategic-partner-voice.md`. Repo contracts require **local activation**
outside the repo; a cloned `.sp-managed` file is only a proposal.
See `stewardship-contract.md`.

This is the structural enforcement behind the SP's "never edits implementation
source files" identity rule while still letting each repo grant SP stewardship
over its own decisions, interviews, benchmarks, and planning artifacts.

**Delivery**: Inlined directly in SKILL.md frontmatter under
`hooks: PreToolUse:` as a `command: |` block. Standalone reference script at
`hooks/guard-impl.sh` is kept in sync for testing. Skill-scoped lifecycle is
correct here — the guard needs to fire only while the SP is active (that is
when it must block SP-initiated source edits); PreToolUse hooks fire during
tool calls made while the skill is invoked, which matches the desired scope.

> **🔮 Future consideration — `permissionDecision` for clearer block reasons.**
> The current guard blocks with a bare exit code 2 (a non-zero exit that tells
> Claude Code to stop the tool call). Claude Code hooks docs
> (https://code.claude.com/docs/en/hooks) confirm PreToolUse hooks can return a
> richer control surface instead: a `hookSpecificOutput.permissionDecision`
> field accepting `allow` / `deny` / `ask` / `defer`, paired with a
> `permissionDecisionReason` string. Migrating the guard from raw exit-2 to
> `permissionDecision: deny` with a reason would let it surface WHY a source
> edit was blocked rather than just blocking it. This is a note only — the
> working guard is unchanged in this release, and the no-`${CLAUDE_*}`-env-vars
> guard (see the Skill-dir resolution section above) applies regardless of
> which block mechanism is used.

---

### 🚀 SessionStart — investigated in v5.9.0, pending cold-start re-verification (2026-04-30 update)

**TL;DR**: v5.9.0 investigated a SessionStart hook in SKILL.md frontmatter,
observed it did not fire, and removed it. The 2026-04-30 hook audit confirmed
that PreToolUse, PostToolUse, UserPromptSubmit, and Stop DO fire from skill
frontmatter on CC 2.1.123 — but SessionStart was NOT re-tested in that audit
(a cold-start session was not run). The original "architecturally incompatible"
conclusion may be confounded by the matcher / invocation gotchas discovered
on 2026-04-30 (see the "Skill-frontmatter hook gotchas" section below). Cold-start
verification is recommended before locking either way on SessionStart. For now,
the SP's contribution to context-handoff timing on large-window sessions remains
a pure **advisory note** delivered in orientation — see `startup-checklist.md`
Step 5 "Context advisory" bullet and `context-handoff.md` § Environment Baseline.

**Why it may not fire (lifecycle scope — pending re-verification)**: Per Anthropic's
hooks documentation (https://code.claude.com/docs/en/hooks), hooks declared in a
component's frontmatter are **scoped to that component's lifecycle and only run
while that component is active**. SessionStart fires at Claude Code session start —
before any skill activates. A SessionStart hook declared in a skill's frontmatter
is therefore registered for an event that, by the harness's own lifecycle rules,
may not fire for that skill. The v5.9.0 evidence:

- An instrumented SessionStart hook inlined in `SKILL.md` frontmatter was
  tested on a fresh Claude Code session invoked via `/strategic-partner`. The
  hook's trace line (`/tmp/sp-hook-trace.log`) never appeared — the hook did
  not fire.
- Of all skills installed at `~/.claude/skills/` on the development machine,
  only the SP declared SessionStart in SKILL.md frontmatter. Other
  well-established skills (including ones previously cited as precedents)
  have no `hooks:` section at all or use only tool-lifecycle events.
- Issue anthropics/claude-code#17688 (OPEN, labeled `bug`, 22 comments)
  reports that even PreToolUse hooks in SKILL.md frontmatter fail within
  plugins on CC 2.1.5 — confirming the skill-frontmatter hook surface has
  known failure modes (see Phase 1 gotchas below).

**2026-04-30 caveat:** The 2026-04-30 audit found that the v5.9.0 zero-firings
result for Stop (a separate lifecycle event) was a false negative caused by
the invocation gotcha — the skill had not been re-invoked after SKILL.md edits,
so the hooks block was not re-registered. SessionStart was not re-tested in
that audit because a cold-start session is required, but the same gotcha
could explain the v5.9.0 SessionStart result. Re-test with a clean cold-start
invocation before concluding SessionStart is permanently incompatible.

**What IS real**: `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` is a documented harness
env var (https://code.claude.com/docs/en/env-vars.md) honored at Claude Code
startup from the launching shell. Setting `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=5`
via `export` before launching `claude` works — empirical test confirmed
compaction fires almost immediately on the resulting session. This is a
**user-side shell concern**, not a skill-side automation. The SP does not
ship any mechanism to set it, recommend bash snippets for it, or install it
into user shells — changing it globally would cause surprise compaction in
long sessions users want to keep running. That is a footgun the SP
deliberately avoids.

**What the SP does instead**: On 1M-context sessions (Opus 4.8 or Opus 4.7,
or any model run with `SP_CONTEXT_WINDOW=1M` exported — opusplan's plan phase
stays 200K), the SP surfaces an informational
note in orientation: retrieval reliability degrades above ~256K tokens
(known Anthropic autocompact issues #34332, #42375, #43989 make the
default ~95% threshold behave inconsistently above that point), so the user
may want to plan handoff timing accordingly. No settings are changed, no
commands are run. The note is situational awareness; the SP's session-end
detection and handoff protocol (SKILL.md § Continuity Stewardship) remain
the mechanism that translates awareness into action. See
`startup-checklist.md` Step 5 and `context-handoff.md` § Environment
Baseline for the exact copy and trigger conditions.

---

### 🚨 PreCompact (user-owned, optional)

**Event**: Fires when Claude Code reaches the autocompact threshold (by
default, approximately 95% of the session's context window, per Anthropic
documentation at https://code.claude.com/docs/en/env-vars.md). Threshold
configuration is entirely user-owned — SP does not set or recommend a value.
See the 🚀 SessionStart section above for why the SP cannot manage this
setting from within a skill.

**SP Behavior (if the user configures this hook in their own `settings.json`):**
```
┌─ PreCompact Emergency Sequence ─────────────────────┐
│  1. 🛑 Extract session state immediately            │
│  2. 📂 Write handoff to .handoffs/[topic-slug]      │
│  3. 💾 Save critical decisions + pending prompts     │
│  4. 🧠 Write session summary to Serena memory       │
│  5. 🏷️ Suggest user finalize name: /rename sp-[topic]│
│  6. 💬 Present continuation prompt (AskUserQuestion) │
│  7. ✅ System compacts regardless — SP's job is done │
└──────────────────────────────────────────────────────┘
```

**Configuration (user-owned, not shipped with the skill):**
```json
{
  "hooks": {
    "PreCompact": [
      {
        "type": "command",
        "command": "echo 'CONTEXT_THRESHOLD_REACHED' >> /tmp/sp-context-alerts.log",
        "description": "SP context threshold alert - triggers handoff preparation"
      }
    ]
  }
}
```

PreCompact is a Claude Code session lifecycle event — it is NOT skill-scoped,
so a PreCompact hook in SKILL.md frontmatter would have the same lifecycle
mismatch as SessionStart. If a user wants this behavior, they add it to their
own `~/.claude/settings.json` where it is genuinely session-scoped.

Independent of whether the user configures a PreCompact hook, the SP's
session-end detection and handoff protocol (SKILL.md § Continuity Stewardship)
remain the primary mechanism for preserving session state. The PreCompact
hook is a belt-and-suspenders backstop, not a required dependency.

---

### 🛑 Stop — confirmed firing from skill frontmatter on CC 2.1.123 (superseded 2026-04-30)

The Stop hook was removed in v5.0.0 because it was being used for session-end
detection — the wrong scope for a hook that fires on every turn. A v5.14.0 spike
explored restoring it as a response-end validator for three structural rules
(AUQ-must-be-AUQ, first-person tool-availability claims, fence-write coupling),
but a soak-mining of 105 production JSONL transcripts found zero observable
firings. Without confidence the hook was actually running in production, the
runtime validator was pulled and the rules moved to release-time enforcement
via Layer 3 (the transcript lint at `tests/lint-transcripts.sh`).

**2026-04-30 update — v5.14.0 zero-firings conclusion overturned:** The
2026-04-30 hook audit produced empirical Stop FIRED trace lines from skill
frontmatter on CC 2.1.123. The v5.14.0 zero-firings result was a false negative
caused by the invocation gotcha (see "Skill-frontmatter hook gotchas" below):
the skill's SKILL.md had been edited to add the Stop hook, but the skill had
not been re-invoked, so the hooks dispatcher held the pre-edit hooks block and
Stop was never registered. After re-invoking the skill via the Skill tool,
Stop fired reliably on every assistant turn. Verbatim trace log evidence from
`/tmp/sp-hook-audit-trace.log` (Round 4, 2026-04-30):

```
[2026-04-30T11:17:19Z] PreToolUse-Bash-literal FIRED   (once: true honored)
[2026-04-30T11:17:21Z] PostToolUse-Bash-literal FIRED  (after 1st Bash)
[2026-04-30T11:18:15Z] PostToolUse-Bash-literal FIRED  (after 2nd Bash)
[2026-04-30T11:18:39Z] PostToolUse-Bash-literal FIRED  (after 3rd Bash)
[2026-04-30T11:19:39Z] Stop FIRED                       (end of assistant turn)
[2026-04-30T11:19:40Z] UserPromptSubmit FIRED           (user's next message)
```

Note also: GitHub issue anthropics/claude-code#19225 was closed as "not planned"
with the claim that Stop never fires from skill frontmatter. That claim is
**empirically overturned** by the trace evidence above. The project may want to
open a follow-up comment on #19225 with the trace log as counter-evidence.

**Current status:** Stop hooks DO fire from skill frontmatter on CC 2.1.123 per
current-version empirical evidence. Consider re-introducing a Stop-based runtime
validator for SP per-turn rhythm enforcement (AUQ-must-be-AUQ, tool-availability
claims, fence-write coupling) in v5.15.0+. The three rules themselves remain
enforced by Layer 3 at release time — see the Hook Delivery Summary below. A
Stop-based per-turn validator would be belt-and-suspenders, catching violations
earlier than the release-gate lint.

**Layer 3 enforcement** (unchanged, still active): `tests/lint-transcripts.sh`
runs three structural checks at release time over `.handoffs/*.md` files and
JSONL transcripts since the last release tag. Exit 0 if clean; exit 1 with
per-violation output if violations found. Wired into `claudedocs/release-process.md` Step 2a.

---

## ⚠️ Skill-frontmatter hook gotchas (CC 2.1.x)

Discovered 2026-04-30 during a multi-round hook audit at `~/sp-hook-sandbox/` using
a test skill at `~/.claude/skills/sp-hook-audit/`. These two gotchas explain most
prior zero-firings results.

### Gotcha 1 — Matcher syntax: wildcards and alternation may silently fail

Regex-style matcher values (`.*`, possibly pipe-alternation like `Edit|Write`) appear
to silently fail hook registration in some invocation contexts, leaving the hook
unregistered with no error message.

**Forms with known failure risk:**
```yaml
hooks:
  PreToolUse:
    - matcher: ".*"          # wildcard — silently fails in tested contexts
      hooks:
        - type: command
          command: "..."
```

**Form that works reliably (literal tool name):**
```yaml
hooks:
  PreToolUse:
    - matcher: "Bash"        # literal — confirmed firing CC 2.1.123
      hooks:
        - type: command
          command: "..."
```

**For multiple tools, use multiple entries instead of alternation:**
```yaml
hooks:
  PreToolUse:
    - matcher: "Edit"
      hooks:
        - type: command
          command: "..."
    - matcher: "Write"
      hooks:
        - type: command
          command: "..."
```

**Important exception — SP's own guard:** The SP's existing PreToolUse guard uses
pipe-alternation `Edit|Write|MultiEdit|NotebookEdit|Bash|mcp__plugin_serena_serena__`
and is empirically verified firing on this same Claude Code version (the guard
demonstrably blocks `/tmp/` Bash redirects with exit code 2 in normal use). The
isolated "alternation + first-invocation" failure mode was not re-tested; the
Rounds 1–2 failures may have been invocation-related rather than matcher-related.
Recommendation: use literal matchers + multiple entries for new hooks until an
isolated re-test resolves the pipe-alternation question.

### Gotcha 2 — Invocation, not mtime: hooks re-bind on skill invocation, not file edit

Editing SKILL.md does NOT re-register its hooks. The `system-reminder` skill-list
refreshes the skill's description immediately on file save, giving the impression
the skill was reloaded — but the hook dispatcher holds the **original `hooks:` block**
from the last invocation. Edits to the `hooks:` section take effect only when:

1. The skill is explicitly re-invoked (slash command `/strategic-partner` or Skill tool call), or
2. Claude Code is restarted.

**Practical implication:** When testing or updating a hook, always re-invoke the skill
after editing SKILL.md. This was the root cause of the v5.14.0 Stop zero-firings result
and may also explain the v5.9.0 SessionStart result.

---

## ✅ Validated canonical pattern (CC 2.1.123, 2026-04-30)

Copy-pasteable YAML covering the four events confirmed firing from skill frontmatter
in the 2026-04-30 audit. Use this as the baseline for new hooks. Note: SessionStart
is NOT included — it was not empirically verified in this audit round.

```yaml
hooks:
  PreToolUse:
    - matcher: "Bash"            # literal matcher — confirmed firing
      hooks:
        - type: command
          once: true             # fires once per session (remove for per-call)
          command: |
            echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] PreToolUse-Bash FIRED" \
              >> /tmp/sp-hook-trace.log
    - matcher: "Edit"            # one entry per tool for new patterns
      hooks:
        - type: command
          command: |
            echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] PreToolUse-Edit FIRED" \
              >> /tmp/sp-hook-trace.log
  PostToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: |
            echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] PostToolUse-Bash FIRED" \
              >> /tmp/sp-hook-trace.log
  UserPromptSubmit:              # non-tool event — no matcher field
    - type: command
      command: |
        TURNS=$(cat /tmp/sp-turn-count.txt 2>/dev/null || echo 0)
        echo $((TURNS+1)) > /tmp/sp-turn-count.txt
        echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] UserPromptSubmit FIRED (turn $((TURNS+1)))" \
          >> /tmp/sp-hook-trace.log
  Stop:                          # fires at end of every assistant turn
    - type: command
      command: |
        echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Stop FIRED" \
          >> /tmp/sp-hook-trace.log
```

**Key rules from the audit:**
- Use absolute paths in `command:` fields — `${CLAUDE_SKILL_DIR}` and similar env vars
  are NOT set in the hook execution environment (see GitHub #36135 and the "Skill-dir
  resolution" section above). Use `${HOME}/...` or hard-coded absolute paths.
- Re-invoke the skill after every SKILL.md edit that touches the `hooks:` block (Gotcha 2).
- Use `once: true` in PreToolUse to avoid running expensive startup checks on every tool call.

---

## 🟡 Phase 2: Monitoring Hooks

These hooks add **visibility** into session activity for better advisory decisions.

**2026-04-30 update:** Configuration examples below show `settings.json` format because
these events have not been individually tested from skill frontmatter. They may be
configurable in skill frontmatter (user-owned OR skill-owned) following the canonical
pattern once verified — the settings.json format is not the only option. Events like
UserPromptSubmit are confirmed firing from frontmatter (see Phase 1 Stop section trace
log); SubagentStart/SubagentStop have not been tested from frontmatter specifically.

### 🤖 SubagentStart / SubagentStop

**Event**: Fires when a sub-agent is spawned or completes.

**SP Behavior:**
- 📊 Track which agents are currently running (agent dashboard)
- 📝 Log agent purpose, model, and spawn time
- ✅ On SubagentStop: capture result summary, verify completion (fire-and-verify)
- ❌ Detect agent failures and surface them proactively

**Configuration:**
```json
{
  "hooks": {
    "SubagentStart": [
      {
        "type": "command",
        "command": "echo \"AGENT_START: $(date +%H:%M:%S)\" >> /tmp/sp-agent-tracking.log",
        "description": "Track sub-agent lifecycle for SP advisory"
      }
    ],
    "SubagentStop": [
      {
        "type": "command",
        "command": "echo \"AGENT_STOP: $(date +%H:%M:%S)\" >> /tmp/sp-agent-tracking.log",
        "description": "Track sub-agent completion for fire-and-verify pattern"
      }
    ]
  }
}
```

**💡 Value**: Enables the fire-and-verify pattern from `startup-checklist.md`.
Without these hooks, agent verification requires polling or inline checks.

---

### 💬 UserPromptSubmit

**Event**: Fires when the user sends a message.

**SP Behavior:**
- 🔢 Count exchange turns for context budget estimation
- 📊 Estimate context consumption per exchange
- ⏳ Trigger context monitoring checks (see `context-handoff.md` thresholds)

**Configuration:**
```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "type": "command",
        "command": "TURNS=$(cat /tmp/sp-turn-count.txt 2>/dev/null || echo 0); echo $((TURNS+1)) > /tmp/sp-turn-count.txt",
        "description": "SP exchange counter for context budget estimation"
      }
    ]
  }
}
```

---

## 🟠 Phase 3: Advanced Hooks

These hooks provide deeper integration for **power users** and diagnostics.

**2026-04-30 update:** Configuration examples below show `settings.json` format.
These events (ConfigChange, PostToolUseFailure) have not been individually tested
from skill frontmatter. They may be configurable in SKILL.md frontmatter following
the canonical pattern once verified — `settings.json` is not required if frontmatter
proves sufficient for these events.

### 🔧 ConfigChange

**Event**: Fires when Claude Code settings change during a session.

**SP Behavior:**
- 🔍 Detect changes that affect advisory (e.g., effort level changed externally)
- ⚠️ Warn if SP identity settings are overridden (`/effort` lowered, `/color` changed)
- 🛡️ Track permission mode changes that might affect prompt execution

**Configuration:**
```json
{
  "hooks": {
    "ConfigChange": [
      {
        "type": "command",
        "command": "echo \"CONFIG_CHANGED: $(date +%H:%M:%S)\" >> /tmp/sp-config-tracking.log",
        "description": "Monitor settings changes affecting SP advisory"
      }
    ]
  }
}
```

---

### ❌ PostToolUseFailure

**Event**: Fires when a tool call fails.

**SP Behavior:**
- 📝 Log tool failures for diagnostic purposes
- 🔍 Detect patterns (e.g., repeated Serena failures → language server issue)
- 💡 Surface actionable failure patterns to user proactively
- 🔄 Trigger fallback strategies (see RULES.md, Serena Fallback Strategy)

**Configuration:**
```json
{
  "hooks": {
    "PostToolUseFailure": [
      {
        "type": "command",
        "command": "echo \"TOOL_FAILURE: $TOOL_NAME $(date +%H:%M:%S)\" >> /tmp/sp-error-tracking.log",
        "description": "SP tool failure diagnostics and pattern detection"
      }
    ]
  }
}
```

---

### 🔌 Custom Hooks (File-Based Signaling)

For SP-specific events that don't map to built-in hook events:

```
┌──────────────────┬──────────────────────────────┬──────────────────────────┐
│  Signal          │  File                        │  Purpose                 │
├──────────────────┼──────────────────────────────┼──────────────────────────┤
│  🚨 Context      │  /tmp/sp-context-alerts.log  │  Companion script alerts │
│  🤖 Agents       │  /tmp/sp-agent-tracking.log  │  Sub-agent lifecycle     │
│  📝 Files        │  /tmp/sp-file-tracking.log   │  Modified files list     │
│  🔢 Turns        │  /tmp/sp-turn-count.txt      │  Exchange counter        │
│  ❌ Errors       │  /tmp/sp-error-tracking.log  │  Tool failure patterns   │
└──────────────────┴──────────────────────────────┴──────────────────────────┘
```

---

## 💬 Hook Delivery Summary

(2026-05-01 update — v5.15.0 ships UserPromptSubmit + Stop hooks alongside the
existing PreToolUse identity guard)

The SP ships **three frontmatter hooks** (all inlined in SKILL.md). All three
were empirically verified to fire on Claude Code 2.1.123 per the 2026-04-30
hook audit (see trace log in the Stop section above).

| Hook | Event | Matcher | Purpose | Ships via | Status |
|---|---|---|---|---|---|
| Identity guard | PreToolUse | `Edit\|Write\|MultiEdit\|NotebookEdit\|Bash\|mcp__plugin_serena_serena__` | Block implementation source-file mutations; allow built-in SP artifacts and locally activated `.sp-managed` paths | SKILL.md frontmatter | Shipping ✅ |
| Floor sentinel | UserPromptSubmit | (non-tool event, no matcher) | Inject minimum-floor reminder per user turn | SKILL.md frontmatter | Shipping ✅ (v5.15.0) |
| Rhythm enforcer | Stop | (non-tool event, no matcher) | Enforce 5 per-turn rules (AUQ-as-AUQ, identity-reset announcements after agent dispatch returns, tool-availability claims, fence-write coupling, floor-signal acknowledgment) | SKILL.md frontmatter | Shipping ✅ (v5.15.0) |

PreToolUse fires during tool calls while the skill is active — correct for
blocking source edits initiated by the SP. UserPromptSubmit and Stop fire as
session-level events; both confirmed firing from frontmatter on CC 2.1.123 per
2026-04-30 audit (see trace log in the Stop section above).

> **⏱️ UserPromptSubmit timeout — floor sentinel must stay under 30s.**
> UserPromptSubmit hooks have a shorter timeout than other events: 30 seconds
> for `command` hooks, versus the 600-second default elsewhere (per Claude Code
> hooks docs, https://code.claude.com/docs/en/hooks). The floor sentinel runs
> on this event, so its bash must complete well inside that window. By
> inspection it does: the SKILL.md hook declares `timeout: 10000` (10s), the
> full check runs only once per session (a `/tmp` marker short-circuits every
> later turn), the single network call is `curl --max-time 8` against the
> GitHub releases API, and the git probes are each bounded to 1s via
> `gtimeout`/`timeout`. Worst case is the curl's ~8s, comfortably under 30s.
> Anything added to `hooks/floor-check.sh` must preserve that headroom — no
> unbounded network or filesystem step. The hook stdin JSON also carries
> `effort` and `permission_mode` fields on supporting events (docs above); the
> floor sentinel does not read them today, but they are available if a future
> check needs the current permission mode.

**Layer 3 (release-time transcript lint):** `tests/lint-transcripts.sh` runs
four behavioral checks plus a voice-pattern scan at release time over
`.handoffs/*.md` files and (when available) the JSONL transcripts since the
last release tag:

- AUQ-must-be-AUQ (prose questions outside `AskUserQuestion` tool calls)
- First-person tool-availability claims without a verified call
- Fence-write coupling (`══ START 🟢 COPY ══` fence without a preceding
  `Write` to `.handoffs/last-prompts/[N].md` in the same turn)
- Identity-reset announcement (assistant turn following an Agent/Task
  tool_result must include "Back in advisory mode" or "Dispatch complete.
  I am back in strategic-partner mode" — implemented via the shared
  `validate_identity_reset` function in `hooks/lib/validators.sh`, mirroring
  Stop rule 2)
- Voice patterns (raw line refs, `Layer N` without gloss, `Direction N`,
  `deliverable N`, function-call notation in prose, incident IDs) — these
  are mechanical violations, separate from the four behavioral rules above.

Exit 0 if clean; exit 1 with per-violation output if any violations found.
Wired into `claudedocs/release-process.md` release process Step 2a as the release-gate backstop.
Layer 3 lints transcripts AFTER the fact — it does not lint `SKILL.md` itself
and is not equivalent to per-turn runtime enforcement.

All other hook types discussed in this file are either:

- **Pending re-verification** (SessionStart — v5.9.0 found it did not fire;
  2026-04-30 audit did not re-test it; may warrant a cold-start re-test before
  locking either way — see Phase 1 above)
- **Considered but not shipped** (SessionEnd — evaluated as optional in v5.15.0
  design but not shipped; empirical verification of SessionEnd from skill
  frontmatter could not be completed within v5.15.0 work scope; deferred to
  v5.16.0 — see `references/closure-floor.md` for the verification gap)
- **Optional user-owned configurations** (PreCompact and all Phase 2 / Phase 3
  hooks that have not been verified from frontmatter) — if a user wants PreCompact
  logging, SubagentStart tracking, or any other monitoring hook, they may add it
  to their own `~/.claude/settings.json` OR (once verified) to SKILL.md frontmatter.
  The SP does not auto-install hooks into user settings and does not modify them.

---

## 📎 Cross-Reference

### Project files

| Reference | Relationship |
|---|---|
| `startup-checklist.md` | Step 5 context advisory + identity commands |
| `context-handoff.md` | Advisory framing for autocompact threshold (user-owned) |
| `companion-script-spec.md` | Historical spec — deprecated in v5.9.0, retained for reference |
| `orchestration-playbook.md` | Agent patterns that SubagentStart/Stop tracks |

### GitHub issues (anthropics/claude-code)

| Issue | Status | What it means for SP |
|---|---|---|
| [#17688](https://github.com/anthropics/claude-code/issues/17688) | OPEN (labeled `bug`) | Plugin-context skill hooks broken — PreToolUse hooks fail within plugins. SP's plugin packaging does **not** rely on that surface: the guard is wired through plugin `hooks.json` to the session-gated hook chain. Evidence lives in `claudedocs/plugin-readiness-report.md` § Validation record: strict manifest validation passed, UserPromptSubmit/Stop fired from plugin hooks, and a live SP trial blocked a source edit with the production guard message. Both skill and plugin installs are supported. |
| [#19225](https://github.com/anthropics/claude-code/issues/19225) | Closed "not planned" | Originally claimed Stop never fires from skill frontmatter. **Empirically overturned** by 2026-04-30 audit trace evidence (see Stop section above). Consider opening a follow-up comment on the issue with the `/tmp/sp-hook-audit-trace.log` evidence. |
| [#36135](https://github.com/anthropics/claude-code/issues/36135) | Open | `${CLAUDE_SKILL_DIR}` substitution broken in frontmatter hook commands. Workaround: use absolute paths (`/Users/yourname/...`) or `${HOME}/...`. This matches SP's existing Provisional Guard ("Don't use `${CLAUDE_*}` env vars in hook commands"). |
