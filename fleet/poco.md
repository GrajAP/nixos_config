# POCO X4 Pro 5G — adb test phone

Xiaomi POCO X4 Pro 5G used for adb testing of mobile-facing work.

- **USB**: tethered to the **laptop** (lenovo), not the PC
- **Tailscale**: `poco-x4-pro-5g` (100.110.155.84) — usually offline unless the
  phone is on Wi-Fi with Tailscale up; USB is the reliable path
- **Not NixOS**: the only fleet-repo footprint is the udev/adb config on lenovo

## adb from the laptop

```bash
adb devices -l
```

Non-root SSH sessions never get `uaccess` ACLs, so the usual
`services.udev.extraRules` uaccess route does not work headless over SSH.
`hosts/lenovo/modules/mobile.nix` therefore:

1. sets `programs.adb.enable` (package only — the option was removed from
   newer nixpkgs; 25.11 still has it)
2. adds a udev rule granting `MODE="0666"` to Xiaomi USB (`idVendor=="2717"`)

If the device shows up as `????????????` or `no permissions`, the rule is not
active — re-plug after `sudo udevadm control --reload-rules && sudo udevadm
trigger`, or re-run `rebuild` on lenovo.
