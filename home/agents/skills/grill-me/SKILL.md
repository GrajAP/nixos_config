---
name: grill-me
description: Interview me one question at a time about a plan or design until we reach shared understanding. Use when I ask to grill me, stress-test a plan, poke holes in a design, or when I say a plan feels off but cannot name why. Not for implementation.
---

# Grill me

Interview me relentlessly about this plan until we reach shared understanding.
Walk the decision tree, one branch at a time, parent decisions before the
choices that hang off them.

## How to ask

- One question at a time. Wait for my answer. Never dump a batch.
- Every question comes with your recommended answer, so I react to a proposal instead of a blank prompt.
- Keep questions short: one sentence, plain English.
- If the repo can answer it, read the code instead of asking me.
- Mark the question number and the branch it belongs to, so I can see the tree filling in.

## Stopping

- Stop early when the remaining branches are unimportant.
- I want questions that change scope, not trivia that confirms it.
- End the session with a bullet list of every decision we settled, and one bullet for anything we left unresolved.

I would rather be annoyed by a hard question than skip a soft spot: the point is to surface implicit calls, so assume conflicting answers reveal the real decision. This interview is stateless: it writes nothing; if ADRs or a written spec are wanted, I ask for that separately after the last question.
