# Skill Routing Matrix — Base Matrix & Delta Procedure

Reference file for the strategic-partner advisor. Ships a comprehensive base matrix
of skills, agent types, and behavioral modes, with a delta-update procedure for
discovering new or custom skills at runtime.

```
Load Base Matrix → Scan for NEW Skills → Build Delta Entries → Merge → Store in Serena → Diff on Continuation
```

---

## Matrix Format Specification

Each entry in the routing matrix follows this schema:

| Field | Description | Example |
|---|---|---|
| Task | Natural-language description of what the user wants | "Implement a focused feature" |
| Primary Skill | Exact invocation (slash command or Agent type) | `/feature-dev:feature-dev` or `⚙️ Agent:code-explorer` |
| Model | Recommended model for the task | Opus, Sonnet, or Haiku |
| When to Use Instead | Alternative skill for edge cases | "/sc:implement for simpler scope" |

---

## 📦 Curated Base Matrix

These are the commonly available skills and built-in Agent types pre-mapped. Load
this table at startup instead of building from scratch — covers the majority of routing needs.

### 🔧 Implementation & Feature Development

| Task | Primary Skill | Model | When to Use Instead |
|---|---|---|---|
| Quick single-file fix or change | `/gsd:quick` | Sonnet | Direct Edit tool for trivial changes |
| Focused feature (1-3 files, clear spec) | `/feature-dev:feature-dev` | Sonnet | `/sc:implement` for simpler scope |
| Complex feature with design phase | `/gsd:feature` | Opus→Sonnet | `/feature-dev` if no design phase needed |
| Implement from existing spec/plan | `/sc:implement` | Sonnet | `/feature-dev` for broader scope |
| Full-stack feature (frontend + backend) | `/gsd:fullstack` | Sonnet | Split into separate frontend/backend prompts |

### 🔍 Debugging & Investigation

| Task | Primary Skill | Model | When to Use Instead |
|---|---|---|---|
| Debug a complex bug | `/gsd:debug` | Opus | `⚙️ Agent:root-cause-analyst` for deep investigation |
| Root cause analysis | `⚙️ Agent:root-cause-analyst` | Opus | `/gsd:debug` for simpler bugs |
| Performance investigation | `⚙️ Agent:performance-engineer` | Sonnet | `/gsd:debug` if perf issue is a bug |

### ✅ Code Quality & Review

| Task | Primary Skill | Model | When to Use Instead |
|---|---|---|---|
| Review PR or changeset | `/code-review:code-review` | Sonnet | `⚙️ Agent:feature-dev:code-reviewer` for deeper review |
| Code cleanup and simplification | `/code-simplifier:code-simplifier` | Sonnet | `⚙️ Agent:refactoring-expert` for larger refactors |
| Large-scale refactoring | `⚙️ Agent:refactoring-expert` | Sonnet | `/code-simplifier` for single-file cleanup |
| Security audit | `⚙️ Agent:security-engineer` | Opus | `/code-review` if just checking for obvious issues |
| Comprehensive multi-domain code analysis | `/sc:analyze` | Sonnet | `⚙️ Agent:security-engineer` for security focus |
| Systematic code improvement | `/sc:improve` | Sonnet | `/code-simplifier` for single-file cleanup |
| Dead code removal, structure cleanup | `/sc:cleanup` | Sonnet | `/sc:improve` for quality-focused changes |
| Diagnose and resolve build/deploy issues | `/sc:troubleshoot` | Sonnet | `/gsd:debug` for complex code bugs |

### 🏗️ Architecture & Design

| Task | Primary Skill | Model | When to Use Instead |
|---|---|---|---|
| Design a new feature's architecture | `⚙️ Agent:feature-dev:code-architect` | Opus | `/sc:design` for API-level specs |
| Backend system design | `⚙️ Agent:backend-architect` | Opus | `⚙️ Agent:system-architect` for distributed systems |
| Scalable system architecture | `⚙️ Agent:system-architect` | Opus | `⚙️ Agent:backend-architect` for single-service scope |
| Frontend/UI architecture | `⚙️ Agent:frontend-architect` | Sonnet | `/frontend-design` for component-level work |
| DevOps and infrastructure design | `⚙️ Agent:devops-architect` | Opus | — |

### 🔍 Research & Exploration

| Task | Primary Skill | Model | When to Use Instead |
|---|---|---|---|
| Explore existing code before building | `⚙️ Agent:Explore` | Sonnet | Quick Grep/Glob for single-file lookups |
| Deep feature analysis, execution tracing | `⚙️ Agent:feature-dev:code-explorer` | Sonnet | `⚙️ Agent:Explore` for broad discovery |
| Deep research with multiple sources | `⚙️ Agent:deep-research-agent` | Opus | `⚙️ Agent:Explore` for codebase-only research |
| Requirements discovery | `⚙️ Agent:requirements-analyst` | Opus | Brainstorming mode for less formal discovery |
| Implementation planning | `⚙️ Agent:Plan` | Sonnet | `⚙️ Agent:feature-dev:code-architect` for design-heavy planning |

### 📝 Documentation & Teaching

| Task | Primary Skill | Model | When to Use Instead |
|---|---|---|---|
| Technical documentation | `⚙️ Agent:technical-writer` | Sonnet | Direct writing for simple docs |
| Explain code or concepts | `⚙️ Agent:learning-guide` | Sonnet | `⚙️ Agent:socratic-mentor` for guided learning |
| Educational guidance (Socratic) | `⚙️ Agent:socratic-mentor` | Sonnet | `⚙️ Agent:learning-guide` for direct explanation |
| Generate component, API, or feature docs | `/sc:document` | Sonnet | `⚙️ Agent:technical-writer` for comprehensive docs |
| Explain code, concepts, or system behavior | `/sc:explain` | Sonnet | `⚙️ Agent:learning-guide` for educational depth |

### 🧪 Testing & Quality Engineering

| Task | Primary Skill | Model | When to Use Instead |
|---|---|---|---|
| Testing strategy, edge case detection | `⚙️ Agent:quality-engineer` | Sonnet | `/gsd:test` for straightforward test writing |
| Write tests for existing code | `/gsd:test` | Sonnet | `⚙️ Agent:quality-engineer` for strategy-level work |

### 🎯 Multi-Expert & Strategic

| Task | Primary Skill | Model | When to Use Instead |
|---|---|---|---|
| Multi-expert business strategy | `⚙️ Agent:business-panel-experts` | Opus | Single-domain agent for focused questions |

### 🚀 Project Lifecycle

| Task | Primary Skill | Model | When to Use Instead |
|---|---|---|---|
| Start a new project from scratch | `/gsd:new-project` | Opus | — |
| Start a new milestone/version cycle | `/gsd:new-milestone` | Opus | — |
| Plan a project phase | `/gsd:plan-phase` | Sonnet | `/superpowers:writing-plans` for non-GSD projects |
| Execute a planned phase | `/gsd:execute-phase` | Sonnet | `/superpowers:executing-plans` for non-GSD |
| Check project progress, route next action | `/gsd:progress` | Sonnet | `/strategic-partner:status` for advisory context |
| Validate built features (UAT) | `/gsd:verify-work` | Sonnet | — |
| Audit milestone before archiving | `/gsd:audit-milestone` | Opus | — |
| Analyze codebase structure in parallel | `/gsd:map-codebase` | Sonnet | `⚙️ Agent:Explore` for lighter scan |
| Gather phase context before planning | `/gsd:discuss-phase` | Sonnet | — |
| Resume work from previous session | `/gsd:resume-work` | Sonnet | `/strategic-partner:handoff` in advisory sessions |
| Pause work and create context handoff | `/gsd:pause-work` | Sonnet | `/strategic-partner:handoff` in advisory sessions |

### 🎨 UI/Frontend

| Task | Primary Skill | Model | When to Use Instead |
|---|---|---|---|
| Full UI/UX design with styling guidance | `/ui-ux-pro-max` | Sonnet | `/frontend-design` for component-level work |
| Create polished frontend interfaces | `/frontend-design` | Sonnet | `/ui-ux-pro-max` for full design system |
| Review UI against Web Interface Guidelines | `/web-design-guidelines` | Sonnet | `/code-review` for non-UI review |
| React composition and component patterns | `/composition-patterns` | Sonnet | `/react-best-practices` for performance focus |
| React/Next.js performance optimization | `/react-best-practices` | Sonnet | `/sc:improve` for non-React optimization |

### 🔄 Workflow & Process

| Task | Primary Skill | Model | When to Use Instead |
|---|---|---|---|
| Interactive requirements discovery | `/sc:brainstorm` | Opus | `/superpowers:brainstorming` as behavioral wrapper |
| Generate implementation workflow from PRD | `/sc:workflow` | Sonnet | `/gsd:plan-phase` for phase-level planning |
| Provide development time/effort estimates | `/sc:estimate` | Sonnet | — |
| Multi-expert specification review | `/sc:spec-panel` | Opus | `/sc:business-panel` for business-focused review |
| Multi-expert business strategy analysis | `/sc:business-panel` | Opus | `/sc:spec-panel` for technical focus |

### 🔧 Git & DevOps

| Task | Primary Skill | Model | When to Use Instead |
|---|---|---|---|
| Git operations with smart commit messages | `/sc:git` | Sonnet | Direct git commands for trivial operations |
| GitHub PRs, issues, workflows, API queries | `/github-ops` | Sonnet | Direct `gh` CLI for quick one-liners |
| Build, compile, and package projects | `/sc:build` | Sonnet | Direct build commands if straightforward |

### 📄 Content & Publishing

| Task | Primary Skill | Model | When to Use Instead |
|---|---|---|---|
| Extract YouTube video transcripts | `/youtube-fetcher` | Haiku | — |
| Remove AI writing patterns from text | `/humanizer` | Sonnet | Manual editing for short passages |
| Publish files or sites to web instantly | `/here-now` | Sonnet | — |
| PDF extraction, creation, or manipulation | `/pdf` | Sonnet | — |

### ⚙️ Configuration & Meta

| Task | Primary Skill | Model | When to Use Instead |
|---|---|---|---|
| Configure Claude Code settings or hooks | `/update-config` | Sonnet | Direct settings.json edit if trivial |
| Customize keyboard shortcuts | `/keybindings-help` | Sonnet | — |
| Sync skills across AI CLI tools | `/skillshare` | Sonnet | — |
| Discover and install new skills | `/find-skills` | Haiku | — |
| Audit or improve CLAUDE.md files | `/claude-md-management:claude-md-improver` | Sonnet | `/claude-md-management:revise-claude-md` for targeted updates |
| Create, modify, or test AI skills | `/skill-creator:skill-creator` | Opus | `/superpowers:writing-skills` for behavioral guidance |
| Build apps with Claude API or Anthropic SDK | `/claude-api` | Sonnet | — |

### 🤖 Behavioral Modes (Superpowers)

NOTE: These are behavioral wrappers that modify HOW a session operates, not standalone
task skills. They're typically invoked at the START of a session alongside a task skill.

| Task | Primary Skill | Model | When to Use Instead |
|---|---|---|---|
| Creative exploration before building | `/superpowers:brainstorming` | Opus | `/sc:brainstorm` for structured requirements |
| Write multi-step implementation plans | `/superpowers:writing-plans` | Opus | `/gsd:plan-phase` for GSD-managed projects |
| Execute a written plan with checkpoints | `/superpowers:executing-plans` | Sonnet | `/gsd:execute-phase` for GSD workflows |
| TDD workflow (tests first) | `/superpowers:test-driven-development` | Sonnet | `/gsd:test` for standalone test writing |
| Systematic debugging with evidence | `/superpowers:systematic-debugging` | Opus | `/gsd:debug` for persistent debug sessions |
| Verify work before claiming done | `/superpowers:verification-before-completion` | Sonnet | — |
| Request formal code review | `/superpowers:requesting-code-review` | Sonnet | `/code-review` for PR-level review |
| Handle incoming review feedback | `/superpowers:receiving-code-review` | Sonnet | — |
| Complete and integrate a dev branch | `/superpowers:finishing-a-development-branch` | Sonnet | — |
| Isolate work in a git worktree | `/superpowers:using-git-worktrees` | Sonnet | — |
| Dispatch parallel independent agents | `/superpowers:dispatching-parallel-agents` | Sonnet | — |
| Agent-driven plan execution | `/superpowers:subagent-driven-development` | Sonnet | `/superpowers:executing-plans` if sequential |

### ⏱️ Recurring & Scheduled Tasks

| Task | Primary Skill | Model | When to Use Instead |
|---|---|---|---|
| Run a prompt on a recurring interval | `/loop` | Sonnet | `/schedule` for cron-based remote scheduling |
| Schedule recurring remote agents (cron) | `/schedule` | Sonnet | `/loop` for in-session polling |
| Process queued work items | `/do-work` | Sonnet | — |

### 🏠 Personal Automation (JARVIS)

NOTE: These are user-specific personal automation skills. Include in the matrix
for completeness but note they may not be present in all environments.

| Task | Primary Skill | Model | When to Use Instead |
|---|---|---|---|
| Morning briefing and vault synthesis | `/JARVIS:morning-briefing` | Sonnet | — |
| Scan folders into Obsidian vault | `/JARVIS:vault-seeder` | Sonnet | — |
| Process pending feedback items | `/JARVIS:jarvis-reactor` | Sonnet | — |

---

## Agent Type Routing (Always Available)

These are built-in Agent subtypes — available in every environment regardless of
installed skills. Always include these in the routing matrix.

| Agent Type | Model | Use For |
|---|---|---|
| `⚙️ Agent:Explore` | Sonnet | Quick codebase exploration, file discovery |
| `⚙️ Agent:Plan` | Sonnet | Implementation planning |
| `⚙️ Agent:general-purpose` | Sonnet | Multi-step research, code search |
| `⚙️ Agent:deep-research-agent` | Opus | Comprehensive research with multiple sources |
| `⚙️ Agent:feature-dev:code-explorer` | Sonnet | Deep feature analysis, execution path tracing |
| `⚙️ Agent:feature-dev:code-architect` | Opus | Feature architecture design |
| `⚙️ Agent:feature-dev:code-reviewer` | Sonnet | Code review with confidence filtering |
| `⚙️ Agent:quality-engineer` | Sonnet | Testing strategy, edge case detection |
| `⚙️ Agent:security-engineer` | Opus | Security audit, vulnerability analysis |
| `⚙️ Agent:backend-architect` | Opus | Backend system design |
| `⚙️ Agent:system-architect` | Opus | Scalable system architecture |
| `⚙️ Agent:python-expert` | Sonnet | Python implementation |
| `⚙️ Agent:refactoring-expert` | Sonnet | Code cleanup, technical debt |
| `⚙️ Agent:performance-engineer` | Sonnet | Performance optimization |
| `⚙️ Agent:root-cause-analyst` | Opus | Complex bug investigation |
| `⚙️ Agent:technical-writer` | Sonnet | Documentation |
| `⚙️ Agent:frontend-architect` | Sonnet | Frontend UI design |
| `⚙️ Agent:business-panel-experts` | Opus | Multi-expert business strategy |
| `⚙️ Agent:code-simplifier` | Sonnet | Code clarity, consistency |
| `⚙️ Agent:learning-guide` | Sonnet | Teaching, explanation |
| `⚙️ Agent:requirements-analyst` | Opus | Requirements discovery |
| `⚙️ Agent:socratic-mentor` | Sonnet | Educational guidance |
| `⚙️ Agent:devops-architect` | Opus | Infrastructure, deployment |

---

## 🔄 Delta-Update Procedure

The base matrix above covers the majority of routing needs. The delta procedure handles
any environment-specific or newly installed skills — custom skills, new installations, and environment-specific tools.

### At Startup (Initialization Mode)

1. **Load the base matrix** from this file (already in context when this reference is read)
2. **Scan for NEW skills** in the system context's available skills list:
   - Compare each available skill against the base matrix entries
   - Skills already in the base matrix → skip (no work needed)
   - Skills NOT in the base matrix → build a routing entry (see format above)
3. **Scan for custom agents** in:
   - `.claude/agents/` (project-level custom agents)
   - `~/.claude/agents/` (user-level custom agents)
   - Build routing entries for any discovered custom agents
4. **Merge**: base matrix + new skill entries + custom agent entries = full matrix
5. **Store** the full merged matrix in Serena memory as `skill_routing_matrix`

### On Subsequent Sessions (Continuation Mode)

1. Read `skill_routing_matrix` from Serena memory
2. Compare against the current session's available skills list
3. If new skills found → build entries for NEW skills only, merge, update Serena
4. If skills removed → prune stale entries, update Serena
5. If unchanged → use cached matrix (zero rebuild cost)

### If Serena Unavailable

- Use the base matrix from this file + the Agent Type table (always available)
- Build delta entries for unknown skills in real-time from system context descriptions
- No persistent caching — delta rebuild each session (still cheaper than full rebuild)

---

## Model Selection Heuristics

Apply these rules when assigning a model to a routing entry:

| Task Characteristic | Model | Rationale |
|---|---|---|
| Architectural decisions, system design | **Opus** | Requires deep reasoning about trade-offs |
| Complex debugging, root cause analysis | **Opus** | Needs hypothesis testing and broad context |
| Deep research, multi-source synthesis | **Opus** | Quality of reasoning matters more than speed |
| Multi-expert panels, spec review | **Opus** | Multiple perspectives need careful balancing |
| Security analysis, vulnerability assessment | **Opus** | Must not miss subtle issues |
| Standard implementation, feature building | **Sonnet** | Well-scoped tasks with clear requirements |
| Code review, quality checks | **Sonnet** | Pattern matching over deep reasoning |
| Testing, coverage analysis | **Sonnet** | Systematic but not architecturally complex |
| Documentation, explanation | **Sonnet** | Clear communication, less novel reasoning |
| Quick lookups, transcript fetching | **Haiku** | Speed matters, depth doesn't |

**Default**: Sonnet unless the task clearly matches an Opus or Haiku pattern.

---

## Composition Patterns

Common scenarios require multi-step workflows, not single skills. The SP fills in
concrete skills from the routing matrix at runtime.

### Standard Feature

```
Explore existing code   → understand what exists
Design the approach     → architecture decisions
Implement               → build it
Review                  → validate before commit
```

### Complex / Multi-Phase Feature

```
Research                → gather context and options
Plan                    → create structured plan with verification
Execute                 → implement with parallelization
Verify                  → UAT and quality check
```

### Large Architectural Change

```
Map codebase            → parallel analysis of current state
Design                  → spec the change
Expert review           → multi-expert validation of spec
Plan + Execute          → phased implementation
```

### Code Quality Pass

```
Analyze                 → identify issues
Improve                 → fix systematically
Test                    → verify nothing broke
```

### Bug Investigation

```
Debug                   → systematic, persistent state
```

---

## MCP & Plugin Routing

| When the task involves... | Instruct use of... | Instead of... |
|---|---|---|
| Navigate to a function, class, or symbol | `serena find_symbol` | Grep/Glob search |
| Understand a file's structure without reading all | `serena get_symbols_overview` | Reading the full file |
| Refactor with impact analysis | `serena find_referencing_symbols` first | Blind search-and-replace |
| Edit a function or method body | `serena replace_symbol_body` | File-based Edit tool |
| Search for patterns across the codebase | `serena search_for_pattern` | `grep` or Grep tool |
| Read or write cross-session memory | `serena read_memory` / `write_memory` | CLAUDE.md annotations |
| Look up library or framework documentation | `context7 resolve-library-id` + `query-docs` | Web search |
| API reference (React, Next.js, FastAPI, etc.) | `context7` | Hallucinating from training data |
| Browser automation or E2E testing | `playwright browser_*` tools | Unit tests alone |
| Visual UI validation (does it look right?) | `playwright browser_snapshot` / `take_screenshot` | — |

### Native-vs-MCP Decision Rule

```
Can a simple Glob or Grep answer it in one shot?  → use native
Is this about a named symbol in a code file?       → use Serena
Is this about documented library behaviour?        → use Context7
Does this require a browser or visual check?       → use Playwright
```

### Fallback Chains

| MCP | Primary Tool | Fallback |
|---|---|---|
| Serena | `find_symbol` | Grep + Glob for symbol search |
| Serena | `replace_symbol_body` | Edit tool for code changes |
| Serena | `read_memory` / `write_memory` | Auto-memory files |
| Context7 | `resolve-library-id` + `query-docs` | WebSearch + WebFetch |
| Playwright | `browser_navigate` + `browser_snapshot` | Manual testing instructions in prompt |

### Embedding MCP in Prompts

When crafting an implementation prompt, specify:
1. Which MCPs the session should use (by tool name, not category)
2. The specific tool calls most relevant
3. When to fall back to native tools if an MCP fails
4. Use conditional triggers: "IF looking up a named symbol → use Serena" (not "always use Serena")

---

## Invocation Convention

- `/skill-name` → invoke via **Skill tool** (slash commands)
- `⚙️ Agent:subagent-type` → invoke via **Agent tool** with `subagent_type` parameter
- The `feature-dev:code-explorer`, `feature-dev:code-architect`, and `feature-dev:code-reviewer`
  entries are **Agent subagent_types**, not slash commands — route accordingly
