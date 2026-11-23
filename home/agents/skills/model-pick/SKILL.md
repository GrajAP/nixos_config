---
name: model-pick
description: Pick a model for a task and shape the prompt. Use when I ask which model, best model, what model to use, or how to prompt something, and when choosing a worker for delegated work in T3 Code.
---

# Model pick

Pick by cost, intelligence and taste, not loyalty.

## Check what is enabled

In T3 Code, call `orchestrator_capabilities` first and use only models it lists as enabled. Model lists change weekly; the tiers below are a guide, the live list wins.

## Tiers

| Tier | Use for | Examples (Nov 2026) |
| --- | --- | --- |
| Free, unlimited | Very simple, mechanical work only: searches, renames, formatting, one-line edits | Antigravity subagents (Gemini 3.8 Flash, high); OpenCode free models |
| Workhorse | Normal coding, debugging, reviews | Codex (GPT 5.6 Luna/Terra, GPT 6 Luna) |
| Strong, taste | Reviews, plans, UI, docs, copy, security | Claude Opus 5.5; Antigravity Claude Opus 4.6 (Thinking) |
| Frontier | Hardest single problems, after two failed rounds | Claude Fable 5.2 (no GPT Sol access) |

- Antigravity Gemini is unlimited but low quality: never the only reviewer, no judgment work, nothing I will read.
- Antigravity Claude has a small quota that resets after days: on "quota reached", move on, do not wait.
- Never one free model alone for a code review: use two different ones.
- Independent review: a different provider than the author.
- If a cheap model fails twice, redo it with a stronger one and tell me you did.

## When a tier is empty

My Claude Max plan ends around 2026-11-29. After that, expect no Claude on the Claude and OpenCode providers.

- Take the best enabled model from the next tier down. Do not wait for a missing model.
- Strong tier empty: give the job to two different models in separate runs, a workhorse first, a free model only as the second. Keep what both say, check the rest in the code yourself, show me what is still disputed.
- Frontier tier empty: after two failed rounds, stop and tell me what was tried and the one open question.

## Prompt shape

1. Context: what the worker needs so it does not re-derive my situation.
2. Impact: who feels a failure and how.
3. Quality bar: say it explicitly.
4. Gaps: what I do not know; ask it to flag its own gaps.
5. Done: a concrete end state ("module loads, checks pass, no new deps").

For investigations: "come back with a confident solution". For small tasks: allow stopping as soon as a fix is found.

A free or flash worker also needs:

- One task per child, with the exact files it may edit.
- The check command to run, and its output pasted in the reply.
- What not to touch, and "do not commit".
