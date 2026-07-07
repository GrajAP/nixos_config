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
  keybinds = import ./keybinds.nix {inherit config lib pkgs ipc;};
in {
  wayland.windowManager.hyprland.settings = {
    bind = keybinds.bind;
    bindm = keybinds.bindm;
    bindr = keybinds.bindr;
    binde = keybinds.binde;
    bindl = keybinds.bindl;
  };
}
