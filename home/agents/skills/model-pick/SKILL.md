---
name: model-pick
description: Pick a model for a task and shape the prompt. Use when I ask which model, best model, what model to use, or how to prompt something, and when choosing a worker for delegated work in T3 Code.
---

# Model pick

Theo's rule: model choice is a workflow decision, not loyalty. Match cost and taste to the task.

## Live match

Model lists churn weekly. Before mapping a task, run the orchestrator capabilities
tool in T3 Code to see what is actually enabled right now. Never hardcode model ids
in docs; read them live.

## Rubric (cost / intelligence / taste)

1. **Cost**: cheap tokens make bulk work free. Use free tier models for mechanical,
   parallel, or high-volume work.
2. **Intelligence**: the model's ceiling. Matters for hard debugging, refactors,
   and anything where a wrong answer costs more than the tokens.
3. **Taste**: opinions about UI, code polish, API design, copy. Only models with
   taste >= 7 should touch anything I will see.

## Rules I follow (Theo style)

- Free models for: bulk file sweeps, parallel audits, mechanical edits, one and
  done scripts, formatting, searching. Errors are cheap to spot and rerun.
- Strong models for: reviews, architecture, user facing UI, security, anything
  where wrong is expensive.
- Never the cheapest model for a code review.
- For independent verification, delegate to a different provider than the one that
  wrote the code.
- Escalate to a stronger model silently when a cheap model fails twice. Do not
  ask permission, do not mention the retry.

## Mapping for this fleet (as of Oct 2026)

- OpenCode free models (GLM 5.3 flash, DeepSeek V4.1 flash, MiMo, Nemotron):
  mechanical work, sweeps, audits, delegateable children.
- Codex models (GPT 5.6 luna/terra, GPT 6 luna): workhorse and reviews. Theo:
  Luna beats last gen Opus at fraction of price, Terra is the balanced pick.
- Antigravity (Gemini 3.8 flash): third independent opinion for cross provider
  review rounds, cheap.
- Claude (Opus 5.5, Fable 5.1): Theo's gold standard for code taste, but not
  enabled here. If it ever is: reviews and everything user facing.
- Frontier tier (Sol, Fable): only for the hardest single-threaded problems, long
  autonomy runs, or when everything else has failed two rounds.

## How to prompt (Theo's pattern)

A prompt needs six things. Write them like this when composing any task prompt
directly or in delegation:

1. **Context**: enough background that the worker does not need to re-derive my
   situation. Diff off, not on.
2. **User impact**: who feels a failure and how. "If this breaks, the user cannot
   read their email" beats "please be careful" by a mile.
3. **No compromise line**: state the quality bar explicitly. "I expect overdue
   safeguards here, no exceptions" pushes back against the model's sycophancy.
4. **Invite pushback**: end with "in my opinion though, not certain about this
   approach, open to alternatives." Turn asks into offers.
5. **Knowledge gaps**: say what I do not know, e.g. whether the API is newer than
   my training data. Ask the model to be honest about gaps before it answers.
6. **Definition of done**: concrete end state so the task cannot stretch to
   infinity. "Done means, module loads, tests pass, no new deps."

For investigation tasks: "come back when you have a confident solution" turns a
fetch into an inquiry. For simple tasks: grant permission to stop early when a
fix is found. For any result that makes no sense to me: "ELI5" on demand.
