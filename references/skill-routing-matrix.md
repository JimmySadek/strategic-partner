# Skill Routing Matrix

Reference file for the strategic-partner advisor. Consult when routing work to implementation sessions.

---

## Task → Skill Mapping

| Task | Primary Skill | Model | When to Use Instead |
|---|---|---|---|
| Explore existing code before building | `Agent:feature-dev:code-explorer` | Sonnet | `/sc:explain` for quick explanation |
| Architect a new feature | `Agent:feature-dev:code-architect` | Opus | `/sc:design` for API/system-level design |
| Implement a focused feature | `/feature-dev:feature-dev` | Sonnet | `/sc:implement` for simpler scope |
| Complex multi-agent task (>3 parallel tracks) | `/sc:spawn` | Opus | `/gsd:execute-phase` for phased delivery |
| Structured phase delivery (PLAN.md → execute) | `/gsd:plan-phase` + `/gsd:execute-phase` | Sonnet | `/gsd:quick` for lightweight tasks |
| Quick task with quality guarantees | `/gsd:quick` | Sonnet | — |
| Deep code audit (quality/security/architecture) | `/sc:analyze` | Sonnet | `Agent:feature-dev:code-reviewer` for PR review |
| Review PR or changeset | `/code-review:code-review` | Sonnet | — |
| Validate built feature (UAT) | `/gsd:verify-work` | Sonnet | `/sc:reflect` for lighter validation |
| Debug a complex bug | `/gsd:debug` | Opus | `/jimmy:systematic-debugging` for autonomous multi-lens |
| Design new system/API spec | `/sc:design` | Opus | — |
| Multi-expert spec review before building | `/sc:spec-panel` | Opus | — |
| Research technical approach (web) | `/sc:research` | Sonnet | `/gsd:research-phase` before planning |
| Systematic code improvements | `/sc:improve` | Sonnet | `/sc:cleanup` for dead code specifically |
| Run tests + coverage report | `/sc:test` | Sonnet | — |
| Fix build or deployment issues | `/sc:troubleshoot` | Sonnet | — |
| Generate workflow from PRD | `/sc:workflow` | Sonnet | — |
| Document a component or API | `/sc:document` | Sonnet | `/sc:index` for full project docs |
| Build UI components, pages, layouts | `/frontend-design:frontend-design` | Sonnet | — |
| Design system decisions, UX review, palette/style | `/ui-ux-pro-max` | Sonnet | — |
| Complex UI (design + build in one pass) | `/ui-ux-pro-max` then `/frontend-design` | Sonnet | — |
| Explore codebase architecture | `/gsd:map-codebase` | Sonnet | `/sc:analyze --scope project` |
| Update CLAUDE.md with session learnings | `/claude-md-management:revise-claude-md` | Sonnet | — |
| Audit and improve CLAUDE.md files | `/claude-md-management:claude-md-improver` | Sonnet | — |
| Estimate effort | `/sc:estimate` | Sonnet | — |
| Preserve session context | (handled internally by advisor) | — | — |
| GitHub PR/issue/workflow operations | `/github-ops` | Sonnet | — |
| React composition, compound components | `/composition-patterns` | Sonnet | — |
| React/Next.js performance optimization | `/react-best-practices` | Sonnet | — |
| Business strategy analysis (multi-expert) | `/sc:business-panel` | Opus | — |
| Requirements discovery (Socratic) | `/sc:brainstorm` | Sonnet | `/strategic-partner` for advisory mode |
| Simplify and refine recently changed code | `/simplify` | Sonnet | `/sc:improve` for broader scope |
| Review UI against Web Interface Guidelines | `/web-design-guidelines` | Sonnet | `/ui-ux-pro-max` for full design audit |
| PDF extraction, creation, merging, forms | `/pdf` | Sonnet | — |
| Task queue — add or process pending work | `/do-work` | Sonnet | — |
| Build with Claude API / Anthropic SDK | `/claude-developer-platform` | Sonnet | — |
| Sync skills across AI tools | `/skillshare` | Sonnet | — |
| Find or discover installable skills | `/find-skills` | Sonnet | — |
| Customize keyboard shortcuts / keybindings | `/keybindings-help` | Sonnet | — |
| Select optimal MCP tool for a task | `/sc:select-tool` | Sonnet | — |
| Build, compile, or package a project | `/sc:build` | Sonnet | `/sc:troubleshoot` for build failures |
| Git commit, branch, or workflow operations | `/sc:git` | Sonnet | — |
| Execute complex multi-step task with workflow | `/sc:task` | Sonnet | `/sc:spawn` for parallel tracks |

---

## Agent Type Routing

When spawning agents via the Agent tool, select the right subagent_type and model:

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

## Project-Local Skills

These skills are specific to projects and may not be available in all contexts:

### Alfred Distribution
- `jimmy:systematic-debugging` — Autonomous debugging with multi-lens analysis
- `jimmy:alfred-buildx` — Build and distribute Alfred Docker images
- `jimmy:sync-api-spec` — Synchronize API spec corrections across OpenAPI specs, Neo4j, Aura
- `jimmy:manage-protected-repos` — Manage protected repository list across 3 protection layers

---

## Power Combinations (Skill Chains)

Common scenarios require skill chains, not single skills. Recommend the full chain:

### New Feature (Standard)
```
/feature-dev:code-explorer   → understand what exists
/feature-dev:code-architect  → design the approach
/feature-dev:feature-dev     → implement
/code-review:code-review     → validate before commit
```

### New Feature (Complex / Multi-Phase)
```
/gsd:research-phase          → research first
/gsd:plan-phase              → create PLAN.md with verification loop
/gsd:execute-phase           → execute with wave parallelization
/gsd:verify-work             → UAT
```

### Large Architectural Change
```
/gsd:map-codebase            → parallel codebase analysis
/sc:design                   → spec the change
/sc:spec-panel               → multi-expert review of spec
/gsd:plan-phase → /gsd:execute-phase
```

### Code Quality Pass
```
/sc:analyze                  → identify issues
/sc:improve                  → fix systematically
/sc:test                     → verify nothing broke
```

### Bug Investigation
```
/gsd:debug                   → systematic, persistent state
```

---

## Routing Principles

1. **Embed routing in every prompt** — specify the exact skill command, not the category
2. **Specify the model** — Opus or Sonnet, based on task complexity
3. **Explain why** that skill and not an alternative
4. **Specify pre-reading** — "read X file first, then run `/feature-dev:code-explorer`"
5. **List the full chain** when a multi-step workflow applies
6. **Proactively recommend** — don't wait for the user to ask which skill to use
7. **Flag cost mismatches** — warn when a task looks simple but needs a heavier skill

---

## Invocation Convention

- `/skill-name` → invoke via **Skill tool** (slash commands)
- `Agent:subagent-type` → invoke via **Agent tool** with `subagent_type` parameter
- The `feature-dev:code-explorer`, `feature-dev:code-architect`, and `feature-dev:code-reviewer` entries are **Agent subagent_types**, not slash commands — route accordingly

## Catalog Freshness

This matrix is a curated reference. At session start, the advisor compares this against
the live skill inventory (from system context) and flags:
- **Uncatalogued**: skills in environment not in this matrix
- **Unavailable**: skills in this matrix not in environment

Last synced: 2026-03-03 (rev 2)
