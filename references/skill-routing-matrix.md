# Skill Routing Matrix — Dynamic Routing Rules

Reference file for the strategic-partner advisor. Defines task categories, dynamic
discovery protocol, and routing rules. Agent D builds the actual matrix at runtime
from each user's installed skills and agents.

```
Task Categories (static) + Discovered Skills (dynamic) → Routing Matrix → Store in Serena → Delta on Continuation
```

---

## Matrix Format Specification

Each entry in the routing matrix follows this schema:

| Field | Description | Example |
|---|---|---|
| Task | Natural-language description of what the user wants | "Implement a focused feature" |
| Primary Skill | Exact invocation (slash command or Agent type) | `[resolved at runtime]` or `Agent:code-explorer` |
| Model | Recommended model for the task | Opus, Sonnet, or Haiku |
| When to Use Instead | Alternative skill for edge cases | "Agent:Plan for lighter scope" |

---

## Task Category Taxonomy

These categories define WHAT kinds of tasks exist. Agent D maps discovered skills
into these categories at runtime using keyword matching and skill descriptions.

### 1. Implementation

**Description:** Building new features, making code changes, executing from specs.
**Keywords:** build, implement, create, add, feature, develop, code, write, make
**Built-in Agents:** `Agent:general-purpose`, `Agent:Plan`
**Model Heuristic:** Sonnet (Opus if design-heavy or full-stack)

### 2. Debugging & Investigation

**Description:** Finding and fixing bugs, root cause analysis, performance issues.
**Keywords:** debug, fix, bug, broken, error, investigate, crash, failing, slow, diagnose
**Built-in Agents:** `Agent:root-cause-analyst`, `Agent:performance-engineer`
**Model Heuristic:** Opus (deep reasoning needed for root cause)

### 3. Code Quality & Review

**Description:** Code review, refactoring, cleanup, security audits, style enforcement.
**Keywords:** review, refactor, clean, simplify, audit, lint, quality, improve, dead code
**Built-in Agents:** `Agent:refactoring-expert`, `Agent:security-engineer`, `Agent:code-simplifier`
**Model Heuristic:** Sonnet (Opus for security audits)

### 4. Architecture & Design

**Description:** System design, API design, component architecture, infrastructure planning.
**Keywords:** architect, design, structure, plan, scale, API, schema, infrastructure, devops
**Built-in Agents:** `Agent:backend-architect`, `Agent:system-architect`, `Agent:frontend-architect`, `Agent:devops-architect`
**Model Heuristic:** Opus (architectural decisions need deep reasoning)

### 5. Research & Exploration

**Description:** Codebase exploration, deep research, requirements discovery, planning.
**Keywords:** explore, research, understand, discover, analyze, investigate, plan, requirements
**Built-in Agents:** `Agent:Explore`, `Agent:Plan`, `Agent:deep-research-agent`, `Agent:requirements-analyst`
**Model Heuristic:** Sonnet for exploration, Opus for deep research

### 6. Documentation & Teaching

**Description:** Writing docs, explaining code, educational guidance, knowledge transfer.
**Keywords:** document, explain, teach, guide, readme, changelog, comment, describe
**Built-in Agents:** `Agent:technical-writer`, `Agent:learning-guide`, `Agent:socratic-mentor`
**Model Heuristic:** Sonnet

### 7. Testing & Quality Engineering

**Description:** Test writing, test strategy, coverage analysis, edge case detection.
**Keywords:** test, coverage, spec, assert, edge case, regression, integration, e2e, QA
**Built-in Agents:** `Agent:quality-engineer`
**Model Heuristic:** Sonnet

### 8. UI & Frontend

**Description:** Building UI components, frontend architecture, styling, accessibility.
**Keywords:** UI, frontend, component, CSS, Tailwind, React, page, layout, responsive, design system
**Built-in Agents:** `Agent:frontend-architect`
**Model Heuristic:** Sonnet

### 9. Workflow & Process

**Description:** Git operations, CI/CD, deployment, scheduling, project lifecycle management.
**Keywords:** git, deploy, CI, pipeline, ship, merge, PR, release, schedule, workflow
**Built-in Agents:** `Agent:devops-architect`
**Model Heuristic:** Sonnet

### 10. Configuration & Meta

**Description:** Tool configuration, skill management, environment setup, settings.
**Keywords:** configure, setup, settings, install, hook, keybinding, sync, skill, plugin
**Built-in Agents:** `Agent:general-purpose`
**Model Heuristic:** Sonnet (Haiku for trivial lookups)

---

## Dynamic Discovery Protocol

Agent D builds the routing matrix at runtime. The system-reminder message is the
**authoritative source** for each user's installed skills — it lists every available
skill with its description.

### Initialization (Fresh Session)

```
Step 1: Read skill inventory from system-reminder
  ├─ Extract each skill name and its one-line description
  ├─ Count total available skills
  └─ Note any skill families (shared prefix, e.g., "gsd:*", "sc:*")

Step 2: Read custom agent definitions
  ├─ Scan .claude/agents/ (project-level)
  │   ├─ Success → count agents, read descriptions from frontmatter
  │   └─ Failure → record error: "project_level_scan_failed"
  ├─ Scan ~/.claude/agents/ (user-level)
  │   ├─ Success → count agents, read descriptions from frontmatter
  │   └─ Failure → record error: "user_level_scan_failed"
  └─ Note: Agent definition files enhance built-in subagent_types with
     skills, effort, tools, etc. — Claude Code picks them up automatically

Step 3: Read MCP server inventory from system-reminder
  ├─ Identify active servers (Serena, Context7, Playwright, etc.)
  └─ Count available MCP tools

Step 4: Map skills to task categories
  ├─ For each discovered skill:
  │   ├─ Read its description from system-reminder
  │   ├─ Match keywords against the Task Category Taxonomy above
  │   ├─ Assign a model heuristic using the Model Selection rules below
  │   └─ Build a routing entry (Task, Primary Skill, Model, When to Use Instead)
  ├─ For each custom agent:
  │   ├─ Read its description from frontmatter
  │   ├─ Match to task category
  │   └─ Build routing entry
  └─ Merge with built-in Agent types (always available)

Step 5: Store the complete matrix in Serena as `skill_routing_matrix`
```

### Continuation (Returning Session)

```
Step 1: Read cached matrix from Serena (`skill_routing_matrix`)

Step 2: Compare against current system context
  ├─ Skills in cache but NOT in system-reminder → mark as removed
  ├─ Skills in system-reminder but NOT in cache → mark as new
  └─ Skills in both → keep existing entry

Step 3: If changes detected
  ├─ Build entries for new skills
  ├─ Remove stale entries
  └─ Update Serena with revised matrix

Step 4: If no changes → use cached matrix (zero rebuild cost)
```

### Fallback Chain

When things fail, degrade gracefully:

```
┌─────────────────────────────────────────────────────────────────┐
│  Fallback Chain                                                  │
│                                                                  │
│  1. Full discovery succeeds                                      │
│     └─ routing_status: "built"                                   │
│        Complete matrix stored in Serena                          │
│                                                                  │
│  2. Partial failure (e.g., agent scan fails, skills readable)    │
│     └─ routing_status: "built" (with errors noted)               │
│        Use what succeeded + note gaps                            │
│                                                                  │
│  3. Full discovery fails, Serena cache exists                    │
│     └─ routing_status: "cached"                                  │
│        Read skill_routing_matrix from Serena                     │
│                                                                  │
│  4. No Serena cache, system context available                    │
│     └─ routing_status: "fallback"                                │
│        Match system-reminder skills to task categories           │
│        + built-in Agent types (always available)                 │
│                                                                  │
│  5. Absolute minimum (no system context, no cache)               │
│     └─ Built-in Agent types only (see table below)               │
└─────────────────────────────────────────────────────────────────┘
```

---

## Agent Type Routing (Always Available)

These are built-in Agent subtypes — available in every environment regardless of
installed skills. Claude Code defines these internally; agent definition files in
`~/.claude/agents/` or `.claude/agents/` can enhance them with skills, effort,
tools, etc., but the base types always exist.

| Agent Type | Model | Use For |
|---|---|---|
| `Agent:Explore` | Sonnet | Quick codebase exploration, file discovery |
| `Agent:Plan` | Sonnet | Implementation planning |
| `Agent:general-purpose` | Sonnet | Multi-step research, code search |
| `Agent:deep-research-agent` | Opus | Comprehensive research with multiple sources |
| `Agent:feature-dev:code-explorer` | Sonnet | Deep feature analysis, execution path tracing |
| `Agent:feature-dev:code-architect` | Opus | Feature architecture design |
| `Agent:feature-dev:code-reviewer` | Sonnet | Code review with confidence filtering |
| `Agent:quality-engineer` | Sonnet | Testing strategy, edge case detection |
| `Agent:security-engineer` | Opus | Security audit, vulnerability analysis |
| `Agent:backend-architect` | Opus | Backend system design |
| `Agent:system-architect` | Opus | Scalable system architecture |
| `Agent:python-expert` | Sonnet | Python implementation |
| `Agent:refactoring-expert` | Sonnet | Code cleanup, technical debt |
| `Agent:performance-engineer` | Sonnet | Performance optimization |
| `Agent:root-cause-analyst` | Opus | Complex bug investigation |
| `Agent:technical-writer` | Sonnet | Documentation |
| `Agent:frontend-architect` | Sonnet | Frontend UI design |
| `Agent:business-panel-experts` | Opus | Multi-expert business strategy |
| `Agent:code-simplifier` | Sonnet | Code clarity, consistency |
| `Agent:learning-guide` | Sonnet | Teaching, explanation |
| `Agent:requirements-analyst` | Opus | Requirements discovery |
| `Agent:socratic-mentor` | Sonnet | Educational guidance |
| `Agent:devops-architect` | Opus | Infrastructure, deployment |

**Note**: These are always available regardless of whether definition files exist.
Agent definition files in `~/.claude/agents/` enhance them with skills, effort, tools,
etc. — Claude Code picks up definition files automatically when `subagent_type` matches.

**Mode selection**: See `orchestration-playbook.md` § Agent Permission Modes for the
mode decision tree. Background agents require `mode: "auto"`.

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
| Quick lookups, transcript fetching | **Haiku 4.5** | Speed matters, depth doesn't |

**Default**: Sonnet unless the task clearly matches an Opus or Haiku pattern.

### Model IDs

When crafting prompts or routing to specific models, use these exact IDs:

| Model | ID | Use For |
|---|---|---|
| Opus 4.7 | `claude-opus-4-7` | Architecture, system design, debugging, deep research, security, multi-expert |
| Sonnet 4.6 | `claude-sonnet-4-6` | Implementation, review, testing, documentation, code quality (default) |
| Haiku 4.5 | `claude-haiku-4-5-20251001` | Quick lookups, transcript fetching, low-depth narrow tasks |

---

## Composition Patterns

Common scenarios require multi-step workflows, not single skills. The SP fills in
concrete skills from the routing matrix at runtime.

### Standard Feature

```
Explore existing code   -> understand what exists
Design the approach     -> architecture decisions
Implement               -> build it
Review                  -> validate before commit
```

### Complex / Multi-Phase Feature

```
Research                -> gather context and options
Plan                    -> create structured plan with verification
Execute                 -> implement with parallelization
Verify                  -> UAT and quality check
```

### Large Architectural Change

```
Map codebase            -> parallel analysis of current state
Design                  -> spec the change
Expert review           -> multi-expert validation of spec
Plan + Execute          -> phased implementation
```

### Code Quality Pass

```
Analyze                 -> identify issues
Improve                 -> fix systematically
Test                    -> verify nothing broke
```

### Bug Investigation

```
Debug                   -> systematic, persistent state
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
| Visual UI validation (does it look right?) | `playwright browser_snapshot` / `take_screenshot` | --- |

### Native-vs-MCP Decision Rule

```
Can a simple Glob or Grep answer it in one shot?  -> use native
Is this about a named symbol in a code file?       -> use Serena
Is this about documented library behaviour?        -> use Context7
Does this require a browser or visual check?       -> use Playwright
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
4. Use conditional triggers: "IF looking up a named symbol -> use Serena" (not "always use Serena")

---

## Invocation Convention

- `/skill-name` -> invoke via **Skill tool** (slash commands)
- `Agent:subagent-type` -> invoke via **Agent tool** with `subagent_type` parameter
- The `feature-dev:code-explorer`, `feature-dev:code-architect`, and `feature-dev:code-reviewer`
  entries are **Agent subagent_types**, not slash commands -- route accordingly
