# nixos_config

NixOS flake for host `grajpap`, with home-manager, Hyprland, Quickshell and Stylix theme modules.

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

It checks the flake with `nom` progress, builds and switches through `nh`,
commits all repository changes, then queues the current branch push to GitHub
as a background user service.

To validate without switching or touching Git:

```bash
rebuild --check
```

The full mode stages the current tree before validation so newly added files
are part of the flake. If the working tree changes while a rebuild is running,
the switch may finish but the commit and push are skipped until the next run.

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
├── hosts/grajpap/
├── system/
├── home/
│   ├── cli/
│   ├── features/
│   ├── misc/
│   ├── rice/
│   │   ├── hyprland/
│   │   └── quickshell/
│   └── scripts/
└── theme/
```

## Hyprland and Quickshell binds

Keybinds are defined once in `home/rice/hyprland/keybinds.nix`.

`home/rice/hyprland/binds.nix` turns that model into Hyprland `bind`, `binde`, `bindm`, `bindr` and `bindl` settings.

`home/rice/quickshell/default.nix` exports the same model into `home/rice/quickshell/shell.qml`, where `Mod + /` opens the fullscreen keybind helper.

When adding a bind, update `keybinds.nix` so Hyprland and the helper stay in sync.
