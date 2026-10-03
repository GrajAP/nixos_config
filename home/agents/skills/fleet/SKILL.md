---
name: fleet
description: Use when working in this NixOS fleet repo - questions about devices (grajpap PC, lenovo server, dell laptop, POCO/Pixel phones), rebuilds, SSH access, tailscale, host-specific config, desktop profiles, or which flake attribute to build.
---

# Fleet

This repo is one flake for the whole fleet: `grajpap` (PC), `lenovo`
(24/7 headless server), `dell` (day-to-day uni laptop), plus two
Android phones configured around them.

## Devices

| Name | What | Access |
| --- | --- | --- |
| `grajpap` | PC, desktop + heavy extras + hosting | this checkout, local shell |
| `lenovo` | headless laptop server (HomeNest, Nextcloud) | `ssh lenovo-user` / `ssh lenovo-user-ts`, `sudo -i` NOPASSWD |
| `dell` (`dellap`) | uni laptop, desktop minus heavy | `ssh dell` / `dell-lan` — `fleet/dell.md` |
| `poco-x4-pro-5g` | test phone, USB to lenovo | `adb devices` on lenovo |
| `grajpap-9a` | Pixel 9a | `adb devices` on the host it is docked to |

Root SSH on lenovo is disabled; the `Host lenovo`/`lenovo-ts` aliases
(`User root`) are dead — use `lenovo-user*`.

## Desktop profiles

Both desktop hosts share `system/wayland`, `system/core`, `theme/` and all
of `home/` (same binds/shell/env). Divergence:

- `fleet.heavy.enable = true` (only in `hosts/grajpap/default.nix`) pulls in
  gaming, Android Studio/SDK, Nextcloud hosting, restic backups, health
  reporting and the PC data disks.
- `lenovo` never touches the desktop stack — headless on purpose.
- `system/mobile/adb.nix` is fleet-wide, not heavy: adb, scrcpy and the
  phone udev rules (Xiaomi 2717, Google 18d1) are on every host.
  `programs.adb.enable` does not exist in nixpkgs >= 26.05, so use
  `pkgs.android-tools` in any shared module.

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
