# Fixture — the justifications that legitimately excuse example text

Each section below uses a bare or elided label shape, and each carries one of
the accepted justifications: the author annotation standing on its own, or a
structural signal together with a marker. The lint must skip all of them and
still exit 0.

## A fenced block, with the marker in the prose that introduces it

Bad: never write the bare or elided spellings below. The guard rejects them.

```
[Dispatch now]
[Hold ...]
[Wrong agent ...]
```

## A conformant label on the same line, with the marker on that line

Write `[Dispatch now - frontend-architect]`, never the generic `[Dispatch now]`.

## An explicit annotation on the bracket's own line

The lint scans for any `[Dispatch now ...]` statement in the docs. <!-- dispatch-label-lint: example -->

## The same annotation, on the line above

<!-- dispatch-label-lint: example -->
A turn that offers no `[Hold ...]` option has skipped the confirmation entirely.

## One real statement, so the scan is not empty

Every specialist dispatch is gated by `AskUserQuestion` with three options:
`[Dispatch now - backend-architect]`, `[Hold - let me review the brief first]`
and `[Wrong agent - let me pick]`.
