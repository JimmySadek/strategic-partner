<p align="center">
  <img src="assets/images/banner.png" alt="Strategic Partner - Chief of Staff for Claude Code" width="100%">
</p>

# strategic-partner

> Every other tool executes. This one decides what to execute.

A Chief of Staff skill for Claude Code. It owns your CLAUDE.md, crafts implementation prompts, routes tasks to the right skill or agent, manages cross-session memory, and handles context handoffs before you lose state. It never writes a line of source code.

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

The skill loads an advisory persona, scans your project, reads Serena memories, and asks what you're working on. From there, it thinks with you and writes prompts for you to run in separate implementation sessions.

---

## Why this exists

There are thousands of Claude Code skills. They write code, run tests, review PRs, orchestrate agents. strategic-partner does none of that. It figures out what your next session should do: which skill to use, what files to read first, what the prompt should say. It owns your CLAUDE.md, manages Serena memories, and doesn't touch source code. Closest thing I can compare it to is a Chief of Staff. It doesn't do the work. It makes sure the work gets done right.

The ecosystem has plenty of tools for doing. Nothing for deciding.

---

## What you get

Here's what a typical advisory session looks like:

```
You:  "I need to add WebSocket support to the API"

SP:   Reads your codebase structure from Serena memory.
      Checks the routing matrix — this is a multi-file feature.
      Asks: "This touches 4 files. Want a single /feature-dev session
      or a phased /gsd approach?"

You:  "Phased"

SP:   Crafts 3 implementation prompts:
      1. /gsd:research-phase — explore existing transport layer
      2. /gsd:plan-phase — design WebSocket integration
      3. /gsd:execute-phase — build it

      Each prompt is self-contained with:
      - Exact files to read first
      - Project constraints from CLAUDE.md
      - Verification checklist
      - Expected commit message

      Saves them to .prompts/v2.0/ and gives you a
      copy-pasteable launcher for each.
```

You paste each prompt into a fresh session. The advisor stays in the current session for follow-up, course corrections, and the next round of prompts.

---

## Features

- **Writes prompts, not code.** Every implementation task gets a self-contained prompt for a separate session.
- **Owns your CLAUDE.md** and updates it as the project evolves.
- **Picks the right skill, agent, or MCP** for each task, with reasoning.
- **Graduated context handoff protocol** — soft at 70%, hard at 75%, emergency at 85%.
- **Maintains a live registry** of your installed skills, MCPs, and agent types.
- **Formats prompts for the target model** — XML for Claude, Markdown for Gemini.
- **Strict firewall between thinking and building.** No exceptions for "small fixes."

---

## How it works

### The advisory loop

```
Advisor crafts prompt → You open new session → You run prompt
                                                     ↓
Advisor crafts next  ← Advisor reviews results ← You report back
```

The advisor doesn't cross into implementation. You say "just fix it," it writes a prompt for fixing it. Advisory sessions think, implementation sessions build.

### Implementation firewall

Two checkpoints, both mandatory:

1. **Request checkpoint** — When you ask to "fix", "change", or "build" something targeting source code, the advisor stops and crafts a prompt instead of reaching for the Edit tool.
2. **Tool checkpoint** — Before any file write, the advisor checks: is this `.prompts/`, `.handoffs/`, or CLAUDE.md? If it's source code, it stops and crafts a prompt.

### Startup sequence

On every invocation, the advisor:

1. Checks for existing handoff files (continuation vs fresh start)
2. Scans your ecosystem — installed skills, MCPs, agent types, hooks
3. Loads routing matrices (which skill for which task)
4. Reads Serena memories for project context
5. Presents a situation summary and asks what to work on

### Context handoffs

When context fills up, the advisor writes a handoff file to `.handoffs/` with:
- What was accomplished
- Key decisions and their reasoning
- Pending implementation prompts
- A continuation prompt you paste into a fresh session

The continuation prompt's first line is `/strategic-partner .handoffs/[filename]` so the advisor persona restores immediately.

---

## What's included

```
strategic-partner/
  SKILL.md                              # Skill definition (600 lines)
  references/
    skill-routing-matrix.md             # Task → skill mapping with model affinity
    mcp-routing-matrix.md               # MCP tool routing with fallback chains
    prompt-crafting-guide.md            # Prompt format standards and examples
    orchestration-playbook.md           # Model selection and parallelization rules
    context-handoff.md                  # Full handoff procedure and templates
    startup-checklist.md                # Internal startup verification
  assets/templates/
    prompt-template.md                  # Implementation prompt skeleton
    handoff-template.md                 # Session handoff skeleton
```

These aren't filler. The advisor loads them at startup and actually uses them for routing and prompt formatting.

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

Loads the full advisor persona with startup sequence.

### With a handoff file

```
/strategic-partner .handoffs/websocket-api-0304-1430.md
```

Resumes from a previous session's handoff.

### Subcommands

| Command | What it does |
|---------|-------------|
| `/strategic-partner:help` | List all subcommands |
| `/strategic-partner:sync-skills` | Compare installed skills against routing matrix, flag gaps |
| `/strategic-partner:handoff` | Trigger a context handoff with split writes |
| `/strategic-partner:status` | Where we stand, what's done, what's next |

### Aliases

`/strategic-partner`, `/advisor`, `/sp` all invoke the same skill.

---

## Requirements

- **Claude Code** — the skill runs inside Claude Code sessions
- **Serena MCP** (recommended) — for cross-session memory and semantic code navigation
- **Context7 MCP** (optional) — for library documentation lookup

The skill works without Serena, but loses cross-session memory and semantic code navigation. CLAUDE.md ownership and prompt crafting work regardless.

---

## What this is not

- Not an orchestrator. It doesn't spawn agents. It tells you which orchestrator to reach for.
- Not a skill catalogue. It knows when to use the skills you already have.
- Not a memory system. It uses Serena for storage, but the point is knowing what to remember and when to bring it back.
- Doesn't replace your implementation skills. Just gives them better prompts.

---

## Limitations

- Advisory sessions use up context without producing code. For a quick bug fix, skip this and use `/gsd:quick`.
- The routing matrix is manually maintained. Install a new skill and it won't show up in routing until the matrix gets updated.
- Prompt quality depends on how well the advisor knows your project. First sessions go better after Serena onboarding.
- The firewall feels rigid when you just want to change one line. That's intentional, but it takes some getting used to.

---

## License

MIT
