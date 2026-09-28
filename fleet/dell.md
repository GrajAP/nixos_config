# dell — day-to-day laptop (uni notes)

Dell laptop, NixOS, the machine you actually sit in front of: same desktop
as `grajpap` (Hyprland, Quickshell, binds, shell, theme) but without the
heavy PC-only extras — no Android Studio/SDK, no games, no server/hosting.

- **Planned flake attr**: `nixosConfigurations.dell` via the shared
  `mkHost` path (`hosts/dell/` — hardware config + hostname only)
- **nixpkgs**: same unstable input as the PC (keeps the desktop 1:1)
- **Tailscale**: `dellap` → 100.65.73.64
- **SSH so far**: `~/.ssh/config` has `Host 192.168.21.22` / `User dellap`
  (LAN address; machine offline since Sep 24)

## Status: BLOCKED — machine offline

Cannot create `hosts/dell/` until the machine is reachable:

1. `hardware-configuration.nix` must be harvested from it (disks, initrd,
   microcode) — cannot be invented.
2. Its current user account is unconfirmed (`dellap` vs `grajpap` — the
   shared `home/` + `system/core/users.nix` assume `grajpap`).
3. Its existing NixOS config (if any) should be reviewed/merged before
   cutover.

When it is on the tailnet (`ssh dellap`), next steps: snapshot the old
repo/state, copy hardware config, add `hosts/dell/` + flake entry, run
`rebuild --check`, then switch **on the dell** (never cross-install).
