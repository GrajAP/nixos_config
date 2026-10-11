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

## Audit 2026-10-11

Power, disk and health audit after 15d20h uptime. RAPL (`/sys/class/powercap`)
measured the CPU package at **2.3–4.5 W** (avg ~3.5 W) at 14.5% average CPU
busy; full-system wall draw is **~10–15 W**, estimated at **~4.6 kWh** since the
boot, ~5 zł. There is no wall meter on this box and the battery is dead, so
nothing here is a metered figure — it is RAPL plus a model.

Corrected earlier assumptions:

- The battery (`BAT0`) is effectively gone: 3.86 V against 14.88 V design,
  `capacity=0`, `energy_now=0`. TLP's 50/80 charge thresholds have nothing to
  act on, and **there is no power-cut buffer** — the box dies instantly.
- The discrete **GeForce 820M is not a power problem**: `nouveau` binds it, but
  `/sys/bus/pci/devices/0000:03:00.0/power/runtime_status` is `suspended` and
  stays there. An earlier single reading showed `active`; that was a transient.
  The repeated `nouveau: MMIO write ... FAULT at PRIVRING` lines in the journal
  are probe noise, not a blocked suspend. Do not blacklist the module on the
  assumption that it saves watts — removing the driver takes runtime PM with it.
- i915 (`00:02.0`) sits at `power/control=on`, `runtime_status=active`. With the
  lid closed and the panel blanked that is <1 W; not worth destabilising.

The CPU package is only part of the bill. `opencode.exe` + `node` + `esbuild` +
`cloudflared` accounted for **28.7 CPU-hours, 39% of all CPU time** since the
boot. Until the agent stops idling on this box, the machine cannot reach idle.

### Disk

`/` hit **92% (18G free)**. Two causes, both fixed:

- `nix-store-gc` had been failing every night since the Nix 2.31 migration —
  `--max-free-space` no longer exists in `nix-collect-garbage`. It now only
  passes `--delete-older-than 14d`; the free-space floor is `min-free = "10G"`
  in `modules/boot.nix`. The timer is daily, not weekly.
- Agent scratch: `~/.t3/worktrees` held 34G of stale T3 Code worktrees and
  `/tmp/opencode` 13G. `agent-scratch-prune.service` (daily, 03:40) now prunes
  both, age-gated at 7 days, skipping anything any process has open. Worktrees
  go through `git worktree remove` **without `--force`**, so a tree with
  uncommitted changes is never touched.

`disk-space-check` was alert-only. It now warns at 85% and *reclaims* at 92%
by starting both jobs and reporting what was freed; the timer runs every 4h.

Result: 190G used / 92% → **106G used / 51%**.

`~/.t3/worktrees/kilometr/t3code-e141a3f4` was **kept on purpose** — it has
three uncommitted files (`.github/workflows/build-apk.yml`, `LiveTripPlan.kt`,
`LiveUpdateFactory`). Everything else in that project was clean, committed to
branches in `/home/grajpap/dev/kilometr`, and removed.

### Power settings

`power.cpuMitigations = false` is set in `configuration.nix` (PTI, retpolines,
IBPB, RDT off). Requires a reboot; **not yet applied to the running kernel**.

### Known cosmetic

Nextcloud logs `files_trashbin/trashbin_size is stored as integer but was
requested as string` and `NoteDoesNotExistException` from the Notes app on
delete. Harmless, noisy.

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
