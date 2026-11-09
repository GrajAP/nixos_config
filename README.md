# nixos_config

One NixOS flake for the whole fleet:

| Host | Flake attr | nixpkgs | Role |
| --- | --- | --- | --- |
| PC | `grajpap` | unstable | desktop + `fleet.heavy` (games, Android Studio, backups) |
| Dell laptop | `dell` | unstable | same desktop, minus heavy, battery first |
| Lenovo laptop | `lenovo` | 25.11 stable | headless server: HomeNest, Nextcloud |

Device notes live in `fleet/`, start at `fleet/INVENTORY.md`.

## Rebuild

```bash
rebuild          # check, switch $(hostname), commit, push
rebuild --check  # flake checks only, no switch, no Git (rootless)
rebuild --build  # checks + build, no switch, no Git (rootless)
```

- Builds `path:/etc/nixos`, so the working tree is built, not `HEAD`.
- Inside T3 Code (`NoNewPrivs`), `sudo` runs on the host through `systemd-run`.
- It does not format files, update inputs or clean generations.

## Unattended updates

`auto-rebuild.timer` runs `fleet/auto-rebuild` once a day:

| Host | Time | Behaviour |
| --- | --- | --- |
| `lenovo` | 04:40 + up to 20 min | switch |
| `grajpap` | 05:20 + up to 2 h | `nix flake update`, then switch, or stage for next boot while a desktop session is open |

The run pulls, checks, commits local work, switches, and rolls back by itself
if a critical unit (`tailscaled`, `sshd`, plus `caddy` on lenovo) is down after
a live switch.
Only commits made on that host are pushed.

grajpap owns `flake.lock`: it keeps a new lock only if every host evaluates and
grajpap builds, then pushes it; lenovo gets it with the next manual deploy. While you are
logged in, the update lands at the next reboot, and an uncommitted edit in
`/etc/nixos` skips that day.

```bash
journalctl -u auto-rebuild.service -e
systemctl list-timers auto-rebuild.timer
```

## Layout

- `flake.nix`: inputs, hosts, checks
- `configuration.nix`: shared desktop base and `fleet.*` options
- `hosts/`: per-host config
- `system/`: NixOS modules
- `home/`: home-manager config (shell, Hyprland, Quickshell, apps, agent skills)
- `apps/`: own packages (T3 Code, whisprflow, ...)
- `theme/`: Stylix theme
- `fleet/`: device notes, `auto-rebuild`, `status.sh`
- `docs/recovery.md`: recovery steps
