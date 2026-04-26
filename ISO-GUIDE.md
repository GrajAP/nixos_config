# Custom NixOS ISO Guide

This repo now exposes a separate ISO build that reuses your main config without depending on your installed disks.

## Build the ISO

From `/etc/nixos` run:

```bash
nix build .#grajpap-iso
```

The resulting image will appear at:

```bash
./result/iso/grajpap-live-x86_64-linux.iso
```

You can copy that ISO to a Ventoy USB stick like any other ISO file.

## What this ISO includes

- Your flake modules from this repo
- Home Manager config for `grajpap`
- Hyprland session and your user environment
- A live user named `grajpap`

## Live ISO login

- User: `grajpap`
- Password: `nixos`
- `sudo` does not require a password on the live ISO

These settings apply to the ISO only, not your installed system.

## Reinstall using this repo

After booting the ISO and mounting your target root at `/mnt`, copy the repo and install:

```bash
sudo mkdir -p /mnt/etc
sudo cp -a /etc/nixos /mnt/etc/nixos
sudo nixos-install --flake /mnt/etc/nixos#grajpap
```

## Safety note

The ISO config intentionally does not import your current hardware configuration, so it can boot independently from the already-installed system.
