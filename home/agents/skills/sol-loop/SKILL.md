---
name: sol-loop
description: Review a change in a loop with an independent model before or after filing a PR. Use when I say "sol loop" or "review loop", and for the review step of full-send and full-stop.
---

# sol-loop (no Sol)

Replaces Theo's tstack `sol-loop`. I have no GPT Sol access, so never wait for Sol and never report "no Sol" as a blocker.

## Pick the reviewer

Call `orchestrator_capabilities` in T3 and take the first one that is enabled:

1. The strongest model on a different provider than the author: Claude Opus first, then Codex GPT.
2. Claude Opus 4.6 (Thinking) on Antigravity.
3. The best enabled OpenCode model.
4. A fresh subagent on the author's own model: say so in the report.

A missing reviewer or a "quota reached" error is not a blocker: go down the list.

Gemini 3.8 Flash on Antigravity is low quality: use it only as an extra second opinion, never as the only reviewer.

An APPROVE from one free model does not end the loop. Run a second, different free model on the same brief in the same round: done needs both to approve. If only one free model is enabled, it reviews alone: say so in the report.

## Loop

- Budget: 3 rounds. Up to 5 only for security, auth, data loss or concurrency, while a blocker is still open. Stop early when only nits are left.
- One reviewer per round, or two different free models, through `delegate_task` (`role: "review"`, `mode: "async"`). Wait for the notice. Do not poll. A timeout is not approval.
- Do not edit the scoped files while a review runs.

Round 1 brief (the child gets no history):

```
Review only. Do not edit, commit, push, comment on PRs, or start subagents.
Repo: <abs path> Base: <sha> Intent: <intent> Out of scope: <scope> Checks: <results>
See: git diff <base>; git status --short (read untracked files).
Find bugs, broken callers, mismatch with intent. Skip style unless it hides a bug.
Flag code the intent does not need.
blocker = intended case wrong. should = real bug callers will hit. nit = rest.
Reply:
VERDICT: APPROVE or CHANGES
S1 [blocker|should|nit] <file>:<line> <claim>. Fix: <suggestion>
```

## Answer findings

- Check every finding yourself. Agree: make the smallest fix. Disagree: give file:line or output as evidence. Nit or out of scope: decline in one line.
- Later rounds: send the same brief, the ledger (fixed / disagree / declined) and the diff since the last round.
- Done when the reviewer approves the current diff and no blocker or should is open. If a point is still disputed after two replies, show both sides and let me decide.

Report: rounds, reviewer model, what changed, findings fixed and declined.
