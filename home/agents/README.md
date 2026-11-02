# Fleet-wide agent skills

One source of truth for global AI-agent instructions and skills, synced to every
harness on every machine (opencode, claude code, codex, and the agent-agnostic
`~/.agents` location).

## Layout

- `AGENTS.md` - global instructions loaded by agents that support a global instructions file.
- `skills/<name>/SKILL.md` - one folder per skill. Add a folder here and it ships everywhere.
- `skills.nix` - the skill list: local `skills/` plus Theo's `full-send`, `full-stop`, `file-pr` and `babysit-pr` from the `tstack` flake input. `sol-loop` is a local rewrite that reviews without GPT Sol. They update when `flake.lock` does.
- `default.nix` - home-manager module that symlinks everything into place.

## What gets installed where

| Source | Targets |
| --- | --- |
| `skills/<name>/` | `~/.config/opencode/skills/<name>`, `~/.claude/skills/<name>`, `~/.agents/skills/<name>`, `~/.codex/skills/<name>` |
| `AGENTS.md` | `~/.config/opencode/AGENTS.md`, `~/.claude/CLAUDE.md`, `~/.agents/AGENTS.md`, `~/.gemini/GEMINI.md` |

Everything is a symlink into the Nix store: edit here, run `./rebuild.sh`, done.
`~/.codex/AGENTS.md` is left alone on purpose: it has local content.

## Hosts without home-manager

lenovo has no home-manager. `system/agents/default.nix` links the same files
into `/home/grajpap` with a oneshot service. Both modules read this directory,
so a new skill reaches every host.

## Adding a skill

```bash
mkdir home/agents/skills/my-skill
$EDITOR home/agents/skills/my-skill/SKILL.md
./rebuild.sh
```

The `SKILL.md` needs YAML frontmatter with `name` and `description`. The
description is the trigger: it is loaded into context for every conversation,
so it should carry the keywords for when the skill should fire.
