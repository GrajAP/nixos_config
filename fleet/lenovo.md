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
