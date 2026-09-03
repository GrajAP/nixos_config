{
  config,
  lib,
  pkgs,
  ...
}: let
  quickshellIpc = pkgs.writeShellApplication {
    name = "quickshell-ipc";
    runtimeInputs = with pkgs; [
      coreutils
      procps
      quickshell
      systemd
    ];
    text = ''
      set -euo pipefail

      pid="$(systemctl --user show --property MainPID --value quickshell.service 2>/dev/null || true)"
      if [[ -z "$pid" || "$pid" == "0" ]]; then
        pid="$(pgrep -u "$(id -u)" -x qs | head -n1 || true)"
      fi
      if [[ -z "$pid" ]]; then
        echo "quickshell-ipc: quickshell.service is not running" >&2
        exit 1
      fi

      exec qs ipc --pid "$pid" call "$@"
    '';
  };
  ipc = "${quickshellIpc}/bin/quickshell-ipc";
  keybinds = import ./keybinds.nix {inherit config lib ipc;};

  toKeys = combo: let
    parts = lib.splitString "," combo;
    tokens = builtins.concatLists (map (p: lib.splitString " " p) parts);
    nonEmpty = builtins.filter (t: t != "") tokens;
  in
    lib.concatStringsSep " + " nonEmpty;

  dirWord = d:
    if d == "l"
    then "left"
    else if d == "r"
    then "right"
    else if d == "u"
    then "up"
    else if d == "d"
    then "down"
    else d;

  wsVal = v:
    if builtins.match "^[0-9]+$" v != null
    then builtins.fromJSON v
    else v;

  toDsp = dispatcher: let
    m = builtins.match "([^,]+),?(.*)" dispatcher;
    name = lib.trim (builtins.elemAt m 0);
    arg = lib.trim (builtins.elemAt m 1);
  in
    if name == "exec"
    then "hl.dsp.exec_cmd(${lib.generators.toLua {} arg})"
    else if name == "global"
    then "hl.dsp.global(${lib.generators.toLua {} arg})"
    else if name == "killactive"
    then "hl.dsp.window.close()"
    else if name == "togglefloating"
    then "hl.dsp.window.float({ action = \"toggle\" })"
    else if name == "fullscreen"
    then "hl.dsp.window.fullscreen({ mode = \"fullscreen\", action = \"toggle\" })"
    else if name == "movewindow"
    then
      (
        if arg == ""
        then "hl.dsp.window.drag()"
        else "hl.dsp.window.move({ direction = \"${dirWord arg}\" })"
      )
    else if name == "resizewindow"
    then "hl.dsp.window.resize()"
    else if name == "movetoworkspace"
    then "hl.dsp.window.move({ workspace = ${lib.generators.toLua {} (wsVal arg)} })"
    else if name == "movefocus"
    then "hl.dsp.focus({ direction = \"${dirWord arg}\" })"
    else if name == "resizeactive"
    then let
      parts = builtins.filter (t: t != "") (lib.splitString " " arg);
      x = builtins.fromJSON (builtins.elemAt parts 0);
      y = builtins.fromJSON (builtins.elemAt parts 1);
    in "hl.dsp.window.resize({ x = ${toString x}, y = ${toString y}, relative = true })"
    else if name == "workspace"
    then "hl.dsp.focus({ workspace = ${lib.generators.toLua {} (wsVal arg)} })"
    else "hl.dsp.exec_cmd(${lib.generators.toLua {} dispatcher})";

  toBind = entry: let
    keys = toKeys entry.combo;
    dsp = lib.generators.mkLuaInline (toDsp entry.dispatcher);
    opts =
      if entry.mode == "binde"
      then [{repeating = true;}]
      else if entry.mode == "bindl"
      then [{locked = true;}]
      else if entry.mode == "bindr"
      then [{release = true;}]
      else [];
  in {
    _args = [keys dsp] ++ opts;
  };
in {
  wayland.windowManager.hyprland.settings = {
    bind = map toBind keybinds.entries;
  };
}
