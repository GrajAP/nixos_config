---
name: show-your-work
description: Prove that work actually works with evidence. Use when I ask to show your work, prove it works, prove it live, demonstrate the change, or when I say I doubt the claim.
---

# Show your work

Claims need evidence attached, in whatever surface this task touched.

1. Code: run the real check or test command and quote the minimal output that proves it. Screenshots of terminals count only after the command is named.
2. UI: with T3 preview tools, take the screenshot and reference the exact state: what is on screen and why it proves the point. Recording it is better than describing it.
3. Infra: show the service state (`systemctl status`), the log line, or the probe output that says the machine is actually in the claimed state.
4. PR: link the PR or commit hash, so the evidence stays reachable after the thread ends.

## Output shape

- What changed: one line.
- Proof: one bullet per claim, each with the command, link, or screenshot that backs it.
- Not covered: name what you did not verify, especially things I cannot check from here.

A failed test shown honestly is worth more than a claim of success: report the failure and the next step, never paint it green.
