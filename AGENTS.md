This is a NixOS machine.

Edit files under /etc/nos, then run:

```bash
./rebuild.sh
```

This validates the flake, switches the system, stages all changes, commits them
and queues a background GitHub push for the current branch. Use
`./rebuild.sh --check` to only validate the flake without switching.

Do not use `sudo`, embed a password, or call `switch-to-configuration` directly.

## CRITICAL: DO NOT OVERTHINK

- Do NOT explain what you are about to do. Just do it.
- Do NOT list steps, create plans, or describe your approach.
- Do NOT think about edge cases before acting.
- Do NOT ask clarifying questions if the request is clear.
- Do NOT spend more than 2 tool calls planning.
- Start writing code or editing files IMMEDIATELY after reading the request.
- If a task is simple (create a file, edit a line, run a command), do it in ONE tool call.
- Stop talking. Start working.

## Git workflow

- Keep `main` clean and deployable. Do feature work on a new branch, then merge back to `main` only after validation.
- Before editing, run `git status --short --branch` and understand any existing changes. Do not revert user changes unless explicitly asked.
- Keep changes scoped. Avoid mixing unrelated cleanup, UI work, package updates, and host changes in one commit unless the user asked for one combined cleanup.
- After finishing a coherent change, commit it with a clear message. Future feature work should start from `main` on a fresh branch.

## Validation before switching

Run `./rebuild.sh` to validate the flake, switch, commit, and push.
Use `./rebuild.sh --check` to only validate without switching.

If a check fails, fix the config first. Do not switch a known broken generation.

## Quickshell and Hyprland binds

- Hyprland keybinds live in `home/rice/hyprland/keybinds.nix`.
- `home/rice/hyprland/binds.nix` consumes that model for Hyprland.
- `home/rice/quickshell/default.nix` exports the same model into `shell.qml` for the fullscreen keybind helper.
- When adding or changing a bind, update `keybinds.nix` only unless the QML UI itself needs new behavior.
