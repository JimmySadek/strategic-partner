# Cross-File Duplication Pair

The same rule defined in both files with substantive bodies. The
duplicates rules-file is referenced from the BG section so
file-discovery picks it up; B7 then evaluates the canonical hybrid
skip across the two files.

## Behavioral Guardrails

See [`.claude/rules/duplicates.md`](.claude/rules/duplicates.md) for
full content.

### Think Before Coding

State assumptions explicitly. When uncertain, ask. Don't pick silently.
This is the canonical Karpathy framing — surface confusion, reject
sycophancy as a dark pattern, push back when warranted.

### Surgical Changes

Touch only what the user asked for. Don't refactor adjacent code.
Match the file's existing style. Diff discipline at every changed line.
