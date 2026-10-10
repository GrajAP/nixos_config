# dell — day-to-day laptop (uni notes)

Dell laptop, NixOS, the machine you actually sit in front of: same desktop as
`grajpap` (Hyprland, Quickshell, binds, shell, theme) but without the heavy
PC-only extras — no games, no server/hosting — and tuned for battery life
first. Android tooling is the one mobile thing it does get: `adb`,
platform-tools, the Android SDK and the native build deps are imported, so
React Native works against a real USB phone. Android Studio and the emulator
stay behind `fleet.heavy.enable`.

- **Flake attr**: `nixosConfigurations.dell` via the shared `mkHost` path
  (`hosts/dell/`)
- **nixpkgs**: same unstable input as the PC (keeps the desktop 1:1)
- **Bootloader**: systemd-boot, single boot. It has a `/boot/loader` and a
  `systemd-bootx64.efi` on its ESP, so `fleet.bootloader = "systemd-boot"` and
  `fleet.dualBoot = false`. Swapping a live machine's bootloader is not
  something a rebuild can undo; do not "fix" this to match the PC.
- **Tailscale**: `dellap` → 100.65.73.64
- **SSH in** (from the PC): `ssh dell` (tailnet) or `ssh dell-lan`
  (`192.168.1.126`), user `grajpap`, fleet key `id_ed25519_lenovo_fleet`
- **SSH out** to lenovo, `~/.ssh/config` on the dell itself:
  `ssh lenovo-user` / `ssh lenovo-user-ts` (tailnet, canonical names),
  `ssh lenovo-user-lan` / `ssh lenovo-lan` (`192.168.1.136`), key
  `id_ed25519_dell_to_lenovo`. Plain `ssh lenovo` is kept as a tailnet alias.
  Keep the canonical `lenovo-user*` names here — fleet docs and
  `fleet/status.sh` use them.

## What is different from the PC

Only what `hosts/dell/default.nix` says, plus the shared fleet options:

| Setting | PC | dell | Why |
| --- | --- | --- | --- |
| `fleet.dualBoot` | `true` | `false` | dell does not boot Windows |
| `fleet.bootloader` | `grub` (default) | `systemd-boot` | that is what is installed there |
| `fleet.heavy.enable` | `true` | `false` | no gaming, no hosting |
| `fleet.displayScale` | `100` | `125` | ~141 PPI panel, 100 is unreadable |
| `fleet.breaks` | on | `false` | the break timer nags a machine you carry |
| `fleet.calendarHeader` | on | `false` | 864 px of panel cannot spare two grid rows |
| `fleet.autostart` | on | `false` | nothing should wake a closed lid |
| `fleet.wifiRandomMac` | `true` | `false` | eduroam EAP-TTLS rejects a random MAC |

dell also does **not** import `system/desktop` (KDE Connect, the Tailscale
recovery flag), because it autostarts nothing and reaches campus wifi on its
own. Everything else — `system/wayland`, `system/core`, `theme/` and all of
`home/` — is shared through `configuration.nix`.

## Campus wifi

`eduroam` (home/scripts/eduroam) owns the NetworkManager profile rather than
Nix, because the EAP password would be lost on every rebuild. NM polkit lets the
`networkmanager` group do it unprivileged, so the script needs no sudo, and the
password goes to the session keyring instead of onto disk in clear.

```bash
eduroam            # asks for the login realm once, then reconnects
eduroam --forget   # drop the profile
```

## Was on its own branch until 2026-10-10

Between 2 and 10 October this host lived on `t3code/dell-fleet-remote-install`,
14 commits ahead of `main` and 25 behind, building a tree `main` never saw. It
is now on `main` like everything else, and `hosts/dell/` is in this repo with a
`dell` flake output.

If you find a merge that drops `dualBoot = true` from `hosts/grajpap`, or
ungates `android-studio` in `system/mobile/default.nix`, that is the same bug
in a different place: the bootloader module defaults `dualBoot` to false, and
the Android module's `heavy` gating is what keeps a second copy of a 4 GB IDE
off a laptop that only imported it for platform-tools.

The pre-merge state is still on `origin` as branch
`t3code/dell-fleet-remote-install` if anything needs to be recovered.