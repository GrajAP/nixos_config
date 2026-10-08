# lenovo — 24/7 laptop server

ThinkPad-class Haswell laptop, lid permanently closed, running headless.

- **Flake attr**: `nixosConfigurations.lenovo`
- **nixpkgs**: `nixpkgs-stable` (25.11); rolling packages come from
  `specialArgs.unstablePkgs` (the root `nixpkgs` unstable input)
- **stateVersion**: `25.11`
- **Config**: `hosts/lenovo/` — `configuration.nix` + one module per concern
- **No home-manager** on this host (headless; agent skills are shipped via the
  project `.opencode/skills/` symlink instead of `home/agents/default.nix`)

## Access

```bash
ssh lenovo-user        # LAN  192.168.1.136, user grajpap
ssh lenovo-user-ts     # tailnet (MagicDNS: lenovo, 100.110.204.8)
sudo -i                # NOPASSWD, no password prompt
```

Root SSH is disabled. Do not use the `Host lenovo` / `Host lenovo-ts`
aliases in `~/.ssh/config` — they still say `User root` and fail; they will
be corrected to `User grajpap`.

## Services

- **HomeNest** production app (Docker, Caddy on :80, systemd secrets unit)
- **Nextcloud** under `/nextcloud` behind the same Caddy (own nginx on loopback)
- **restic** backups + sqlite-safe snapshotting (see `modules/backup.nix`)
- **Tailscale** (unstable channel package) — admin path, `tailscale-serve`
  publishes HTTPS on the tailnet
- **monitoring**: smartd + alerting; **TLP/thermald** power management

## WiFi (PWr eduroam)

The internal Broadcom BCM43142 (`pci 14e4:4365`) has no in-tree driver, so
`hosts/lenovo/modules/wifi.nix` does three things: adds `broadcom-sta` (`wl`,
unfree + insecure, gated by a targeted `nixpkgs.config.allowInsecurePredicate`),
blacklists `b43`/`bcma`, and declares an NM `ensureProfiles` keyfile for
eduroam — EAP-TTLS / phase2 PAP, anonymous identity `anonymous@pwr.edu.pl`,
server `rad01.pwr.edu.pl`, CA chain in `modules/eduroam-ca.pem`
(GEANT TLS RSA 1 + HARICA TLS RSA Root CA 2021).

Credentials are **not** in the repo. As root, before the first trip to PWR:

```bash
sudo tee /var/lib/eduroam/eduroam.env >/dev/null <<'EOF'
EDUROAM_IDENTITY=<login>@pwr.edu.pl
EDUROAM_PASSWORD=<haslo>
EOF
sudo chmod 600 /var/lib/eduroam/eduroam.env
sudo systemctl restart NetworkManager-ensure-profiles
nmcli connection show eduroam
```

The empty placeholders are intentional: NetworkManager refuses the profile
(`802-1x.identity: property is empty`) until both values are set, so nothing
half-configured is ever loaded. The profile template and CA are in the system
closure; the env file lives only in `/var/lib/eduroam/`.

`wl` is built for the currently deployed kernel (6.12.93) while the box still
runs 6.12.78 since its last boot, so **reboot once** (`sudo reboot`) after the
switch — `systemd-modules-load` resolves modules through
`/run/booted-system/kernel-modules/lib/modules/$(uname -r)`, which only
contains `wl.ko` from the new generation onward. Then check
`modinfo wl` and `nmcli device status` for the new wlan interface.

## Rebuild

```bash
rebuild          # on lenovo — switches #lenovo, commits, pushes (origin may be absent)
rebuild --check  # from any host: whole-fleet flake checks
```

The laptop's old standalone repo had **no git remote**. After cutover this
checkout is a clone of the fleet repo; `rebuild` skips push cleanly when no
GitHub origin exists. `gh auth setup-git` was run on the laptop so pushes work
once an origin is configured.

## Migration state

The legacy laptop repo was backed up before cutover
(`~/lenovo-nixos-legacy.bundle` + WIP tarball). Its uncommitted WIP
(`configuration.nix` edits, `modules/nextcloud.nix`) was carried into
`hosts/lenovo/`.
