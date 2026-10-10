# Fleet inventory

Five devices, one tailnet (`tail138448.ts.net`).

| Device | Role | Host / Tailscale name | Tailscale IP | NixOS config in this repo |
| --- | --- | --- | --- | --- |
| PC | main desktop (Hyprland, Quickshell, heavy extras) | `grajpap` | 100.123.219.96 | `nixosConfigurations.grajpap` (nixpkgs unstable) |
| Laptop | 24/7 headless server (HomeNest, Nextcloud, restic) | `lenovo` | 100.110.204.8 | `nixosConfigurations.lenovo` (nixpkgs 25.11 stable + `unstablePkgs`) |
| Dell laptop | day-to-day / uni notes — same desktop as PC, minus heavy | `dellap` (will become `dell`) | 100.65.73.64 (online again) | `nixosConfigurations.dell` — exists on the dell's own checkout, not yet in this repo's flake |
| POCO X4 Pro 5G | adb test phone, USB-tethered to laptop | `poco-x4-pro-5g` | 100.110.155.84 | not NixOS — udev rule in `system/mobile/adb.nix` |
| Pixel 9a | personal phone, adb when docked | `grajpap-9a` | 100.106.96.44 | not NixOS — same rule |

Per-device details: [grajpap notes live in README](../README.md), [lenovo.md](lenovo.md), [dell.md](dell.md), [poco.md](poco.md), [pixel.md](pixel.md).

## Desktop profiles

The two desktop hosts share `system/` (wayland, core), `theme/` and all of
`home/` — same binds, shell, env and look. Divergence is controlled by host:

- **`fleet.heavy.enable`** (option, default `false`): PC-only extras —
  gaming (`home/features/gaming.nix`), Android Studio + SDK
  (`system/mobile/default.nix`), Nextcloud hosting (`system/sync`), restic
  backups (`system/backup`), health reporting (`system/monitoring`), data
  disks (`system/core/storage.nix`). Set `true` in
  `hosts/grajpap/default.nix` only.
- **`lenovo`** does not use the desktop stack at all — it is headless by
  design (`hosts/lenovo/modules/server.nix`). It still imports
  `system/maintenance` and `system/mobile/adb.nix` from the shared tree.
- **`system/mobile/adb.nix`** is the exception to both: fleet-wide, so adb
  and the phone udev rules work on every host.

## Access

- **grajpap**: local shell, or t3code opened in this repo.
- **lenovo**: `ssh lenovo-user` (LAN) or `ssh lenovo-user-ts` (tailnet) — user
  `grajpap`, passwordless `sudo`. Root SSH is disabled (`PermitRootLogin no`);
  the old `Host lenovo` / `lenovo-ts` aliases in `~/.ssh/config` still say
  `User root` and no longer work.
- **dell**: `ssh dell` (tailnet `dellap`) or `ssh dell-lan`
  (`192.168.1.126`), user `grajpap`, fleet key `id_ed25519_lenovo_fleet`.
  From the dell, lenovo is `ssh lenovo-user` / `ssh lenovo-user-ts`.
- **POCO**: `adb devices` from the laptop (USB).
- **Pixel**: `adb devices` from whichever machine it is docked to.

## Rebuild

On each host: `rebuild`. It picks the flake attribute from `$(hostname)`,
so `grajpap` switches `#grajpap` and `lenovo` switches `#lenovo`.
Validate from anywhere: `rebuild --check` (runs the flake's checks —
alejandra, statix, deadnix, shellcheck — for the whole fleet).

`fleet/status.sh` prints a quick health summary of the reachable devices.
