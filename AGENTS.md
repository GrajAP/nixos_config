This is a NixOS machine.

Edit files under /etc/nixos, then run:

```bash
nix flake check
nix build .#nixosConfigurations.grajpap.config.system.build.toplevel
systemctl start t3code-os-switch.service
```

This is the passwordless agent path. The root-owned service runs the checks,
builds the candidate generation as `grajpap`, validates its store path, and
then activates it. Do not use `sudo`, embed a password, or call
`switch-to-configuration` directly.

`./rebuild.sh` is the user-facing helper. Without arguments it validates,
switches, stages all changes, commits them and queues a background GitHub push
for the current branch. `./rebuild.sh --check` only validates the flake.
If the tree changes during a full rebuild, it skips the commit and push.
Agents doing scoped work should use the explicit validation and switch commands
above so they do not commit unrelated user changes. The helper never formats,
updates flake inputs or cleans generations.

## Git workflow

- Keep `main` clean and deployable. Do feature work on a new branch, then merge back to `main` only after validation.
- Before editing, run `git status --short --branch` and understand any existing changes. Do not revert user changes unless explicitly asked.
- Keep changes scoped. Avoid mixing unrelated cleanup, UI work, package updates, and host changes in one commit unless the user asked for one combined cleanup.
- After finishing a coherent change, commit it with a clear message. Future feature work should start from `main` on a fresh branch.

## Validation before switching

Run checks before starting `t3code-os-switch.service` so broken config never becomes the active system:

1. `nix flake check`
2. `nix build .#nixosConfigurations.grajpap.config.system.build.toplevel`
3. `systemctl start t3code-os-switch.service`

If a check fails, fix the config first. Do not switch a known broken generation.

## Quickshell and Hyprland binds

- Hyprland keybinds live in `home/rice/hyprland/keybinds.nix`.
- `home/rice/hyprland/binds.nix` consumes that model for Hyprland.
- `home/rice/quickshell/default.nix` exports the same model into `shell.qml` for the fullscreen keybind helper.
- When adding or changing a bind, update `keybinds.nix` only unless the QML UI itself needs new behavior.
