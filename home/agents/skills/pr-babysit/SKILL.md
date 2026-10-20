---
name: pr-babysit
description: Watch a PR and drive it to green without me in the loop. Use when I ask to babysit, watch, monitor, or keep a PR green until merge, or when check comments or review changes land on my PR. Not for creating a PR; use pr for that.
---

# Babysit a PR

Loop on this single PR until it is green and reviewable, then hand the merge decision back to me.

1. Use the T3 PR watch (`watch_pull_request`) instead of a polling loop.
2. When a check or comment arrives, classify it before touching code:
   - Real bug: fix it, push, comment what changed.
   - Nit: apply it only if cheap, otherwise push back with one reason.
   - False positive or infra flake: rerun or disarm with a one-line written reason, then stop touching it.
3. Verify every reviewer or bot claim against the actual code before changing anything. A wrong claim is answered with the file and line that disproves it, not with agreement.
4. Only act on comments and checks that arrived after my latest push; stale ones can be resolved without new commits.

## Rules

- Answer on my behalf, plainly and politely, in simple English: reviewers see the human's PR, so reply like me, not like a changelog.
- If another PR supersedes this one, stop monitoring and ask me before closing anything.
- Distinguish repo failures from infra flakes in check logs; never push a "fix" for a flake it cannot fix.
- When the PR is green, list the block: what was exercised, what was fixed over time, what open issue remains. Then release the watch back to me.
- No new scope during babysitting: fixes only, or the PR balloons.
