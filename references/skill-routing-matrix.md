# Skill Routing Matrix — Template & Procedure

Reference file for the strategic-partner advisor. Defines the format, auto-generation
procedure, and universal routing rules for skill selection.

The routing matrix is **built at runtime** from the system context's available skills,
not shipped as a static table. This file provides the template and procedure.

---

## Matrix Format Specification

Each entry in the routing matrix follows this schema:

| Field | Description | Example |
|---|---|---|
| Task | Natural-language description of what the user wants | "Implement a focused feature" |
| Primary Skill | Exact invocation (slash command or Agent type) | `/feature-dev:feature-dev` or `Agent:code-explorer` |
| Model | Recommended model for the task | Opus, Sonnet, or Haiku |
| When to Use Instead | Alternative skill for edge cases | "/sc:implement for simpler scope" |

**Example entries** (illustrative — concrete entries are generated at runtime):

```
| Explore existing code before building | Agent:feature-dev:code-explorer | Sonnet | Quick Grep/Glob for single-file lookups |
| Architect a new feature               | Agent:feature-dev:code-architect | Opus  | /sc:design for API-level specs |
| Implement a focused feature           | /feature-dev:feature-dev         | Sonnet | /sc:implement for simpler scope |
| Debug a complex bug                   | /gsd:debug                       | Opus  | — |
| Review PR or changeset                | /code-review:code-review         | Sonnet | — |
```

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

## Auto-Generation Procedure

### At Startup (Initialization Mode)

1. Read the system context's available skills list (provided automatically in the
   session's system prompt)
2. For each skill, create a routing entry:
   - **Task**: derive from the skill's description and trigger phrases
   - **Primary Skill**: the exact invocation command
   - **Model**: apply model selection heuristics (see below)
   - **When to Use Instead**: identify overlapping skills and note when each is preferred
3. Merge with the always-available Agent Type table above
4. Store the complete matrix in Serena memory as `skill_routing_matrix`

### On Subsequent Sessions (Continuation Mode)

1. Read `skill_routing_matrix` from Serena memory
2. Compare against the current session's available skills list
3. If new skills found or skills removed → rebuild and update Serena memory
4. If unchanged → use cached matrix

### If Serena Unavailable

- Use the Agent Type table above (always available) as the base
- Match tasks to skills in real-time from the system context's skill descriptions
- No persistent caching — rebuild each session

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
