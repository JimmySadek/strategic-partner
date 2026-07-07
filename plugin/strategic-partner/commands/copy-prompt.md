---
name: copy-prompt
description: "Copy a recently emitted fenced prompt to the OS clipboard"
category: utility
complexity: low
mcp-servers: []
---

# /strategic-partner-plugin:copy-prompt — Clipboard Copy for Fenced Prompts

> Reads `.handoffs/last-prompts/` and pipes the selected prompt to the OS clipboard.
> Run immediately after any SP response that contained a `═══ COPY ═══` fence.

## Output Style

Terse. One confirmation line on success; one error line on failure. No extra prose.

## Behavioral Flow

The common case — exactly one saved prompt — is a **single Bash call** (Step 1).
The multi-prompt case adds a selection step (Steps 2–3). Both paths share the same
clipboard-detection logic and the same no-wipe rule.

### Step 1 — Fast path: one saved prompt → one shell call

Run the single self-contained Bash command below. It detects the OS and clipboard
tool, confirms exactly one `.md` exists in `.handoffs/last-prompts/`, pipes it to the
clipboard, and prints the confirmation — all in one invocation, with no descriptor
extraction. It exits with a distinct status when the directory is empty (so Step 2
runs the empty-dir message) or when 2+ prompts exist (so Step 2 lists them):

```bash
DIR=".handoffs/last-prompts"
N=$(ls "$DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$N" = "0" ]; then
  echo "__SP_EMPTY__"; exit 3
elif [ "$N" != "1" ]; then
  echo "__SP_MULTI__"; exit 4
fi
FILE=$(ls "$DIR"/*.md 2>/dev/null | head -1)
NUM=$(basename "$FILE" .md)
OS=$(uname -s)
REL=$(uname -r 2>/dev/null)
if [ "$OS" = "Darwin" ]; then
  CLIP="pbcopy"
elif printf '%s' "$REL" | grep -qiE 'microsoft|WSL'; then
  CLIP="clip.exe"
elif [ "$OS" = "Linux" ]; then
  if command -v xclip >/dev/null 2>&1; then
    CLIP="xclip -selection clipboard"
  elif command -v xsel >/dev/null 2>&1; then
    CLIP="xsel --clipboard --input"
  else
    echo "Clipboard copy failed: neither xclip nor xsel found. Install one with your package manager (e.g. apt install xclip) and retry."; exit 1
  fi
else
  case "$OS" in
    MINGW*|MSYS*|CYGWIN*) CLIP="clip.exe" ;;
    *) echo "Clipboard copy failed: unsupported OS $OS. Expected Darwin, Linux, WSL, or Windows (MINGW/MSYS/CYGWIN)."; exit 1 ;;
  esac
fi
if cat "$FILE" | $CLIP; then
  echo "Copied prompt $NUM to clipboard."
else
  echo "Clipboard copy failed: the $CLIP command returned a non-zero status."; exit 1
fi
```

Interpret the result:

- Confirmation line printed (`Copied prompt N to clipboard.`) → **done**. Report it and stop.
- A clipboard-failure error line printed → **done**. Report that line and stop.
- `__SP_EMPTY__` printed (exit 3) → the directory is missing or empty → go to **Step 2a**.
- `__SP_MULTI__` printed (exit 4) → two or more prompts exist → go to **Step 2b**.

### Step 2a — Empty directory message

If Step 1 printed `__SP_EMPTY__`, print:

> "No recent SP prompts found. The SP writes prompts to `.handoffs/last-prompts/` only when emitting fenced content. Run this subcommand after an SP response that contained a ═══ COPY ═══ fence."

Then exit cleanly. Do not error.

### Step 2b — List files for selection

If Step 1 printed `__SP_MULTI__`, list all `.md` files in `.handoffs/last-prompts/`
sorted numerically (`1.md`, `2.md`, …) in a single shell call. For each file, extract a
descriptor:

- Take the first non-empty, non-comment line of the file content (max 60 chars).
- Strip leading/trailing whitespace and any leading `# ` heading marker.
- If no such line is found, fall back to `"Prompt N"` where N is the file number.

### Step 3 — Select (multi-prompt only)

Invoke `AskUserQuestion` with one question. The question text is
`"Which prompt do you want to copy to clipboard?"`. Each option is one prompt:
label = the descriptor (truncated to 60 chars if needed). After the user selects,
run one shell call that pipes the chosen file to the clipboard using the same
OS-detection logic as Step 1 (Darwin → `pbcopy`; WSL → `clip.exe`; Linux →
`xclip`/`xsel` fallback; MINGW/MSYS/CYGWIN → `clip.exe`; otherwise the
unsupported-OS error), then print:

> "Copied prompt N ({descriptor}) to clipboard."

On a non-zero exit from the clipboard command, print the underlying command's
error output.

### Step 4 — Do NOT wipe the directory

Leave `.handoffs/last-prompts/` intact. Wiping is the write-side's responsibility —
the next SP response that emits fenced content will wipe and rewrite the directory.

## Boundaries

**Will:**
- Read files from `.handoffs/last-prompts/`
- Detect the OS and pipe file content to the detected clipboard command
- Present `AskUserQuestion` for multi-prompt selection

**Will Not:**
- Delete or modify any files in `.handoffs/last-prompts/`
- Start an advisory session or load the full SP persona
- Retry on clipboard failure — it reports and exits

## See Also

- `/strategic-partner-plugin:handoff` — the other SP command that emits a fenced prompt. The continuation prompt at session-end is the most common case for `:copy-prompt` to follow.
