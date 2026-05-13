<p align="center">
  <img src="assets/images/banner.png" alt="Strategic Partner - Chief of Staff for Claude Code" width="100%">
</p>

[![Version](https://img.shields.io/badge/version-6.5.0-blue)](CHANGELOG.md)

# strategic-partner

A strategic advisory skill for Claude Code (an installable add-on that extends Claude Code's behavior) that separates thinking from building. It thinks with you in one session — asking the right questions, challenging assumptions, framing problems before jumping to solutions — then packages implementation for fresh sessions where the full context window is available. Decisions persist. Context stays clean. The advisory persona is the primary deliverable, not the prompts.

> **What's new** — v6.5 fixes a real annoyance: when you start a Strategic Partner session, the advisor used to sometimes close its briefing with a bare prose line like "Ready when you are." instead of giving you a clickable menu of next-step options. Now startup briefings reliably end with a structured choice you pick from — the routing decision you owe goes in front of you, not in freeform. Under the hood, this is a new response shape built specifically for the startup moment plus a small set of bookkeeping cleanups that consolidate scattered rules into one canonical spot. See [CHANGELOG.md](CHANGELOG.md) for prior releases.

---

## The problem

AI coding assistants degrade as conversations grow. Every tool call, file read, and back-and-forth exchange pushes the original instructions further from the model's attention. By the time you're deep into implementation, the careful thinking from earlier has been diluted by hundreds of intermediate results.

Think of it like a meeting that started with a clear agenda but kept going for six hours. By hour four, decisions are being made on autopilot — not because anyone stopped caring, but because the original focus got buried under everything that came after.

Most workflows ignore this. You open one session, plan and build in the same window, and by the time you're in the weeds, decisions are being made mid-build with degraded instruction-following. When context fills up completely, everything is lost.

The strategic partner fixes this by enforcing a separation: persistent advisory context where decisions accumulate, and disposable execution context where clean context matters most.

---

## Who is this for

**Solo developers** — A second brain that interrogates your assumptions before you build, picks the right tool, and remembers decisions across sessions so you don't re-litigate them.

**Team leads** — Consistent prompt quality across implementation sessions, with a decision log that survives context resets. Your architectural intent carries forward even when execution happens in fresh windows.

**Non-technical PMs** — You can describe what you need in plain language. The advisor handles the translation into technical prompts, breaks large features into phased delivery, and reports back in terms you can act on. You never need to know which skill or model is best for a task.

---

## How it works

### Two sessions, one loop

**Strategic Partner (SP for short)** runs the advisor in one session. Your installed implementation skills (or background agents) execute in another.

```
+---------------------------------+     +---------------------------------+
|  SESSION 1: ADVISOR (persistent) |     |  SESSION 2: EXECUTOR (ephemeral) |
|                                  |     |                                  |
|  /strategic-partner              |     |  /feature-dev                    |
|                                  |     |  (or whatever skill SP chose)    |
|  - Thinks with you               |     |  - Builds what SP specified      |
|  - Challenges your assumptions   |     |  - Follows the prompt exactly    |
|  - Crafts implementation prompts |     |  - Commits when done             |
|  - Routes to the right skill     |     |  - You close this when finished  |
|  - Tracks decisions and state    |     |                                  |
|  - Stays open across phases      |     |  Opens fresh for each prompt.    |
|                                  |     |  No accumulated context.         |
|  YOU KEEP THIS ONE OPEN.         |     |  DISPOSABLE.                     |
+----------------+-----------------+     +----------------+-----------------+
                 |                                        |
                 |  1. SP crafts prompt ----------------> |
                 |                                        |  2. You paste & run
                 |                                        |
                 |  4. SP reviews, plans next  <--------- |  3. You report back
                 |                                        |     what happened
                 +----------------------------------------+
```

You describe what you need. The SP asks clarifying questions, then delivers a self-contained prompt targeting the right skill with the right model. You paste that prompt into a fresh session — full context window, zero accumulated baggage. When it finishes, you report back. The SP reviews what landed, extracts lessons, and crafts the next prompt.

**The SP never builds. The executor never decides.** That separation is what makes both work.

Before routing a single task, the SP runs a few invisible checks. It premise-checks every request against six trigger conditions (solution-shaped framing, missing problem statement, unverified assumptions inherited from prior sessions, etc.), presents alternatives where decisions are warranted, and verifies a small set of completion conditions before any prompt or dispatch fires. After every implementation cycle, it explicitly returns to planning mode so implementation momentum doesn't bleed into the next decision. The walk-through below shows what this looks like in practice.

### Optional background execution for small tasks

For small mechanical tasks, the SP may offer to dispatch the prepared prompt to a background agent instead of asking you to paste it into a fresh session. Same roles, same separation: SP decides what gets built and why; the agent executes what SP specifies. This optional shortcut is a delivery mechanism, not a personality change — the SP still thinks first, presents alternatives, and gets your consent before dispatching.

---

## What you get

Your team needs to build a **user onboarding flow** for a SaaS product. Here's what happens:

You open Claude Code and type:

```
/strategic-partner
```

Then say: *"We need to build an onboarding flow"*

**Strategic Partner responds:**

> **Premise challenge:** solution-shaped request — "onboarding flow" describes a feature, not a problem.
>
> Before we scope this — what user problem does onboarding solve? Are new users dropping off? Confused by the setup? Missing a key activation step?

You clarify: *"New signups aren't completing setup — 60% drop off before connecting their first data source."*

> Good. This touches **auth**, **UI**, **backend state**, and **email triggers** — 4 concern areas. Your CLAUDE.md says React + Tailwind, no component library for modals yet.
>
> **Path A (Minimal):** 3-step inline wizard, no modal, connects existing setup flow. Ships fast, might need rework later.
> **Path B (Recommended):** Dedicated onboarding route with progress tracking, broken into 3 phases. Solid foundation.
> **Path C (Lateral):** Skip the wizard — auto-detect the user's intent from their first actions and surface contextual setup prompts. Higher effort, potentially higher activation.
>
> I'd go with **Path B** — it balances speed with a foundation that won't need rework. Path C is interesting but unproven for your user volume.

You pick Path B. The SP delivers 3 ready-to-paste prompts:

| Phase | Target skill | What it does |
|-------|-------------|-------------|
| **1 — Research** | *[picked from your installed tools]* | Read 5 files, map existing auth flow, identify where onboarding state should live |
| **2 — Build UI** | *[picked from your installed tools]* | WelcomeScreen + 3-step wizard, mock data only, no backend calls yet |
| **3 — Wire up** | *[picked from your installed tools]* | Connect wizard to user state, trigger welcome email on step 3 completion |

Each prompt includes: files to read first, constraints from CLAUDE.md, verification checklist, [✅ SAFE]/[⚠️ RISK] labels on key recommendations, expected commit message, and explicit NOT-in-scope exclusions.

You paste Phase 1 into a **fresh Claude Code session**. It runs. You come back and say "done." The SP reviews the git log, then gives you Phase 2. Repeat until the feature ships.

### The key difference

| Aspect | Normal session | With the SP |
|--------|---------------|-------------|
| **Planning** | Discovered mid-build | Surfaced before any work starts |
| **Assumptions** | Unchallenged | Premise-checked, alternatives explored |
| **Big tasks** | One session, degrades at scale | Phased prompts, each with full context |
| **Knowledge** | Dies with the session | Persists via saved project notes and handoff files |
| **Tool selection** | You pick | SP picks dynamically from your installed tools |
| **Confidence** | Implicit | [✅ SAFE]/[⚠️ RISK] labels on recommendations |

---

## Supported Platforms

| Platform | Status | Notes |
|---|---|---|
| macOS 13.0+ | ✅ Fully supported | Primary development platform |
| Linux (GNU coreutils) | ✅ Fully supported | |
| Windows WSL2 | ✅ Fully supported | Recommended Windows path — inherits Linux support |
| Windows WSL1 | ✅ Supported | (Claude Code sandboxing unavailable per Anthropic) |
| Windows native (Git Bash / MSYS2 / Cygwin) | ⚠️ Experimental | Known symlink, interpreter, and install-path limitations — requires `SP_ALLOW_NATIVE_WINDOWS=1` env var to run `setup`. Use WSL2 if possible. |
| Windows native (cmd / PowerShell) | ❌ Unsupported | Claude Code itself requires a Bash-compatible shell |

---

## Quick start

### Install

```bash
# Via npx (recommended)
npx skills add https://github.com/JimmySadek/strategic-partner

# Manual — clone to your preferred skills directory
git clone https://github.com/JimmySadek/strategic-partner.git <your-skills-dir>/strategic-partner
```

### Setup

After install completes, change into the install directory and run setup:

```bash
cd /path/to/strategic-partner    # the directory created by npx or git clone
./setup
```

Registers subcommands with Claude Code. Optional: `./setup --audit-permissions` checks for permission gaps that cause friction in advisory sessions.

### Run

```
/strategic-partner
```

Resume from a previous session by passing a handoff file path:

```
/strategic-partner .handoffs/onboarding-flow-0304-1430.md
```

### Aliases

`/strategic-partner`, `/advisor`, `/sp` all invoke the same skill.

---

## What's included

The advisor operates through a lean core (SKILL.md) that loads reference material on demand:

- **Strategic advisory and prompt crafting** — the core loop: discover, challenge premises, present alternatives, route, craft, review. Prompts adapt to the target model (Anthropic XML, OpenAI Markdown, Gemini Markdown) and include reusable hallucination-prevention and scope-discipline blocks.
- **Pre-build decision discipline** — every request is premise-checked against six trigger conditions (solution-shaped framing, missing problem statement, unverified assumptions carried from prior sessions, etc.). Non-trivial tasks get three distinct alternatives (minimal / recommended / lateral) before any routing. Recommendations carry [✅ SAFE] or [⚠️ RISK] confidence labels so the executor knows which suggestions involve judgment.
- **Plain-English partnership voice** — opening sentences readable by a non-technical reader; decision questions surfaced as structured choice prompts with explicit options (not buried in prose); pause-at-every-decision instead of bundling multi-step transitions; visual aids (tables, ASCII diagrams) where they help comprehension; anti-sycophancy rules that name both failure modes — agreeing for no reason AND disagreeing for the appearance of independence.
- **Skill and tool picking** — the advisor builds an installed-tool picker from what you have available and selects the best match per task. The first specialist dispatch in a session is gated by a confirmation question whose option label names the chosen agent, so a wrong pick gets caught before the agent runs.
- **Cross-model adversarial review** — for high-stakes decisions (irreversible changes, large blast radius, unresolved disagreements), the advisor can dispatch curated briefs to OpenAI's Codex CLI for an independent second opinion, then synthesize a three-way perspective (your position, the advisor's, Codex's). Optional — requires Codex CLI installed.
- **Rules-file drift detection** — `/strategic-partner:context-file-scan` checks your project's `CLAUDE.md`, `AGENTS.md`, or `GEMINI.md` against 17 patterns of structural and behavioral drift (size breach, stale references, broken hybrid pattern, etc.). Interactive walk-through, report-only, and release-gate output modes.
- **Cross-session memory and handoffs** — saves substantive decisions to long-term memory at coherent stretches, captures session findings, promotes important findings to a persistent backlog with re-engagement at startup when conditions match, and produces full handoff files when context pressure rises so a fresh session can pick up exactly where the last one left off.
- **Optional background execution for small tasks** — for small, reversible tasks, the advisor can dispatch a prepared prompt to a background agent and surface a desktop notification when it completes, so you can walk away during the 3-5 minute window and come back to the conclusion.

### Under the hood

- **Implementation boundary** — a safety guard in Claude Code blocks accidental source edits in advisor sessions, paired with three behavioral gates (pre-build decision checklist, return-to-planning after execution, post-dispatch recovery)
- **Memory architecture** — stewards four persistence layers (`CLAUDE.md`, `.claude/rules/`, auto-memory, Serena memory) so decisions survive across sessions
- **Visible prompt quality checklist** — every crafted prompt renders a pass/fail table of 13 quality checks (skill routing, file context, deliverables, verification commands, etc.) before the prompt body, so dispatches can be audited without trusting hidden reasoning
- **Startup status check** — at session start and on each subcommand, a hook gathers a one-line snapshot (model, project conventions, memory, git state, version freshness, installed-tool picker freshness) and injects it into the advisor's context
- **1M context advisory (Opus 4.7)** — on 1M-context models, the advisor surfaces a one-time orientation note: known Anthropic issues cause erratic behavior above ~256K tokens; consider wrapping up or triggering handoff around 250K for reliable retrieval

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full file layout and mechanism detail.

---

## Subcommands

| Command | What it does |
|---------|-------------|
| `/strategic-partner:help` | List all subcommands |
| `/strategic-partner:copy-prompt` | Copy a recently emitted prompt to the OS clipboard |
| `/strategic-partner:handoff` | Trigger a context handoff with split writes |
| `/strategic-partner:status` | Where we stand, what's done, what's next |
| `/strategic-partner:update` | Check for updates and self-update to latest version |
| `/strategic-partner:codex-feedback` | Cross-model adversarial review via Codex CLI (GPT-5.5) |
| `/strategic-partner:context-file-scan` | Detect drift in `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` rules files (17 patterns) |
| `/strategic-partner:backlog` | View project backlog — parked ideas, deferred work, and future improvements |

---

## Requirements

- **Claude Code** — the skill runs inside Claude Code sessions
- **`jq`** — required for `/strategic-partner:context-file-scan` (the scanner uses `jq` for JSON output assembly). Install via `brew install jq` (macOS) or `apt install jq` / `dnf install jq` (Linux). The scanner exits with a clear error if `jq` is missing; other features work without it.
- **Serena MCP** (recommended) — for cross-session memory and semantic code navigation
- **Context7 MCP** (optional) — for library documentation lookup
- **Codex CLI** (optional) — for cross-model adversarial review

The skill works without Serena, but loses cross-session memory and semantic code navigation. `jq` is the only hard runtime dependency outside Claude Code itself.

---

## Staying updated

Every SP session checks for updates in the background and surfaces a one-line notice when a newer version is available. Run `/strategic-partner:update` to fetch the latest version — it detects whether you installed via skills or git clone, uses the right method, and re-runs `./setup` to refresh command registrations. When an update introduces new subcommands, restart your Claude Code session so the CLI picks up the new registrations.

---

## Troubleshooting

| Scenario | What happens | What to do |
|---|---|---|
| **Serena MCP unavailable** | Cross-session memory and semantic navigation disabled | SP falls back to Grep/Glob. Memory features degrade but prompt crafting works. |
| **Skills missing** | The installed-tool picker can't match a task to an installed skill | SP routes to built-in Agent types (always available) or suggests installing the skill. |
| **No automatic warning before context fills up** | SP relies on self-assessed thresholds and periodic checks | A user-owned hook (Claude Code's pre-fill warning event) can serve as an extra backstop if you choose to configure one. |
| **Sub-agents hit permission walls** | Background agents can't prompt for approval | Specify `mode` on every agent spawn. Pre-approve `WebFetch(*)` and `WebSearch(*)` in `~/.claude/settings.json` for research agents. Run `./setup --audit-permissions` to check for gaps. |
| **Implementation session fails** | Executor reports errors or incomplete work | Report back to the SP. It will diagnose, rewrite the prompt with a different approach, and suggest retry. |
| **Codex CLI not found** | Cross-model review unavailable | Install from [github.com/openai/codex](https://github.com/openai/codex) and run `codex login`. Feature is optional. |

---

## What this is not

- Not a **skill catalogue**. It knows when to use the skills you already have.
- Not a **memory system**. It stewards Claude Code's existing persistence layers — the point is knowing what to persist, where, and when to bring it back.
- Doesn't **replace** your implementation skills. It gives them better prompts, cleaner context, and challenged assumptions.

---

## License

MIT
