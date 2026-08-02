# Fixture — the three context signals that legitimately excuse example text

Each section below uses a bare or elided label shape, and each carries exactly
one of the three accepted context signals. The lint must skip all of them and
still exit 0.

## Signal 1 — inside a fenced code block

```
[Dispatch now]
[Hold ...]
[Wrong agent ...]
```

## Signal 2 — a conformant label of the same keyword on the same line

Write `[Dispatch now - frontend-architect]`, never the generic `[Dispatch now]`.

## Signal 3 — an explicit annotation on the bracket's own line

The lint scans for any `[Dispatch now ...]` statement in the docs. <!-- dispatch-label-lint: example -->

## Signal 3 again — the annotation on the line above

<!-- dispatch-label-lint: example -->
A turn that offers no `[Hold ...]` option has skipped the confirmation entirely.

## One real statement, so the scan is not empty

Every specialist dispatch is gated by `AskUserQuestion` with three options:
`[Dispatch now - backend-architect]`, `[Hold - let me review the brief first]`
and `[Wrong agent - let me pick]`.
