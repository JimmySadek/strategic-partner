<p align="center">
  <img src="assets/images/banner.png" alt="Strategic Partner - Chief of Staff for Claude Code" width="100%">
</p>

[![Version](https://img.shields.io/badge/version-4.0.0-blue)](CHANGELOG.md)

# strategic-partner

> Every other tool executes. This one decides **what** to execute.

Think of it as your **Chief of Staff** — a strategic partner, literally. It helps you **plan**, **structure your thoughts**, and **keep track of your project**. It even recommends the **next best action**. It owns your **CLAUDE.md**, crafts **implementation prompts**, routes tasks to the **right skill or agent**, manages **cross-session memory**, and handles **context handoffs** before you lose state. It reads your installed **skills**, **MCP servers**, **agent types**, and **hooks** from the system context — so when it routes a task, it already knows what's available on your machine.

**v4.0** brings **hooks integration** for proactive session management, **guardrailed compaction** to extend session life without full handoffs, a **fire-and-verify** pattern that catches silent agent failures, and a **lean hub architecture** that cuts SKILL.md context by ~40% while keeping all core behaviors inline. Prompt crafting now enforces **mandatory quality gates** — routing decision trees, parallelization checks, and post-craft verification — so every prompt the SP delivers is properly routed and complete.

It speaks to **engineers** in their language, to **PMs** in theirs, and to **founders** in theirs. It captures your **git state** on startup, recommends optimal session settings (`/effort high`, `/rename`), verifies commits landed after implementation sessions, and structures every response around **diagrams first, tables second, prose last**. The ecosystem has plenty of tools for doing. Nothing for **deciding**.

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

### The advisory loop

```
Advisor crafts prompt → You open new session → You run prompt
                                                     ↓
Advisor crafts next  ← Advisor reviews results ← You report back
```

The advisor doesn't cross into implementation. You say "just fix it," it writes a **prompt** for fixing it. Advisory sessions **think**, implementation sessions **build**.

### Deliverable routing

Not everything needs a Claude session. The SP decides what format fits:

| Task type | Output | Where it goes |
|-----------|--------|---------------|
| Needs **AI judgment** (code, debugging, architecture) | Implementation prompt | `.prompts/` |
| **Deterministic** commands (config, installs, setup) | Runnable shell script | `.scripts/` |
| **Mixed** | Both — script for mechanical part, prompt for judgment part | Both directories |

### Implementation firewall

Two checkpoints, both mandatory:

1. **Request checkpoint** — When you ask to "fix", "change", or "build" something targeting **source code**, the advisor stops and crafts a prompt instead of reaching for the Edit tool.
2. **Tool checkpoint** — Before any file write, the advisor checks: is this `.prompts/`, `.handoffs/`, `.scripts/`, or CLAUDE.md? If it's source code, it **stops** and crafts a prompt.

### Context handoffs

The SP monitors context usage and escalates through **three tiers**, backed by an environment variable that gives it a **reliable system signal** at 70%:

| Context Level | What happens |
|---|---|
| **65-72%** | Strategic compact — SP suggests `/compact` with focus instructions to extend the session |
| **72%+** | Full handoff — SP proposes writing state to `.handoffs/` via a direct question |
| **70% (system)** | PreCompact hook fires — SP intercepts for emergency handoff preparation |

The handoff file goes to `.handoffs/` with everything needed to continue: **decisions made**, **pending prompts**, **pending scripts**, **`/insights` analysis**, and a **continuation prompt** that restores the advisor persona in a fresh session.

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

You paste each prompt into a fresh session. The advisor stays in the current session for **follow-up**, **course corrections**, and the next round of prompts.

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
  SKILL.md                              # Lean hub (~440 lines) — identity, core behaviors, routing dispatch
  references/
    startup-checklist.md                # Identity commands, env vars, fire-and-verify agents
    prompt-crafting-guide.md            # Routing tree, parallelization check, quality gates
    context-handoff.md                  # Env var baseline, strategic compaction, split writes
    orchestration-playbook.md           # Model selection, parallelization heuristics, worktree isolation
    skill-routing-matrix.md             # Curated base matrix (~30 skills) + delta-update procedure
    partner-protocols.md                # Session naming, /compact guardrails, /insights, version bumps
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

## What this is not

- Not an **orchestrator**. It doesn't spawn agents. It tells you which orchestrator to reach for.
- Not a **skill catalogue**. It knows when to use the skills you already have.
- Not a **memory system**. It uses Serena for storage, but the point is knowing what to remember and when to bring it back.
- Doesn't **replace** your implementation skills. Just gives them better prompts.

---

## License

MIT
