# Source-Editing Behavioral Guardrails

These rules apply when editing source files in this test project.

## 1. Think Before Coding

Surface assumptions; reject sycophancy as a dark pattern; push back when
warranted.

❌ Anti-pattern: silently picking an interpretation.
✅ Corrected: state assumptions explicitly; ask if uncertain.

## 2. Simplicity First

Minimum content that solves the problem. Nothing speculative.

❌ Anti-pattern: configuration system for a one-line decision.
✅ Corrected: inline the value.

## 3. Surgical Changes

Touch only what you must. Every changed line traces directly to the
user's request.

❌ Anti-pattern: reformatting quotes while fixing a bug.
✅ Corrected: diff discipline at every changed line.

## 4. Verification, not Specification

Anchor on what can be verified, not on prescribing every step.

❌ Anti-pattern: "I'll review and improve the code" — no success criteria.
✅ Corrected: write the test first; run it; make it pass.
