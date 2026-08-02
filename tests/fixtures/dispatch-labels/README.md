# Dispatch-label carve-out fixtures

Self-test material for `tests/lint-dispatch-labels.sh`. These files are excluded
from the lint's default repo scan, because half of them exist to be rejected.

Before this fixture set, the lint excused two label shapes on **spelling alone** —
the bare `[Dispatch now]` and the elided `[Dispatch now …]` / `[Hold …]` /
`[Wrong agent …]`. A real normative statement written in either shape was skipped
silently, so a documentation drift could hide inside a carve-out. The lint now
requires a **context** signal as well as the shape; these two trees prove both
halves of that rule.

| Tree | Expected exit | What it holds |
|---|---|---|
| `hidden-drift/` | ❌ 1 | Normative statements in the bare and elided shapes with no example context — the drift the old carve-outs hid |
| `honored-carveouts/` | ✅ 0 | The same shapes, each carrying one of the three accepted context signals, plus one conformant statement so the scan is not empty |

Run both:

```
bash tests/lint-dispatch-labels.sh --root tests/fixtures/dispatch-labels/hidden-drift
bash tests/lint-dispatch-labels.sh --root tests/fixtures/dispatch-labels/honored-carveouts
```

The three accepted context signals are stated in the lint's header comment: a
fenced code block, a guard-conformant label of the same keyword on the same line,
or an explicit `<!-- dispatch-label-lint: example -->` annotation on the bracket's
line or the line above it.
