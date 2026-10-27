# POCO X4 Pro 5G: adb test phone

- Not NixOS. adb config lives in `system/mobile/adb.nix` (fleet-wide udev rule).
- USB: tethered to Lenovo. Tailscale peer `poco-x4-pro-5g` at `100.110.155.84`.
- Lenovo keeps Android's ADB TCP listener on port 5555 enabled. A systemd timer
  restores it after a POCO reboot, using the already-authorized USB connection.
- Tailscale is configured as Android's always-on VPN with lockdown, so the phone
  returns to the tailnet after reconnecting to Wi-Fi/mobile data.
- T3 Code on lenovo can drive the phone directly: the USB adb transport plus the
  SDK tree from `hosts/lenovo/modules/t3-devices.nix` (`t3-devices.nix`) make the
  POCO show up in T3's Devices panel. First agent use installs T3's device tools
  into `~/.t3/tools` on lenovo; no native emulator runs there, only the phone.
- From grajpap, Lenovo, or Dell after switching its NixOS configuration, run
  the `connect-poco` command. On a desktop it opens scrcpy; on headless Lenovo
  it connects ADB and prints the desktop command. The first connection from
  each computer needs one-time RSA authorization on the phone.
- Authorize each new computer's ADB RSA key on the POCO once. Keep the phone
  online and USB-tethered to Lenovo so Lenovo can restore TCP mode after reboots.
- If USB access breaks on Lenovo, check `adb devices -l`; reload udev rules and
  replug only if the POCO reports `no permissions`.
