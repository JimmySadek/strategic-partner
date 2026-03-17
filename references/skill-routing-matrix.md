# Skill Routing Matrix — Base Matrix & Delta Procedure

Reference file for the strategic-partner advisor. Ships a curated base matrix of
common skills and agent types, with a delta-update procedure for discovering new
or custom skills at runtime.

```
Load Base Matrix → Scan for NEW Skills → Build Delta Entries → Merge → Store in Serena → Diff on Continuation
```

---

## Matrix Format Specification

Each entry in the routing matrix follows this schema:

| Field | Description | Example |
|---|---|---|
| Task | Natural-language description of what the user wants | "Implement a focused feature" |
| Primary Skill | Exact invocation (slash command or Agent type) | `/feature-dev:feature-dev` or `Agent:code-explorer` |
| Model | Recommended model for the task | Opus, Sonnet, or Haiku |
| When to Use Instead | Alternative skill for edge cases | "/sc:implement for simpler scope" |

---

## 📦 Curated Base Matrix

These are the ~30 most common skills and agent types pre-mapped. Load this table
at startup instead of building from scratch — reduces cognitive cost by **~80%**.

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
| Debug a complex bug | `/gsd:debug` | Opus | Agent:root-cause-analyst for deep investigation |
| Root cause analysis | Agent:root-cause-analyst | Opus | `/gsd:debug` for simpler bugs |
| Performance investigation | Agent:performance-engineer | Sonnet | `/gsd:debug` if perf issue is a bug |

### ✅ Code Quality & Review

| Task | Primary Skill | Model | When to Use Instead |
|---|---|---|---|
| Review PR or changeset | `/code-review:code-review` | Sonnet | Agent:feature-dev:code-reviewer for deeper review |
| Code cleanup and simplification | `/code-simplifier:code-simplifier` | Sonnet | Agent:refactoring-expert for larger refactors |
| Large-scale refactoring | Agent:refactoring-expert | Sonnet | `/code-simplifier` for single-file cleanup |
| Security audit | Agent:security-engineer | Opus | `/code-review` if just checking for obvious issues |

### 🏗️ Architecture & Design

| Task | Primary Skill | Model | When to Use Instead |
|---|---|---|---|
| Design a new feature's architecture | Agent:feature-dev:code-architect | Opus | `/sc:design` for API-level specs |
| Backend system design | Agent:backend-architect | Opus | Agent:system-architect for distributed systems |
| Scalable system architecture | Agent:system-architect | Opus | Agent:backend-architect for single-service scope |
| Frontend/UI architecture | Agent:frontend-architect | Sonnet | `/frontend-design` for component-level work |
| DevOps and infrastructure design | Agent:devops-architect | Opus | — |

### 🔍 Research & Exploration

| Task | Primary Skill | Model | When to Use Instead |
|---|---|---|---|
| Explore existing code before building | Agent:Explore | Sonnet | Quick Grep/Glob for single-file lookups |
| Deep feature analysis, execution tracing | Agent:feature-dev:code-explorer | Sonnet | Agent:Explore for broad discovery |
| Deep research with multiple sources | Agent:deep-research-agent | Opus | Agent:Explore for codebase-only research |
| Requirements discovery | Agent:requirements-analyst | Opus | Brainstorming mode for less formal discovery |
| Implementation planning | Agent:Plan | Sonnet | Agent:feature-dev:code-architect for design-heavy planning |

### 📝 Documentation & Teaching

| Task | Primary Skill | Model | When to Use Instead |
|---|---|---|---|
| Technical documentation | Agent:technical-writer | Sonnet | Direct writing for simple docs |
| Explain code or concepts | Agent:learning-guide | Sonnet | Agent:socratic-mentor for guided learning |
| Educational guidance (Socratic) | Agent:socratic-mentor | Sonnet | Agent:learning-guide for direct explanation |

### 🧪 Testing & Quality Engineering

| Task | Primary Skill | Model | When to Use Instead |
|---|---|---|---|
| Testing strategy, edge case detection | Agent:quality-engineer | Sonnet | `/gsd:test` for straightforward test writing |
| Write tests for existing code | `/gsd:test` | Sonnet | Agent:quality-engineer for strategy-level work |

### 🎯 Multi-Expert & Strategic

| Task | Primary Skill | Model | When to Use Instead |
|---|---|---|---|
| Multi-expert business strategy | Agent:business-panel-experts | Opus | Single-domain agent for focused questions |
| Spec review from multiple perspectives | `/spec-review` (if available) | Opus | Agent:business-panel-experts as fallback |
| UI component creation | `/frontend-design` (if available) | Sonnet | Agent:frontend-architect for architecture-level |

---

## Agent Type Routing (Always Available)

These are built-in Agent subtypes — available in every environment regardless of
installed skills. Always include these in the routing matrix.

| Agent Type | Model | Use For |
|---|---|---|
| Explore | Sonnet | Quick codebase exploration, file discovery |
| Plan | Sonnet | Implementation planning |
| general-purpose | Sonnet | Multi-step research, code search |
| deep-research-agent | Opus | Comprehensive research with multiple sources |
| feature-dev:code-explorer | Sonnet | Deep feature analysis, execution path tracing |
| feature-dev:code-architect | Opus | Feature architecture design |
| feature-dev:code-reviewer | Sonnet | Code review with confidence filtering |
| quality-engineer | Sonnet | Testing strategy, edge case detection |
| security-engineer | Opus | Security audit, vulnerability analysis |
| backend-architect | Opus | Backend system design |
| system-architect | Opus | Scalable system architecture |
| python-expert | Sonnet | Python implementation |
| refactoring-expert | Sonnet | Code cleanup, technical debt |
| performance-engineer | Sonnet | Performance optimization |
| root-cause-analyst | Opus | Complex bug investigation |
| technical-writer | Sonnet | Documentation |
| frontend-architect | Sonnet | Frontend UI design |
| business-panel-experts | Opus | Multi-expert business strategy |
| code-simplifier | Sonnet | Code clarity, consistency |
| learning-guide | Sonnet | Teaching, explanation |
| requirements-analyst | Opus | Requirements discovery |
| socratic-mentor | Sonnet | Educational guidance |
| devops-architect | Opus | Infrastructure, deployment |

---

## 🔄 Delta-Update Procedure

The base matrix above covers ~80% of routing needs. The delta procedure handles
the remaining ~20% — custom skills, new installations, and environment-specific tools.

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
- `Agent:subagent-type` → invoke via **Agent tool** with `subagent_type` parameter
- The `feature-dev:code-explorer`, `feature-dev:code-architect`, and `feature-dev:code-reviewer`
  entries are **Agent subagent_types**, not slash commands — route accordingly
