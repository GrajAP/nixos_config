---
name: unslop
description: Remove AI slop from code and copy. Use when the user asks to clean up, unslop, de-slop, remove unnecessary comments or filler, trim unused code or imports, tighten prose or docs, delete em dashes, or shorten anything written.
---

# Unslop

Kill low-signal artifacts while preserving behavior and intent. First-person voice for prose, repo-agnostic for code: detect the repo's own conventions instead of assuming a stack.

## Workflow

1. **Triage**: scan for redundancy, dead code, filler prose, dash abuse, style drift. Match the repo's conventions, whatever the stack.
2. **Comments, code**: delete restatement (name already says it). Keep constraints, workarounds, and tickets.
3. **Dead code**: remove unused imports, variables, props, helpers, commented-out blocks, placeholder branches.
4. **Copy, docs, UI strings**: cut filler ("certainly", "in summary", "it's worth noting"), hedges, and redundant intros. Short sentences, conclusion first.
5. **Dashes**: remove every em dash and en dash, in prose, comments, docs, and UI strings. Replace with ",", ":" or "-".
6. **Validate**: run the repo's checks (format, lint, typecheck). Behavior must be unchanged outside cleanup.

## Decision checklist

- Comment explains why: keep. Paraphrases the code: delete.
- Unreferenced: delete.
- Removing it changes behavior or tests: stop, keep or re-check.
- Sentence over 20 words: split or cut.
- Em or en dash found: replace per rule 5.

## Guardrails

- No drive-by refactors or formatting churn beyond what was asked.
- Keep any workaround the user asked to preserve.
- If the repo has its own style guide, it wins over everything here.
