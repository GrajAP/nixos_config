# POCO X4 Pro 5G: adb test phone

- Not NixOS. adb config lives in `system/mobile/adb.nix` (fleet-wide udev rule).
- USB: tethered to lenovo. Tailscale `poco-x4-pro-5g`, usually offline.
- Use: `adb devices -l` on the connected host. If `no permissions`, re-plug after `sudo udevadm control --reload-rules`.
