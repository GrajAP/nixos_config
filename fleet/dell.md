# dell: laptop, uni notes

- What: same desktop as `grajpap`, minus `fleet.heavy` extras, battery-first, Android tooling included
- Config: `hosts/dell/`, same unstable nixpkgs as the PC
- IP: `192.168.1.126` LAN, `100.65.73.64` tailnet
- SSH in: `ssh dell` (tailnet) / `ssh dell-lan`, user `grajpap`
- Rebuild: `./rebuild.sh`

## Notes

- systemd-boot, single boot: `fleet.bootloader = "systemd-boot"`, do not copy the PC's GRUB setup here.
- Campus eduroam: run `eduroam` (home/scripts/eduroam) once, it owns the NetworkManager profile outside Nix.
- Per-host `fleet.*` settings are declared in `hosts/dell/default.nix`, see that file, not a doc table.
