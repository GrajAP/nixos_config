---
name: pr
description: File and open a pull request for finished work. Use when I ask to file, open, or create a PR, or to ship, land, or submit the current change. Not for watching or monitoring an existing PR; use pr-babysit for that.
---

# File a PR

Do quality and honest sizing first, then open the PR.

1. Run the repo's checks (`./rebuild.sh --check` here) and make sure they pass.
2. Commit only the files the change needs, clean of debug leftovers.
3. Push a short, plain branch name and open a normal (not draft) PR: review automation skips drafts.

## Title and body

- Title: say what changed in one plain sentence. No prefixes, no word salad.
- Body: two headings, "Problem" and "Solution", one or two short bullets each.
- No implementation inventory lists ("modified file X, line Y"): the diff is right there.
- Add "How to test" when the change is not provable from checks alone.
- Keep the English simple: I am not a native speaker, and neither is the next reader.

## In T3 Code

- Register the PR with `link_pull_request` right after creating it, so the thread tracks checks and comments.
- If I ask for it, follow up with pr-babysit.
