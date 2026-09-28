# Pixel 9a — personal phone

Google Pixel 9a, Tailscale client.

- **Tailscale**: `grajpap-9a` (100.106.96.44) — typically online
- **adb**: available when docked (USB) to a host with `adb` installed
- **Not NixOS** — no config in this repo beyond docs

## adb

```bash
adb devices -l
```

Unlock the phone and accept the RSA prompt on first connect to a new host.
Unlike the POCO (Xiaomi, always the same vendor id on the laptop), the Pixel
is docked ad hoc — run `adb devices` on the machine it is plugged into.
