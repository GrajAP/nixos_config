# POCO X4 Pro 5G — adb test phone

Xiaomi POCO X4 Pro 5G used for adb testing of mobile-facing work.

- **USB**: tethered to the **laptop** (lenovo), not the PC
- **Tailscale**: `poco-x4-pro-5g` (100.110.155.84) — usually offline unless the
  phone is on Wi-Fi with Tailscale up; USB is the reliable path
- **Not NixOS**: the only fleet-repo footprint is the fleet-wide adb config in
  `system/mobile/adb.nix`

## adb from the laptop

```bash
adb devices -l
```

adb is fleet-wide, configured in `system/mobile/adb.nix` and imported by
every host (lenovo, grajpap, dell), so the same thing works wherever the
phone is plugged in.

Two details that make it work on this box, which is headless and driven over
SSH:

1. `programs.adb.enable` is **not** set. It is package-only on 25.11 and
   removed outright in nixpkgs >= 26.05, and the desktops are on unstable —
   the shared module installs `pkgs.android-tools` instead.
2. Non-root SSH sessions never get `uaccess` ACLs, so the rule grants
   `MODE="0660", GROUP="adbusers"` on Xiaomi USB (`idVendor=="2717"`)
   instead. `grajpap` is in `adbusers` on every host.

If the device shows up as `????????????` or `no permissions`, the rule is not
active — re-plug after `sudo udevadm control --reload-rules && sudo udevadm
trigger`, or re-run `rebuild`.
