# nixos_config

One NixOS flake for the whole fleet: host `grajpap` (PC, unstable, desktop +
heavy extras + hosting), host `lenovo` (24/7 headless laptop server, 25.11
stable) and — pending — host `dell` (day-to-day uni laptop, same desktop as
the PC minus heavy stuff). Device inventory docs live under `fleet/`.
The PC has home-manager, Hyprland, Quickshell and Stylix theme
modules; the laptop is headless.

## Daily workflow

Work from `main` only for clean, already validated state.

```bash
git switch main
git pull --ff-only
git switch -c feature/name
```

Before editing, check the tree:

```bash
git status --short --branch
```

For the normal user workflow, run one command:

```bash
rebuild
```

It checks the flake with `nom` progress, builds and switches `#$(hostname)`
(so each host rebuilds itself), commits all repository changes, then queues the
current branch push to GitHub as a background user service when a GitHub origin
exists. When executed from sandboxed environments like
T3 Code where `NoNewPrivs` is active, `rebuild` transparently delegates `sudo`
to the host session via `systemd-run`.

To validate without switching or touching Git:

```bash
rebuild --check
```

To validate and build the system without switching (rootless):

```bash
rebuild --build
```

The full mode stages the current tree before validation, and validates the flake
as `path:$repo`, so newly added files are part of both the checks and the
switch. If the working tree changes while a rebuild is running, the switch may
finish but the commit and push are skipped until the next run.

Agents and scoped manual work should still review and commit only the intended
files after the active generation has been verified:

```bash
git add path/to/changed-file
git commit -m "Describe the change"
git switch main
git merge --ff-only feature/name
git push origin main
```

Do not merge a branch into `main` until checks, build and the root-owned switch
service pass. This keeps the active system and `main` aligned. `rebuild` does
not format files, update flake inputs or clean generations.

## Unattended updates

Each host also updates itself once a day from the same repo, driven by
`auto-rebuild.timer` → `fleet/auto-rebuild`:

| Host | Time | Behaviour |
| --- | --- | --- |
| `lenovo` | 04:40 + up to 20 min | `switch` — activates immediately |
| `grajpap` | 05:20 + up to 2 h | `switch`, but skipped while a graphical session is logged in |

The run pulls `main`, runs the lint checks, commits anything authored locally,
switches, checks that `tailscaled` (plus `sshd` and `caddy` on `lenovo`) came
back, and only then publishes:

- changes that arrived from GitHub are **not** pushed back — otherwise every
  host re-pushes the others' commits at each other;
- commits this host authored **are** pushed, including ones you made by hand.

If a critical unit is not active after the switch, the run rolls the system
back by itself. A failing check warns instead of aborting, so an unformatted
file on `main` cannot silently freeze a host's updates; a broken configuration
is still refused by the evaluator. Watch it with:

```bash
journalctl -u auto-rebuild.service -e
systemctl list-timers auto-rebuild.timer
```

Both the unattended run and an interactive `rebuild` build the flake as
`path:/etc/nixos`, so an edit is validated and switched in on the run that made
it. A bare `$repo#attr` reference resolves to a git repository, which nix
evaluates from `HEAD` -- a staged or edited file would be invisible to both the
checks and the switch. The unattended run commits *before* switching so the
generation that goes live and the commit that may be pushed describe the same
tree; an interactive `rebuild` commits straight after a clean switch.

## Required validation

`rebuild --check` is the local read-only validation command. It runs:

```bash
nix flake check
```

The default `rebuild` continues with the NixOS build and activation through the
passwordless `nh` wrapper and the root-owned service. The explicit agent path is:

```bash
nix build .#nixosConfigurations.grajpap.config.system.build.toplevel
systemctl start t3code-os-switch.service
```

Do not use `sudo` or call `switch-to-configuration` directly. If validation
fails, fix the config before activating or merging.

## Project structure

```text
.
├── flake.nix
├── configuration.nix
├── hosts/
│   ├── grajpap/
│   └── lenovo/
├── fleet/
├── system/
├── home/
├── apps/
└── theme/
```
