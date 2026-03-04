# MCP & Plugin Routing Matrix

Reference file for the strategic-partner advisor. Consult when specifying MCP tool usage
in implementation prompts.

---

## MCP Tool Routing

| When the task involves… | Instruct use of… | Instead of… |
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
| TypeScript / Python type errors from IDE | `ide getDiagnostics` | Running type checker manually |
| Execute code snippets via IDE | `ide executeCode` | Bash for simple cases |

---

## Native-vs-MCP Decision Rule

```
Can a simple Glob or Grep answer it in one shot?  → use native
Is this about a named symbol in a code file?       → use Serena
Is this about documented library behaviour?        → use Context7
Does this require a browser or visual check?       → use Playwright
Does this need IDE diagnostics (type errors)?      → use IDE
```

---

## Fallback Chains

When an MCP is unavailable, fall back to native tools:

| MCP | Primary Tool | Fallback |
|---|---|---|
| Serena | `find_symbol` | Grep + Glob for symbol search |
| Serena | `get_symbols_overview` | Read tool for file structure |
| Serena | `replace_symbol_body` | Edit tool for code changes |
| Serena | `find_referencing_symbols` | Grep for call site search |
| Serena | `read_memory` / `write_memory` | Auto-memory files in `~/.claude/projects/` |
| Context7 | `resolve-library-id` + `query-docs` | WebSearch + WebFetch for docs |
| Playwright | `browser_navigate` + `browser_snapshot` | Manual testing instructions in prompt |
| IDE | `getDiagnostics` | Bash: run linter/type-checker manually |
| IDE | `executeCode` | Bash: run code directly |

---

## Domain-Specific MCPs

Available but not used in general development. Loaded on-demand via ToolSearch:

| MCP | Domain | Key Tools |
|---|---|---|
| Clinical Trials | Healthcare/pharma | `search_trials`, `get_trial_details`, `analyze_endpoints`, `search_investigators` |
| HubSpot | CRM/Sales | `search_crm_objects`, `get_properties`, `get_user_details`, `search_owners` |

Only reference in prompts when the task is domain-specific.

---

## Embedding MCP in Prompts

When crafting an implementation prompt, specify:
1. Which MCPs the session should use (by tool name, not just category)
2. The specific tool calls most relevant (e.g., "use `serena find_symbol` with `depth=1`")
3. When to fall back to native tools if an MCP fails
4. Use conditional triggers: "IF looking up a named symbol → use Serena" (not "always use Serena")

---

## Proactive MCP Recommendations

During conversation, flag opportunities where MCP outperforms native:
- "Use `serena find_referencing_symbols` before refactoring — it shows every call site"
- "Context7 has the FastAPI docs — use it instead of training data for response model patterns"
- "This visual check needs `playwright browser_snapshot` — unit tests won't catch layout issues"

---

## Plugin Discovery

The system context lists available MCP servers. Read and internalize at session start —
it varies by machine and configuration. Never assume a plugin is available without checking.
Use ToolSearch to discover deferred tools before invoking them.
