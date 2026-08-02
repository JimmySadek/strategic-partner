# Fixture — drift that the old spelling-only carve-outs hid

Every statement below is written as an instruction to follow, not as an example.
Each one uses a shape the previous lint excused on spelling alone, so each one
used to pass silently. The lint must now report all four.

## Bare form presented as the label to use

When dispatching a specialist, gate it with `AskUserQuestion` and offer
`[Dispatch now]` as the confirming option.

## Elided form presented as the label to use

The three options are `[Dispatch now ...]`, `[Hold ...]` and `[Wrong agent ...]`.
Use those exact labels.

## Why this is a drift, not a nitpick

The guard compares the selected option label by exact string equality. A reader
who follows either statement above writes a label the guard rejects, and the
dispatch blocks every time.
