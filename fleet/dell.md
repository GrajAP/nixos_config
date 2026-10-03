# dell — day-to-day laptop (uni notes)

Dell laptop, NixOS, the machine you actually sit in front of: same desktop
as `grajpap` (Hyprland, Quickshell, binds, shell, theme) but without the
heavy PC-only extras — no Android Studio/SDK, no games, no server/hosting.

- **Planned flake attr**: `nixosConfigurations.dell` via the shared
  `mkHost` path (`hosts/dell/` — hardware config + hostname only)
- **nixpkgs**: same unstable input as the PC (keeps the desktop 1:1)
- **Tailscale**: `dellap` → 100.65.73.64
- **Tailscale**: `dellap` → 100.65.73.64, online again (was offline since Sep 24)
- **SSH in** (from the PC): `ssh dell` (tailnet) or `ssh dell-lan`
  (`192.168.1.126`), user `grajpap`, fleet key `id_ed25519_lenovo_fleet`
- **SSH out** to lenovo, `~/.ssh/config` on the dell itself:
  `ssh lenovo-user` / `ssh lenovo-user-ts` (tailnet, canonical names),
  `ssh lenovo-user-lan` / `ssh lenovo-lan` (`192.168.1.136`), key
  `id_ed25519_dell_to_lenovo`. Plain `ssh lenovo` is kept as a tailnet alias.
  Keep the canonical `lenovo-user*` names here — fleet docs and
  `fleet/status.sh` use them.

## Status: online, ahead of this repo

It is reachable and runs NixOS 26.11 as user `grajpap`. Its own checkout at
`/etc/nixos` already has `hosts/dell/{default,hardware-configuration}.nix`
and a `dell` flake output, with uncommitted work on top of commit
`48657cc` (quickshell battery widget, hyprland displayScale).

What is still missing here:

1. `hosts/dell/` is not in this repo's tree, and `flake.nix` has no `dell`
   output — the dell only builds from its own checkout.
2. Those uncommitted changes on the dell need to land on a branch here and
   be pushed, or they are lost if that checkout is reset.
3. Confirm the desktop stays 1:1 with the PC (`fleet.heavy.enable = false`).

Next steps: bring the dell's commits over, add `hosts/dell/` + the flake
entry, run `rebuild --check`, then switch **on the dell** (never
cross-install).
