# NixOS fleet repo

Hosts, devices and per-host profiles: load the `fleet` skill. Layout: `README.md`.

## Rules

- Check before claiming done: `./rebuild.sh --check` (alejandra, statix, deadnix, shellcheck, no-dashes).
- Use `./rebuild.sh --build` to also build without switching.
- Never call `switch-to-configuration` directly and never embed a password.
- Plain `./rebuild.sh` switches, commits everything with `git add -A` and pushes. Do not run it unless I ask.
- New files must be tracked or built through `path:/etc/nixos`: git flakes only see tracked files.
- Format Nix with `alejandra`.
- lenovo has no home-manager: its config is `hosts/lenovo/`, one module per concern.
