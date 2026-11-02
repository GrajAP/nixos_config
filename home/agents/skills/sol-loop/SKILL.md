---
name: sol-loop
description: Review a change in a loop with an independent model before or after filing a PR. Use when I say "sol loop" or "review loop", and for the review step of full-send and full-stop.
---

# sol-loop (no Sol)

Replaces Theo's tstack `sol-loop`. I have no GPT Sol access, so never wait for Sol and never report "no Sol" as a blocker.

## Pick the reviewer

Call `orchestrator_capabilities` in T3 and take the first one that is enabled:

1. A different provider than the author: Claude Opus when Codex or OpenCode wrote the change, or Codex GPT when Claude wrote it.
2. The best enabled OpenCode model.
3. A fresh Claude Opus subagent: same model as the author, so say so in the report.

Gemini 3.8 Flash on Antigravity is low quality: use it only as an extra second opinion, never as the only reviewer.

## Loop

- Budget: 3 rounds. Up to 5 only for security, auth, data loss or concurrency, while a blocker is still open. Stop early when only nits are left.
- One reviewer per round, through `delegate_task` (`role: "review"`, `mode: "async"`). Wait for the notice. Do not poll. A timeout is not approval.
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
