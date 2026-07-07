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

After a coherent change:

```bash
nix flake check
nix build .#nixosConfigurations.grajpap.config.system.build.toplevel
nh os switch
git status --short
git add .
git commit -m "Describe the change"
git switch main
git merge --ff-only feature/name
```

Do not merge a branch into `main` until the checks and `nh os switch` pass. This keeps the active system and `main` aligned.

## Required validation

Run these before switching or merging:

```bash
nix flake check
nix build .#nixosConfigurations.grajpap.config.system.build.toplevel
nh os switch
```

If one of these fails, fix it before continuing. The goal is that the repository never knowingly contains a broken deployable configuration.

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
