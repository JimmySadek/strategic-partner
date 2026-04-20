/[skill-name]

Read and execute the implementation prompt below.

---

## [Name]

[1-2 sentence description of what this implements and why]

<context>
  Read first (in order):
  1. path/to/file — [what to look for]
  2. path/to/file — [what to look for]

  Project conventions:
  1. [relevant CLAUDE.md rules]
  2. [relevant Serena memory gotchas]
</context>

<!-- Default blocks: universal patterns for any Claude 4.x executor. -->
<!-- Additional optional blocks (subagent_usage, use_parallel_tool_calls, conservative_actions, scope_explicit, context_awareness) can be added based on task shape. See prompt-crafting-guide.md "Reusable Prompt Blocks" section. -->
<investigate_before_answering>
Never speculate about code you have not opened. If the user references a specific file, you MUST read the file before answering. Make sure to investigate and read relevant files BEFORE answering questions about the codebase. Never make any claims about code before investigating unless you are certain of the correct answer — give grounded and hallucination-free answers.
</investigate_before_answering>

<avoid_over_engineering>
Only make changes that are directly requested or clearly necessary. Keep solutions simple and focused:

- Scope: Don't add features, refactor code, or make "improvements" beyond what was asked. A bug fix doesn't need surrounding code cleanup. A simple feature doesn't need extra configurability.
- Documentation: Don't add docstrings, comments, or type annotations to code you didn't change. Only add comments where the logic isn't self-evident.
- Defensive coding: Don't add error handling, fallbacks, or validation for scenarios that can't happen. Trust internal code and framework guarantees. Only validate at system boundaries (user input, external APIs).
- Abstractions: Don't create helpers, utilities, or abstractions for one-time operations. Don't design for hypothetical future requirements. The right amount of complexity is the minimum needed for the current task.
</avoid_over_engineering>

<instructions>
  [Clear, direct task description]

  Deliverables:
  1. [Specific file + what changes]
  2. [...]

  Constraints:
  1. [Project-specific rules]
  2. [Patterns to follow]
</instructions>

<!-- Include <not-in-scope> for multi-file changes. Optional for single-file fixes.
     Name specific adjacent temptations the executor will face — not vague platitudes
     like "keep changes minimal." The goal is to prevent scope creep at execution time. -->
<not-in-scope>
  Do NOT:
  1. [Specific adjacent change the executor will be tempted to make]
  2. [Another specific exclusion — name the file, module, or pattern to leave alone]
  3. [...]
</not-in-scope>

<!-- Include <orchestration> ONLY when (a) subtasks are clearly independent with
     no shared state, (b) user explicitly requested multi-agent decomposition,
     or (c) latency-hiding is the primary goal. Skip otherwise — Opus 4.7 plans
     parallelism well by default. -->
<orchestration>
  Phase 1 (parallel):
    Agent A (Sonnet 4.6): [task + expected output]
    Agent B (Sonnet 4.6): [task + expected output]
  Phase 2 (sequential):
    Agent C (Opus 4.7): [synthesis task]
</orchestration>

<verification>
  1. [ ] [Specific check — what to verify]
  2. [ ] Run: [test command]
  3. [ ] Verify: [expected outcome]
</verification>

<!-- Include <rollback> when the change could regress existing behavior -->
<rollback>
  If this change causes regressions:
  - Revert: git revert [this commit's hash]
  - [Additional cleanup: migration rollback, config restore, etc.]
</rollback>

Expected commit: "[type]([scope]): [description]"
