# Pixel 9a: personal phone

- Not NixOS. adb works when USB-docked to any fleet host (`system/mobile/adb.nix`, Google vendor rule).
- Tailscale: `grajpap-9a`, 100.106.96.44, typically online.
- Use: `adb devices -l` on the docked machine, accept the RSA prompt once.
