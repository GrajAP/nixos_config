# Agent Guidelines for NixOS Config

This repository manages the fleet configuration for the hosts `grajpap` (PC)
and `lenovo` (24/7 laptop server). Follow these rules strictly when working here.

## Fleet

One flake, three hosts:

| Host | Flake attr | nixpkgs | Profile |
| --- | --- | --- | --- |
| PC | `grajpap` | unstable (`nixpkgs`) | desktop + `fleet.heavy.enable` (games, Android Studio, data disks) |
| Laptop | `lenovo` | 25.11 stable (`nixpkgs-stable`), unstable via `specialArgs.unstablePkgs` | headless server — no desktop, hosts Nextcloud |
| Dell laptop | `dell` | unstable (same as PC) | desktop minus heavy — 1:1 with PC |

- Desktop hosts share `system/wayland`, `system/core`, `theme/` and `home/`;
  PC-only extras are gated by `fleet.heavy.enable` and host imports in
  `hosts/grajpap/default.nix`.
- `rebuild` switches `#$(hostname)` — on each host it picks the right attribute.
- Access lenovo with `ssh lenovo-user` (LAN) / `ssh lenovo-user-ts` (tailnet),
  user `grajpap` + NOPASSWD sudo. Root SSH is disabled; the old
  `Host lenovo`/`lenovo-ts` aliases (`User root`) do not work.
- Phone notes (POCO adb over USB on lenovo, Pixel 9a) and full inventory:
  `fleet/` — start at `fleet/INVENTORY.md`. Health: `fleet/status.sh`.
- Agent skill for fleet questions: `home/agents/skills/fleet/` (symlinked
  into `.opencode/skills/fleet` for project sessions).

## Rebuild Script

The repository contains a helper script [rebuild.sh](file:///etc/nixos/rebuild.sh) (symlinked to `/run/current-system/sw/bin/rebuild` via alias).
It checks the flake with `nom` progress, builds and switches, commits changes,
and queues a background GitHub push for the current branch. Use
`./rebuild.sh --check` to only validate the flake without switching, or
`./rebuild.sh --build` to validate and build the system without switching.

Inside the T3 Code sandbox, `rebuild` transparently delegates `sudo` to the host via `systemd-run` to bypass the container's `no new privileges` restriction. Both `./rebuild.sh` and rootless modes (`--check` / `--build`) work seamlessly.

Do not embed a password or call `switch-to-configuration` directly.

## CRITICAL: DO NOT OVERTHINK

- Do NOT explain what you are about to do. Just do it.
- Do NOT list steps, create plans, or describe your approach.
- Do NOT think about edge cases before acting.
- Do NOT ask clarifying questions if the request is clear.
- Make the changes immediately.
- Test with `./rebuild.sh --check` before claiming done.
- If it passes, you are done.
- Stop typing. Start acting.

## Repository Layout

- `flake.nix` — Flake inputs, both host outputs, and checks.
- `hosts/` — Per-host NixOS configuration (`grajpap/`, `lenovo/`).
- `fleet/` — Device inventory, per-device notes, health script.
- `system/` — NixOS system-level configuration (hardware, boot, networking, desktop).
- `home/` — Home Manager user configuration (shell, desktop theme, apps).
- `apps/` — Custom package derivations (e.g., quickshell, t3code).
- `theme/` — System-wide color scheme and styling assets.

## Git Rules

- Keep `main` clean and deployable.
- Do NOT commit broken configurations; check with `./rebuild.sh --check` first.
- Rebuilding via `./rebuild.sh` automatically commits and pushes if switching succeeds.

## Code Quality

- Format Nix files with `alejandra`.
- Run checks with `./rebuild.sh --check` before finishing.
