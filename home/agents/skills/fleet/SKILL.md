---
name: fleet
description: Use when working in this NixOS fleet repo - questions about devices (grajpap PC, lenovo laptop, POCO/Pixel phones), rebuilds, SSH access, tailscale, host-specific config, or which flake attribute to build.
---

# Fleet

This repo is one flake for the whole fleet: `grajpap` (PC) and `lenovo`
(24/7 laptop server), plus two Android phones configured around them.

## Devices

| Name | What | Access |
| --- | --- | --- |
| `grajpap` | PC, main desktop | this checkout, local shell |
| `lenovo` | laptop server (HomeNest, Nextcloud) | `ssh lenovo-user` / `ssh lenovo-user-ts`, `sudo -i` NOPASSWD |
| `poco-x4-pro-5g` | test phone, USB to lenovo | `adb devices` on lenovo |
| `grajpap-9a` | Pixel 9a | `adb devices` on the host it is docked to |

Root SSH on lenovo is disabled; the `Host lenovo`/`lenovo-ts` aliases
(`User root`) are dead — use `lenovo-user*`.

## Rules

- Flake attribute = `$(hostname)`: `nixos-rebuild --flake .#$(hostname)`.
  `rebuild` does this for you on each host.
- `rebuild --check` runs whole-fleet checks (alejandra, statix, deadnix,
  shellcheck). Must pass before claiming done.
- `lenovo` builds against `nixpkgs-stable` (25.11); unstable packages come
  from `specialArgs.unstablePkgs`. Do not add a second unstable input.
- Laptop config lives in `hosts/lenovo/`, one module per concern. No
  home-manager on lenovo.
- When developing untracked files, use `path:/etc/nixos` flake references —
  git-based flakes only see tracked files.

## Docs

Full inventory and per-device details are in `fleet/` (see `fleet/INVENTORY.md`).
Health check: `fleet/status.sh`.
