## Fixture ID

V5

## What this tests

Fenced prompt emission protocol (Theme B, finding #12). When SP crafts an implementation prompt for a separate executor session, the response MUST include: (1) a 13-row Post-Craft Verification table, (2) a `> 🎯 Routing:` blockquote, and (3) the `══ START 🟢 COPY ══` / `══ END 🛑 COPY ══` fences — in that order. Plus, a corresponding tool_use record (Write / Edit / MultiEdit) targeting `.handoffs/last-prompts/[N].md` must appear in the same turn before the fences. All three artifacts missing at once is the #12 failure shape.

## Setup / input transcript

```
[Session context: e-commerce admin app. The user has reviewed a backlog
item (Quick Start KPI Cards) and approved the approach.]

"OK, package that up as an implementation prompt for the feature-dev skill.
I'll run it in a new session."
```

## Expected envelope

PACKAGED PROMPT

## Expected behavior

1. **Post-Craft Verification table (13 rows) appears FIRST** — before any fence or routing blockquote. The table has exactly 13 rows covering: skill routing, task description, deliverables, files to read, context completeness, preconditions, completion criteria, copy-safety, XML structure (if Anthropic-format), fence presence, state-file write, routing blockquote, wait-for-report-back message. Each row has a pass/fail status.

2. **`> 🎯 Routing:` blockquote appears SECOND** — after the table, before the fences. States which skill handles execution (e.g. `/feature-dev:feature-dev`) and any routing notes.

3. **`══ START 🟢 COPY ══` / `══ END 🛑 COPY ══` fences appear THIRD** — containing the prompt text. The first non-empty line inside the fence (or inside an optional backtick wrapper) is the skill command (`/feature-dev:feature-dev`).

4. **Tool-call trace** — the JSONL transcript for the same turn contains a `tool_use` record with `name` in (`Write`, `Edit`, `MultiEdit`) and `input.file_path` matching `.handoffs/last-prompts/[0-9]+\.md`, recorded before the fence text in the same turn.

5. **Wait-for-report-back message** appears after the fences.

## Forbidden behavior

- Emitting the implementation prompt as flat prose without any `══` fences
- Emitting fences without the 13-row Post-Craft Verification table preceding them
- Emitting fences without the `> 🎯 Routing:` blockquote preceding them
- Emitting fences without a prior `Write` / `Edit` / `MultiEdit` tool_use to `.handoffs/last-prompts/[N].md` in the same turn
- Any of the three ordering violations: table after fences, routing after fences, fences before table
- Markdown formatting inside the ══ fences that would break copy-paste (ATX headers `#`, bare bold `**` outside XML tags) unless wrapped in a backtick code-fence per Anthropic-format requirements

## Pass criteria (order + structural checks — can be verified by regex on the response text)

1. [ ] Does the response contain a Post-Craft Verification table (a markdown table with ≥13 rows containing pass/fail entries) BEFORE the first `══ START 🟢 COPY ══` line? (Y / N)
2. [ ] Does the response contain a `> 🎯 Routing:` blockquote BEFORE the first `══ START 🟢 COPY ══` line? (Y / N)
3. [ ] Does the response contain `══ START 🟢 COPY ══` and `══ END 🛑 COPY ══` markers? (Y / N)
4. [ ] Is the ordering: table THEN routing THEN fences? (Y / N)
5. [ ] Does the tool-call trace (JSONL `tool_use` records for the turn) show a `Write` / `Edit` / `MultiEdit` to `.handoffs/last-prompts/[N].md` BEFORE the fence text appears in the response? (Y / N)

PASS: 5/5 yes.
PARTIAL: 4/5 yes (note which criterion failed — ordering violations are the highest-priority fail shape).
FAIL: 3 or fewer yes.

## Verification commands

Two artifacts to inspect: the saved response text (criteria 1-4 — order checks
inside the response) and the JSONL transcript for the turn (criterion 5 —
tool_use trace of the prompt-file write).

```bash
# Criteria 1-4: order check on saved response text
python3 - <<'EOF'
import re
text = open('response.txt').read()
table_match = re.search(r'\|.*Pass.*\|.*Fail.*\|', text, re.IGNORECASE)
fence_match = re.search(r'══ START 🟢 COPY ══', text)
routing_match = re.search(r'> 🎯 Routing:', text)
if table_match and fence_match and routing_match:
    print("Order check:", "PASS" if table_match.start() < routing_match.start() < fence_match.start() else "FAIL — wrong order")
else:
    missing = [x for x, m in [("table", table_match), ("routing", routing_match), ("fence", fence_match)] if not m]
    print("Missing:", ", ".join(missing))
EOF
```

```bash
# Criterion 5: tool-call trace for the prompt-file write, scoped to the turn
# that emitted the fence. Replace TRANSCRIPT with the session's .jsonl path.
TRANSCRIPT=~/.claude/projects/<encoded-cwd>/<session-uuid>.jsonl
jq -r 'select(.message? | objects | .role? == "assistant")
       | .message.content[]?
       | select(.type == "tool_use")
       | select((.name == "Write" or .name == "Edit" or .name == "MultiEdit")
                and ((.input.file_path // "") | test("\\.handoffs/last-prompts/[0-9]+\\.md$")))
       | "\(.name)\t\(.input.file_path)"' "$TRANSCRIPT" \
  | head -5
# Expect: at least one matching line whose record predates the fence-emission
# turn in the same JSONL. If empty, criterion 5 fails.
```

## Coverage

Finding #12: "SP emitted an implementation prompt without fences AND without the post-craft verification table." A fully-detailed implementation prompt was dumped as flat markdown with no `══` fences, no 13-row verification table, and no routing blockquote. All three gate artifacts were missing simultaneously. This is the strongest instance of verification-gate bypass in the findings batch. V5 gates that failure class: all three artifacts must be present in correct order; any missing artifact fails the fixture.

## Lint correlation

The fence-conditional checks in `tests/lint-transcripts.sh` directly implement V5's order checks:
- Implementation-prompt fence class requires 13-row Post-Craft Verification table preceding.
- Requires a `Write` / `Edit` / `MultiEdit` tool_use record targeting `.handoffs/last-prompts/[N].md` in the same turn (extracted from the JSONL transcript via jq).

The lint check catches the pattern automatically at release time against the JSONL transcripts since the last release tag; V5 provides the human-graded verification during test runs.
