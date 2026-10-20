---
name: audit
description: Audit my recent conversations to find repeated agent mistakes and propose targeted rule edits. Use when I ask to audit you, review my agent history, find my failure patterns, or tune the setup based on what went wrong.
---

# Audit

Mine history for corrections, then encode each one as the smallest possible rule.

1. Read recent sessions on this topic and list what actually went wrong, grouped by model and harness: over-asked edits, colliding parallel edits, premature PRs, dumped plans, tool misuse, stopping without reporting a simple fix.
2. For each failure pattern, propose one targeted line for the global instructions or a skill, so it does not clash with something already there.
3. Review the current instructions as well: delete any rule that does not describe a mistake worth its upkeep, and merge duplicates.
4. Deliver a short table: observed incident, proposed one-line rule, file to edit. Present rows one at a time so I can approve or reject each.

## Guardrails

- The goal of instruction files is a small set of lines that steer behavior; a rule without an observed mistake behind it is deleted, not kept.
- Prefer positive framing: state what to do instead of a list of prohibitions.
- Quote my actual corrections from real incidents, so every proposed rule points at evidence, not vibes.
- Do not edit the instruction files during the audit; propose only, edit after my approval.
