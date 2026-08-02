# Dispatch-label carve-out fixtures

Self-test material for `tests/lint-dispatch-labels.sh`. These files are excluded
from the lint's default repo scan, because most of them exist to be rejected.

The lint excuses two label shapes as example text — the bare `[Dispatch now]`
and the elided `[Dispatch now …]` / `[Hold …]` / `[Wrong agent …]`. Two rounds of
review found two ways drift could hide inside that carve-out:

1. **Spelling alone excused it.** A real normative statement written in either
   shape was skipped silently.
2. **Structure alone excused it.** Sitting inside a fenced block, or sharing a
   line with a correct label, was treated as proof the author meant an example.
   Neither is proof — a fence is an indentation convention, and a correct label
   beside an incorrect one is how a normative "either form works" list reads.

The lint now needs an **author declaration** (the `<!-- dispatch-label-lint:
example -->` annotation), or a **structural signal together with an example
marker** in the surrounding prose. These five trees prove every half of that.

| Tree | Expected exit | What it holds |
|---|---|---|
| `hidden-drift/` | ❌ 1 | Normative statements in the bare and elided shapes with no example context at all |
| `fence-drift/` | ❌ 1 | A normative bare label inside a fence that no marker introduces |
| `sameline-drift/` | ❌ 1 | An incorrect label sharing a line with a correct one, with no marker near it |
| `marked-fence/` | ✅ 0 | A genuine counterexample inside a fence the prose above it marks as one |
| `honored-carveouts/` | ✅ 0 | Each accepted justification once, plus one conformant statement so the scan is not empty |

Run any of them:

```
bash tests/lint-dispatch-labels.sh --root tests/fixtures/dispatch-labels/<tree>
```

The marker set, the marker window and the exact rule are stated in the lint's
own header comment — read that before adding a fixture, so a new one exercises
the rule as written rather than as remembered.
