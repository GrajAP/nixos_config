# Fleet-wide agent skills

One source of truth for global AI-agent instructions and skills, synced to every
harness on every machine (opencode, claude code, codex, and the agent-agnostic
`~/.agents` location).

## Layout

- `AGENTS.md` - global instructions loaded by agents that support a global instructions file.
- `skills/<name>/SKILL.md` - one folder per skill. Add a folder here and it ships everywhere.
- `default.nix` - home-manager module that symlinks everything into place.

## What gets installed where

| Source | Targets |
| --- | --- |
| `skills/<name>/` | `~/.config/opencode/skills/<name>`, `~/.claude/skills/<name>`, `~/.agents/skills/<name>`, `~/.codex/skills/<name>` |
| `AGENTS.md` | `~/.config/opencode/AGENTS.md`, `~/.claude/CLAUDE.md`, `~/.agents/AGENTS.md` |

Everything is a symlink into the Nix store: edit here, run `./rebuild.sh`, done.
`~/.codex/AGENTS.md` is intentionally left alone because it already has local content.

## Heads without home-manager

`lenovo` is headless and has no home-manager, so `default.nix` above never runs
there and it used to get nothing at all — the one gap that let a skill silently
exist on two machines and not the others.

`system/agents/default.nix` is the same deployment in system scope, reading the
same `AGENTS.md` and `skills/`, installed by a oneshot into `/home/grajpap`. It
is imported by lenovo and links exactly the same paths listed above.

Both modules read the same directory, so a new skill folder reaches the desktops
through home-manager and the headless hosts through the system module, with no
second list to keep in step. Two mechanisms rather than one, because the store
links home-manager makes are the right thing where they are available and simply
do not exist without it.

## Adding a skill

```bash
mkdir home/agents/skills/my-skill
$EDITOR home/agents/skills/my-skill/SKILL.md
./rebuild.sh
```

The `SKILL.md` needs YAML frontmatter with `name` and `description`. The
description is the trigger: it is loaded into context for every conversation,
so it should carry the keywords for when the skill should fire.

## Other machines

This lives in the same repo as the NixOS config, so pulling this repo and
running `./rebuild.sh` on any machine gives it the identical fleet.
