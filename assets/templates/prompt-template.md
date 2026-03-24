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
  - [relevant CLAUDE.md rules]
  - [relevant Serena memory gotchas]
</context>

<instructions>
  [Clear, direct task description]

  Deliverables:
  1. [Specific file + what changes]
  2. [...]

  Constraints:
  - [Project-specific rules]
  - [Patterns to follow]
</instructions>

<!-- Include <orchestration> only for multi-agent tasks -->
<orchestration>
  Phase 1 (parallel):
    Agent A (Sonnet 4.6): [task + expected output]
    Agent B (Sonnet 4.6): [task + expected output]
  Phase 2 (sequential):
    Agent C (Opus 4.6): [synthesis task]
</orchestration>

<verification>
  - [ ] [Specific check — what to verify]
  - [ ] Run: [test command]
  - [ ] Verify: [expected outcome]
</verification>

<!-- Include <rollback> when the change could regress existing behavior -->
<rollback>
  If this change causes regressions:
  - Revert: git revert [this commit's hash]
  - [Additional cleanup: migration rollback, config restore, etc.]
</rollback>

Expected commit: "[type]([scope]): [description]"
