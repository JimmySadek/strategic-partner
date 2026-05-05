# Inline Shell Heavy

This file has multi-line shell snippets that should trigger S6.

## Setup

```bash
git status
git log --oneline -5
git diff
ls -la
echo "checked"
```

## Tear-down

```sh
rm -rf node_modules
rm -rf .venv
rm -rf dist
echo done
```

## Annotated example (should NOT fire)

```bash
# example only
git status
git log
git diff
echo
```
