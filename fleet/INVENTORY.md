# Fleet inventory

Four devices, one tailnet (`tail138448.ts.net`).

| Device | Role | Host / Tailscale name | Tailscale IP | NixOS config in this repo |
| --- | --- | --- | --- | --- |
| PC | main desktop (Hyprland, Quickshell) | `grajpap` | 100.123.219.96 | `nixosConfigurations.grajpap` (nixpkgs unstable) |
| Laptop | 24/7 server (HomeNest, Nextcloud, restic) | `lenovo` | 100.110.204.8 | `nixosConfigurations.lenovo` (nixpkgs 25.11 stable + `unstablePkgs`) |
| POCO X4 Pro 5G | adb test phone, USB-tethered to laptop | `poco-x4-pro-5g` | 100.110.155.84 | not NixOS — udev rule lives in `hosts/lenovo/modules/mobile.nix` |
| Pixel 9a | personal phone, adb when docked | `grajpap-9a` | 100.106.96.44 | not NixOS |

Per-device details: [lenovo.md](lenovo.md), [poco.md](poco.md), [pixel.md](pixel.md).

## Access

- **grajpap**: local shell, or t3code opened in this repo.
- **lenovo**: `ssh lenovo-user` (LAN) or `ssh lenovo-user-ts` (tailnet) — user
  `grajpap`, passwordless `sudo`. Root SSH is disabled (`PermitRootLogin no`);
  the old `Host lenovo` / `lenovo-ts` aliases in `~/.ssh/config` still say
  `User root` and no longer work.
- **POCO**: `adb devices` from the laptop (USB).
- **Pixel**: `adb devices` from whichever machine it is docked to.

## Rebuild

On each host: `rebuild`. It picks the flake attribute from `$(hostname)`,
so `grajpap` switches `#grajpap` and `lenovo` switches `#lenovo`.
Validate from anywhere: `rebuild --check` (runs the flake's checks —
alejandra, statix, deadnix, shellcheck — for the whole fleet).

`fleet/status.sh` prints a quick health summary of all four devices.
