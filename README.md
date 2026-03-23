<p align="center">
  <img src="assets/images/banner.png" alt="Strategic Partner - Chief of Staff for Claude Code" width="100%">
</p>

[![Version](https://img.shields.io/badge/version-4.3.0-blue)](CHANGELOG.md)

# strategic-partner

> Every other tool executes. This one decides **what** to execute.

Think of it as your **Chief of Staff** — a strategic partner, literally. It helps you **plan**, **structure your thoughts**, and **keep track of your project**. It even recommends the **next best action**. It owns your **CLAUDE.md**, crafts **implementation prompts**, routes tasks to the **right skill or agent**, manages **cross-session memory**, and handles **context handoffs** before you lose state. It reads your installed **skills**, **MCP servers**, **agent types**, and **hooks** from the system context — so when it routes a task, it already knows what's available on your machine.

**v4.0** brings **hooks integration** for proactive session management, **structured context handoffs** that preserve full session state before context degrades, a **fire-and-verify** pattern that catches silent agent failures, and a **lean hub architecture** that cuts SKILL.md context by ~40% while keeping all core behaviors inline. Prompt crafting now enforces **mandatory quality gates** — routing decision trees, parallelization checks, and post-craft verification — so every prompt the SP delivers is properly routed and complete.

It captures your **git state** on startup, recommends optimal session settings (`/effort high`, `/rename`), verifies commits landed after implementation sessions, and structures every response around **diagrams first, tables second, prose last**. The ecosystem has plenty of tools for doing. Nothing for **deciding**.

---

## Quick start

Install:

```bash
npx skills add https://github.com/JimmySadek/strategic-partner
```

Run:

```
/strategic-partner
```

The skill loads an **advisory persona**, scans your project, and asks what you're working on. From there, it thinks with you and writes prompts for you to run in **separate implementation sessions**.

---

## How it works

### You always have two sessions open

This is the core operating model. It's how the skill is designed to be used.

```
┌─────────────────────────────────┐     ┌─────────────────────────────────┐
│  SESSION 1: ADVISOR (persistent) │     │  SESSION 2: EXECUTOR (ephemeral) │
│                                  │     │                                  │
│  /strategic-partner              │     │  /feature-dev                    │
│                                  │     │  (or whatever skill SP chose)    │
│  • Thinks with you               │     │  • Builds what SP specified      │
│  • Asks the right questions      │     │  • Follows the prompt exactly    │
│  • Crafts implementation prompts │     │  • Commits when done             │
│  • Routes to the right skill     │     │  • You close this when finished  │
│  • Tracks decisions & state      │     │                                  │
│  • Stays open across phases      │     │  Opens fresh for each prompt.    │
│                                  │     │  No accumulated context.         │
│  YOU KEEP THIS ONE OPEN.         │     │  DISPOSABLE.                     │
└──────────────┬───────────────────┘     └──────────────┬───────────────────┘
               │                                        │
               │  1. SP crafts prompt ──────────────►   │
               │                                        │  2. You paste & run
               │                                        │
               │  4. SP reviews, plans next  ◄──────    │  3. You report back
               │                                        │     what happened
               └────────────────────────────────────────┘
```

**Session 1** is your **persistent brain** — it accumulates decisions, tracks what's done, and knows the full picture. You never close it until the work is complete (or context runs out, at which point it hands off to a fresh advisory session).

**Session 2** is a **disposable executor** — you open it, paste the prompt, let it run, report the results back to Session 1, and close it. Each prompt gets a fresh session with a full context window and zero baggage.

### The loop in practice

```
YOU:    "We need to add JWT auth to the API"

SP:     Asks 3 clarifying questions.
        Crafts a prompt targeting the right skill.
        Presents it in a copy-paste block:

        ══════════════ START 🟢 COPY ══════════════
        /[skill from routing matrix]

        <context>...</context>
        <instructions>...</instructions>
        <verification>...</verification>

        Expected commit: "feat(auth): add JWT middleware"
        ══════════════= END 🛑 COPY ═══════════════

        "Run this in a new session and come back with the results."

YOU:    Open a new terminal tab. Paste the prompt. Let it run.
        Come back to Session 1: "Done, committed on main."

SP:     Checks git log. Reviews what landed. Extracts lessons.
        Crafts the next prompt (or says "we're done").
```

**The SP never builds. The executor never decides.** That separation is what makes both sessions effective.

### Why two sessions?

This isn't a quirky workflow — it's how Claude Code is designed to work best.

Anthropic's own documentation recommends **breaking complex tasks into focused sessions** rather than cramming everything into one. Claude's instruction-following quality degrades as context fills up — a phenomenon called **context dilution**. The more tool results, file reads, and back-and-forth accumulate in a single session, the less reliably Claude follows its original instructions.

The two-session model directly addresses this:

| One session does everything | Two-session model |
|---|---|
| Advisory context consumed by implementation | Advisory context preserved for decisions |
| Tool calls and file reads fill up context fast | Executor gets a **fresh context window** per prompt |
| Instructions diluted by accumulated noise | Each prompt is the **first thing** the executor sees |
| Decisions made mid-build, often too late | Decisions made before any code is written |
| No record of what was decided or why | SP tracks decisions, routes to Serena memory |
| When context fills, everything is lost | SP hands off structured state before context degrades |

**The executor session is disposable by design.** A fresh session means the implementation prompt lands in a clean context window with zero competing instructions — maximum instruction adherence. This is why Anthropic recommends using **focused, self-contained prompts** over long conversational chains for implementation work.

The SP skill automates this pattern: it keeps the **planning context** persistent (where decisions accumulate) and makes the **execution context** ephemeral (where clean context matters most).

### Deliverable routing

Not everything needs a Claude session. The SP decides what format fits:

| Task type | Output | Where it goes |
|-----------|--------|---------------|
| Needs **AI judgment** (code, debugging, architecture) | Implementation prompt | `.prompts/` |
| **Deterministic** commands (config, installs, setup) | Runnable shell script | `.scripts/` |
| **Mixed** | Both — script for mechanical part, prompt for judgment part | Both directories |

### Context handoffs

When your advisory session approaches its context limit, the SP preserves everything:

| Context Level | What happens |
|---|---|
| **60-70%** | SP monitors context, mentions handoff is approaching |
| **70%+** | Full handoff — SP writes state to `.handoffs/` with a continuation prompt |
| **70% (system)** | PreCompact hook fires as a reliable backstop |

The handoff file contains: **decisions made**, **pending prompts**, **pending scripts**, **`/insights` analysis**, and a **continuation prompt** that restores the advisor persona in a fresh Session 1.

---

## What you get

Your team needs to build a **user onboarding flow** for a SaaS product. Here's what happens:

You open Claude Code and type:

```
/strategic-partner
```

Then say: *"We need to build an onboarding flow"*

**Strategic Partner responds:**

> Before we build — a few things:
> - This touches **auth**, **UI**, **backend state**, and **email triggers**. That's 4 concern areas.
> - Your **CLAUDE.md** says you're using React + Tailwind. No component library for modals yet.
> - Is this for **new signups only**, or also re-onboarding existing users?
>
> Options: **Single big session** / **Break into 3 phases** / **Start with just the UI skeleton first**

You say: *"3 phases, new signups only"*

**SP delivers 3 ready-to-paste prompts:**

| Phase | Prompt | What it does |
|-------|--------|-------------|
| **1 — Research** | *[research skill from routing matrix]* | Read these 5 files. Map existing **auth flow**. Identify where **onboarding state** should live. |
| **2 — Build UI** | *[feature skill from routing matrix]* | Build **WelcomeScreen** + 3-step wizard components. Use mock data only. **No backend calls yet.** |
| **3 — Wire It Up** | *[execution skill from routing matrix]* | Connect wizard to **user state**. Trigger **welcome email** on step 3 completion. |

*Skill names are never hardcoded — the SP builds a routing matrix from your actual installed skills and picks the best match for each task.*

Each prompt has: **files to read first**, **constraints from CLAUDE.md**, **verification checklist**, **expected commit message**.

You paste Phase 1 into a **new terminal tab** → it runs → you come back and say "done." SP reviews the git log, then gives you Phase 2. You paste that into **another fresh session**. Repeat until the feature ships. The advisor session stays open throughout — it's your persistent planning layer.

---

## The key difference

| Aspect | Normal session | `/strategic-partner` session |
|--------|---------------|------------------------------|
| **How it works** | You ask → Claude builds | You ask → SP **plans** → writes the brief → the right tool executes |
| **Role** | Claude is a builder | SP is your **planning layer** — it decides, delegates, and tracks |
| **Big tasks** | One session does everything → falls apart at scale | Work is **broken into focused phases** — each one scoped and self-contained |
| **Decisions** | Discovered mid-build, often too late to change | **Surfaced before any work starts** — so you choose, not guess |
| **Knowledge** | Dies when the session ends | **Carries forward** — decisions, patterns, and context survive across sessions |
| **Tool selection** | You have to know which tool to use | SP **picks the right tool** based on what the task actually needs |
| **Manual steps** | Terminal commands or manual steps? Claude gives you a **list to follow yourself** | SP generates a **runnable script** — one command replaces a page of manual steps |
| **Context** | **Context** fills up silently — your progress and decisions are lost | SP **monitors your context** and preserves your state before it degrades |
| **Releases** | You track versions and milestones manually | SP **proposes version bumps** at the right moment and keeps commit history clean |

SP is a **senior tech lead** who asks the right questions before your team starts building — so you don't discover the problem halfway through.

---

## What's included

```
strategic-partner/
  SKILL.md                              # Lean hub (~540 lines) — identity, core behaviors, routing dispatch
  references/
    startup-checklist.md                # Identity commands, env vars, fire-and-verify agents
    prompt-crafting-guide.md            # Routing tree, parallelization check, quality gates
    context-handoff.md                  # Env var baseline, two-tier thresholds, split writes
    orchestration-playbook.md           # Model selection, parallelization heuristics, worktree isolation
    skill-routing-matrix.md             # Curated base matrix + delta-update procedure
    partner-protocols.md                # Session naming, /insights, version bumps, partner adaptation
    hooks-integration.md                # Hook events, JSON configs, phased rollout
    companion-script-spec.md            # Python context monitor architecture (spec only)
  assets/templates/
    prompt-template.md                  # Implementation prompt skeleton
    handoff-template.md                 # Session handoff skeleton (with /insights section)
  docs/
    v4.0-implementation-decisions.md    # Decision log for audit findings F1-F12
```

These aren't filler. The advisor **loads them on-demand** — the core SKILL.md (~440 lines) carries identity, core behaviors, and routing dispatch, while deep procedural content loads only when crafting prompts, routing edge cases, or preparing handoffs.

---

## Installation

### Via npx (recommended)

```bash
npx skills add https://github.com/JimmySadek/strategic-partner
```

### Via skillshare

```bash
npx skillshare install https://github.com/JimmySadek/strategic-partner
```

### Manual

Clone the repo into your skills directory:

```bash
git clone https://github.com/JimmySadek/strategic-partner.git ~/.config/skillshare/skills/strategic-partner
```

---

## Usage

### Main command

```
/strategic-partner
```

Loads the full **advisory persona** with startup sequence.

### With a handoff file

```
/strategic-partner .handoffs/onboarding-flow-0304-1430.md
```

Resumes from a **previous session's handoff**.

### Subcommands

| Command | What it does |
|---------|-------------|
| `/strategic-partner:help` | List all subcommands |
| `/strategic-partner:sync-skills` | Rebuild **routing matrix** from system context, show diff against previous |
| `/strategic-partner:handoff` | Trigger a **context handoff** with split writes |
| `/strategic-partner:status` | Where we stand, what's done, what's next |

### Aliases

`/strategic-partner`, `/advisor`, `/sp` all invoke the same skill.

---

## Requirements

- **Claude Code** — the skill runs inside Claude Code sessions
- **Serena MCP** (recommended) — for **cross-session memory** and semantic code navigation
- **Context7 MCP** (optional) — for library documentation lookup

The skill works without Serena, but loses **cross-session memory** and semantic code navigation. **CLAUDE.md ownership** and **prompt crafting** work regardless.

---

## Troubleshooting

| Scenario | What happens | What to do |
|---|---|---|
| **Serena MCP unavailable** | Cross-session memory and semantic code navigation disabled | SP falls back to Grep/Glob. Memory features degrade but prompt crafting works. |
| **Skills missing** | Routing matrix can't match a task to an installed skill | SP routes to built-in Agent types (always available) or suggests installing the skill. |
| **Hooks not configured** | Context monitoring relies on self-assessment only | SP uses self-assessed thresholds instead of the PreCompact hook backstop. Consider adding hooks for reliability. |
| **Sub-agents hit permission walls** | Background agents can't prompt for approval — WebFetch, WebSearch, and cross-directory reads fail silently | SP now specifies `mode` parameter on all agent spawns. If you still see failures, pre-approve `WebFetch` and `WebSearch` in `~/.claude/settings.json`. |
| **Implementation session fails** | Executor reports errors or incomplete work | Report back to the SP. It will diagnose, rewrite the prompt with a different approach, and suggest retry. |

---

## What this is not

- Not an **orchestrator**. It doesn't spawn agents. It tells you which orchestrator to reach for.
- Not a **skill catalogue**. It knows when to use the skills you already have.
- Not a **memory system**. It uses Serena for storage, but the point is knowing what to remember and when to bring it back.
- Doesn't **replace** your implementation skills. Just gives them better prompts.

---

## License

MIT
