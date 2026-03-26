<p align="center">
  <img src="assets/images/banner.png" alt="Strategic Partner - Chief of Staff for Claude Code" width="100%">
</p>

[![Version](https://img.shields.io/badge/version-4.8.0-blue)](CHANGELOG.md)

# strategic-partner

> Every other tool executes. This one decides **what** to execute.

A strategic advisory skill for Claude Code. It sits between you and your implementation tools — asking the right questions, crafting scoped prompts, routing tasks to the right skill, and tracking decisions across sessions. You think with it. Other tools build what it specifies.

---

## The problem: context dilution

Claude's instruction-following quality degrades as context fills up. The more tool results, file reads, and back-and-forth accumulate in a single session, the less reliably Claude follows its original instructions. This is called **context dilution**.

Most workflows ignore this. You open one session, plan and build in the same window, and by the time you're deep into implementation, the careful thinking from earlier has been pushed out by hundreds of tool calls. Decisions get made mid-build, often too late. When context fills, everything is lost.

The strategic partner solves this by splitting planning and execution into separate sessions — persistent advisory context where decisions accumulate, and ephemeral execution context where clean context matters most.

---

## How it works

### Two sessions, one loop

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

You describe what you need. The SP asks clarifying questions, then delivers a self-contained prompt targeting the right skill with the right model. You paste that prompt into a fresh session — full context window, zero baggage. When it finishes, you report back. The SP reviews what landed, extracts lessons, and crafts the next prompt.

**The SP never builds. The executor never decides.** That separation is what makes both sessions effective.

### Fast lane for small tasks

Not every task needs the full cycle. When a task passes a 5-question simplicity assessment (no design judgment, no ambiguity, no cross-cutting concerns), the SP can dispatch it to a sub-agent directly — same fresh context, without the copy-paste overhead. The SP still crafts the prompt, still reviews the result.

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

You paste Phase 1 into a **new terminal tab** — it runs — you come back and say "done." SP reviews the git log, then gives you Phase 2. Repeat until the feature ships.

### The key difference

| Aspect | Normal session | `/strategic-partner` session |
|--------|---------------|------------------------------|
| **How it works** | You ask, Claude builds | You ask, SP **plans**, writes the brief, the right tool executes |
| **Big tasks** | One session does everything, falls apart at scale | Work **broken into focused phases**, each scoped and self-contained |
| **Decisions** | Discovered mid-build, often too late | **Surfaced before any work starts** |
| **Knowledge** | Dies when the session ends | **Carries forward** via Serena memory and handoffs |
| **Tool selection** | You pick the tool | SP **routes to the right tool** based on what the task needs |
| **Context** | Fills up silently, progress lost | SP **monitors context** and preserves state before it degrades |

---

## Quick start

### Install

```bash
# Via npx (recommended)
npx skills add https://github.com/JimmySadek/strategic-partner

# Via skillshare
npx skillshare install https://github.com/JimmySadek/strategic-partner

# Manual — clone to your preferred skills directory
git clone https://github.com/JimmySadek/strategic-partner.git <your-skills-dir>/strategic-partner
```

### Run

```
/strategic-partner
```

The skill loads an advisory persona, scans your project, and asks what you're working on.

### Resume from a previous session

```
/strategic-partner .handoffs/onboarding-flow-0304-1430.md
```

### Aliases

`/strategic-partner`, `/advisor`, `/sp` all invoke the same skill.

---

## What's included

The SP operates through a lean core (SKILL.md) that loads reference material on demand:

- **Strategic advisory and prompt crafting** — the core loop: think, plan, route, craft, review
- **Skill and MCP routing** — builds a routing matrix from your installed tools and picks the best match per task
- **Cross-session memory** — uses Serena to persist decisions, conventions, and codebase knowledge across sessions
- **Context handoff management** — monitors context pressure and preserves full session state before it degrades
- **Anti-sycophancy and cognitive patterns** — direct communication style with named thinking heuristics for architecture and trade-off decisions
- **Provider-specific prompt formatting** — adapts prompt structure for Claude, OpenAI, and Gemini targets

<details>
<summary>Full file tree</summary>

```
strategic-partner/
  SKILL.md                              # Lean hub — identity, core behaviors, routing dispatch
  commands/
    help.md                             # Subcommand reference
    sync-skills.md                      # Skill inventory sync
    handoff.md                          # Context handoff trigger
    status.md                           # Status briefing
    update.md                           # Version check + self-update
  references/
    startup-checklist.md                # Identity commands, env vars, fire-and-verify agents
    prompt-crafting-guide.md            # Routing tree, parallelization check, quality gates
    context-handoff.md                  # Env var baseline, two-tier thresholds, split writes
    orchestration-playbook.md           # Model selection, parallelization heuristics, worktree isolation
    skill-routing-matrix.md             # Curated base matrix + delta-update procedure
    partner-protocols.md                # Session naming, /insights, version bumps, partner adaptation
    hooks-integration.md                # Hook events, JSON configs, phased rollout
    companion-script-spec.md            # Python context monitor architecture (spec only)
    cognitive-patterns.md               # Named thinking heuristics for architecture and trade-offs
    provider-guides/
      anthropic.md                      # Claude XML prompt format template
      openai.md                         # GPT-5.4 prompt format template
      google.md                         # Gemini Markdown prompt format template
  assets/templates/
    prompt-template.md                  # Implementation prompt skeleton
    handoff-template.md                 # Session handoff skeleton (with /insights section)
  docs/
    v4.0-implementation-decisions.md    # Decision log for audit findings F1-F12
```

</details>

The `commands/` directory is auto-linked to `~/.claude/commands/strategic-partner/` on first run — no manual setup needed.

---

## Subcommands

| Command | What it does |
|---------|-------------|
| `/strategic-partner:help` | List all subcommands |
| `/strategic-partner:sync-skills` | Rebuild **routing matrix** from system context, show diff against previous |
| `/strategic-partner:handoff` | Trigger a **context handoff** with split writes |
| `/strategic-partner:status` | Where we stand, what's done, what's next |
| `/strategic-partner:update` | Check for **updates** and self-update to latest version |

---

## Requirements

- **Claude Code** — the skill runs inside Claude Code sessions
- **Serena MCP** (recommended) — for cross-session memory and semantic code navigation
- **Context7 MCP** (optional) — for library documentation lookup

The skill works without Serena, but loses cross-session memory and semantic code navigation. CLAUDE.md ownership and prompt crafting work regardless.

---

## Staying updated

### Automatic check

Every SP session checks for updates in the background. If a newer version exists:

> Strategic Partner **v4.8.0** available (you have v4.7.0). Run `/strategic-partner:update` to update.

### Update command

```
/strategic-partner:update
```

Checks the latest version, shows what changed, and runs the update. Detects whether you installed via skillshare or git clone and uses the right method. After updating, it re-links any new subcommand files automatically.

### GitHub notifications

For release announcements with full changelogs:

1. Go to [github.com/JimmySadek/strategic-partner](https://github.com/JimmySadek/strategic-partner)
2. Click **Watch** > **Custom** > check **Releases** > **Apply**

---

## Troubleshooting

| Scenario | What happens | What to do |
|---|---|---|
| **Serena MCP unavailable** | Cross-session memory and semantic navigation disabled | SP falls back to Grep/Glob. Memory features degrade but prompt crafting works. |
| **Skills missing** | Routing matrix can't match a task to an installed skill | SP routes to built-in Agent types (always available) or suggests installing the skill. |
| **Hooks not configured** | Context monitoring relies on self-assessment only | SP uses self-assessed thresholds instead of the PreCompact hook backstop. Consider adding hooks for reliability. |
| **Sub-agents hit permission walls** | Background agents can't prompt for approval — WebFetch, Bash, and cross-directory reads fail silently | SP runs a permission pre-flight on startup that detects missing permissions and proposes adding them. One-time fix. |
| **Implementation session fails** | Executor reports errors or incomplete work | Report back to the SP. It will diagnose, rewrite the prompt with a different approach, and suggest retry. |

---

## What this is not

- Not an **orchestrator** — it can dispatch small tasks to sub-agents, but its primary role is deciding what to build and routing to the right tool.
- Not a **skill catalogue**. It knows when to use the skills you already have.
- Not a **memory system**. It uses Serena for storage, but the point is knowing what to remember and when to bring it back.
- Doesn't **replace** your implementation skills. Just gives them better prompts.

---

## License

MIT
