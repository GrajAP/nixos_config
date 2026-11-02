---
name: model-pick
description: Pick a model for a task and shape the prompt. Use when I ask which model, best model, what model to use, or how to prompt something, and when choosing a worker for delegated work in T3 Code.
---

# Model pick

Pick by cost, intelligence and taste, not loyalty.

## Check what is enabled

In T3 Code, call `orchestrator_capabilities` first. Model lists change weekly; the tiers below are a guide, the live list wins.

## Tiers

| Tier | Use for | Examples (Nov 2026) |
| --- | --- | --- |
| Free, unlimited | Very simple, mechanical work only: searches, renames, formatting, one-line edits | Antigravity subagents (Gemini 3.8 Flash, high); OpenCode free models |
| Workhorse | Normal coding, debugging, reviews | Codex (GPT 5.6 Luna/Terra, GPT 6 Luna) |
| Strong, taste | Reviews, plans, UI, docs, copy, security | Claude Opus 5.5 |
| Frontier | Hardest single problems, after two failed rounds | Fable 5.1 (no GPT Sol access) |

- Antigravity is unlimited but low quality: never give it judgment work, reviews or anything I will read.
- Never the cheapest model for a code review.
- Independent review: a different provider than the author.
- If a cheap model fails twice, redo it with a stronger one and tell me you did.

## Prompt shape

1. Context: what the worker needs so it does not re-derive my situation.
2. Impact: who feels a failure and how.
3. Quality bar: say it explicitly.
4. Gaps: what I do not know; ask it to flag its own gaps.
5. Done: a concrete end state ("module loads, checks pass, no new deps").

For investigations: "come back with a confident solution". For small tasks: allow stopping as soon as a fix is found.
