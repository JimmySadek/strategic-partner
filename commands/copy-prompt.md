---
name: copy-prompt
description: "Copy a recently emitted fenced prompt to the OS clipboard"
category: utility
complexity: low
mcp-servers: []
---

# /strategic-partner:copy-prompt — Clipboard Copy for Fenced Prompts

> Reads `.handoffs/last-prompts/` and pipes the selected prompt to the OS clipboard.
> Run immediately after any SP response that contained a `═══ COPY ═══` fence.

## Output Style

Terse. One confirmation line on success; one error line on failure. No extra prose.

## Behavioral Flow

### Step 1 — Locate the prompts directory

Check whether `.handoffs/last-prompts/` exists and contains `.md` files.

If the directory is missing or empty, print:

> "No recent SP prompts found. The SP writes prompts to `.handoffs/last-prompts/` only when emitting fenced content. Run this subcommand after an SP response that contained a ═══ COPY ═══ fence."

Then exit cleanly. Do not error.

### Step 2 — List files

List all `.md` files in `.handoffs/last-prompts/` sorted numerically (`1.md`, `2.md`, …).

For each file, extract a descriptor:
- Take the first non-empty, non-comment line of the file content (max 60 chars).
- Strip leading/trailing whitespace and any leading `# ` heading marker.
- If no such line is found, fall back to `"Prompt N"` where N is the file number.

### Step 3 — Select

**Exactly 1 file**: proceed directly to Step 4 with that file selected.

**2 or more files**: invoke `AskUserQuestion` with one question. The question text is
`"Which prompt do you want to copy to clipboard?"`. Each option is one prompt:
label = the descriptor (truncated to 60 chars if needed). After the user selects,
proceed to Step 4 with the selected file.

### Step 4 — Detect clipboard command

Run `uname -s` to detect the OS. Pick the clipboard command:

- `Darwin` → `pbcopy`
- WSL detection: `uname -r` contains `microsoft` or `WSL` (case-insensitive grep) → `clip.exe` (the Windows clipboard via WSL interop, not xclip)
- `Linux` (and not WSL) → try `xclip -selection clipboard`; if `xclip` is not found, try
  `xsel --clipboard --input`; if neither is found, print:
  > "Clipboard copy failed: neither `xclip` nor `xsel` found. Install one with your package manager (e.g. `apt install xclip`) and retry."
  Then exit.
- `MINGW*`, `MSYS*`, or `CYGWIN*` (glob match against uname output) → `clip.exe`
- Any other value → print:
  > "Clipboard copy failed: unsupported OS `{uname output}`. Expected Darwin, Linux, WSL, or Windows (MINGW/MSYS/CYGWIN)."
  Then exit.

### Step 5 — Copy and report

Pipe the selected file's full content to the detected clipboard command via Bash:

```
cat .handoffs/last-prompts/N.md | pbcopy         # macOS example
cat .handoffs/last-prompts/N.md | xclip -selection clipboard  # Linux xclip example
```

On success, print:
> "Copied prompt N ({descriptor}) to clipboard."

On failure (non-zero exit from the clipboard command), print the underlying command's
error output.

### Step 6 — Do NOT wipe the directory

Leave `.handoffs/last-prompts/` intact. Wiping is the write-side's responsibility —
the next SP response that emits fenced content will wipe and rewrite the directory.

## Boundaries

**Will:**
- Read files from `.handoffs/last-prompts/`
- Run `uname -s` and pipe file content to the detected clipboard command
- Present `AskUserQuestion` for multi-prompt selection

**Will Not:**
- Delete or modify any files in `.handoffs/last-prompts/`
- Start an advisory session or load the full SP persona
- Retry on clipboard failure — it reports and exits
