{
  config,
  lib,
  pkgs,
  ...
}: let
  mod = "SUPER";
  modshift = "${mod}SHIFT";
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
  # binds $mod + [shift +] {1..10} to [move to] workspace {1..10} (stolen from fufie)

  workspaces = builtins.concatLists (builtins.genList (
      x: let
        ws = let
          c = (x + 1) / 10;
        in
          toString (x + 1 - (c * 10));
      in [
        "${mod}, ${ws}, workspace, ${toString (x + 1)}"
        "${mod} SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
      ]
    )
    10);
in {
  wayland.windowManager.hyprland.settings = {
    bind =
      [
        ''${mod},RETURN,exec,foot${lib.optionalString config.programs.foot.server.enable "client"} -e sh -c 'exec tmux' ''

        "${mod},SPACE,global,quickshell:launcher"
        "${mod},F,exec,helium --profile-path=\"${config.home.homeDirectory}/.config/net.imput.helium/Default\""
        "${mod},D,exec,discord"
        "${mod},D,exec,vesktop"
        "${mod},C,killactive"

        ",XF86Bluetooth, exec, bcn"
        "${mod},T,togglegroup,"
        "${modshift},G,changegroupactive,"
        "${mod},V,togglefloating,"
        "${mod},F11,fullscreen,"

        # workspace controls

        "${modshift},h,movewindow, l"
        "${modshift},j,movetoworkspace,+1"
        "${modshift},k,movetoworkspace,-1"
        "${modshift},l,movewindow, r"

        # zoom controls
        "${modshift},mouse_down,exec,hyprctl -q keyword cursor:zoom_factor $(hyprctl getoption cursor:zoom_factor -j | jq '.float * 1.5')"
        "${modshift},mouse_up,exec,hyprctl -q keyword cursor:zoom_factor $(hyprctl getoption cursor:zoom_factor -j | jq '(.float / 1.5) | if . < 1 then 1 else . end')"

        ",Print,exec,${ipc} tools screenshotEdit"
        "${modshift},O,exec,move-special-dp2 obs"
        "${mod},Q,exec,katana-switch"

        "${mod},Period,exec, emote"
        ",PAUSE,exec,${ipc} tools voiceStart"

        "${mod},Semicolon,global,quickshell:powerMenu"

        "${mod},B,global,quickshell:toggleBar"
        "${mod},E,exec,nemo"

        "${mod},G,exec,hyprctl dispatch lockactivegroup toggle"
        "${mod},M,exec,hyprctl dispatch toggleorientation"
        "${mod},N,global,quickshell:notifications"
        "${modshift},N,exec,${ipc} notifications clear"
        "${mod},O,exec,toggle-obs-special"
        "${mod},S,exec,${ipc} tools screenshotCopy"
        "${modshift},S,exec,${ipc} tools screenshotSave"
        "${mod},U,exec,hyprctl dispatch focusurgentorlast"

        "${mod},X,global,quickshell:powerMenu"

        "${mod},A,exec,toggle-special-dp2 social"
        "${modshift},A,exec,move-special-dp2 social"
        "${mod},W,exec,toggle-special-dp2 tools"
        "${modshift},W,exec,move-special-dp2 tools"
        "${mod},Z,exec,toggle-special-dp2 scratchpad"
        "${modshift},Z,exec,move-special-dp2 scratchpad"

        "${mod},F12,exec,foot --app-id=scratchpad -e tmux"
      ]
      ++ workspaces;

    bindm = [
      "${mod},mouse:272,movewindow"
      "${mod},mouse:273,resizewindow"
    ];

    bindr = [
      ",PAUSE,exec,${ipc} tools voiceStop"
    ];

    binde = [
      "${mod},H,movefocus,l"
      "${mod},J,movefocus,d"
      "${mod},K,movefocus,u"
      "${mod},L,movefocus,r"

      #/ volume controls
      ",XF86AudioRaiseVolume, exec, pamixer -i 5 && ${ipc} osd volume"
      ",XF86AudioLowerVolume, exec, pamixer -d 5 && ${ipc} osd volume"
      ",XF86AudioMute, exec, pamixer -t && ${ipc} osd volume"
      ",XF86AudioMicMute, exec, micmute"

      ",XF86MonBrightnessUp, exec, brightnessctl set 10%+ && ${ipc} osd brightness"
      ",XF86MonBrightnessDown, exec, brightnessctl set 10%- && ${ipc} osd brightness"

      "${mod} Control_L, H, resizeactive, -80 0"
      "${mod} Control_L, J, resizeactive, 0 80"
      "${mod} Control_L, K, resizeactive, 0 -80"
      "${mod} Control_L, L, resizeactive, 80 0"
    ];

    # binds that are locked, a.k.a will activate even while an input inhibitor is active
    bindl = [
      # media controls
      ",XF86AudioPlay,exec,playerctl play-pause"
      ",XF86AudioPrev,exec,playerctl previous"
      ",XF86AudioNext,exec,playerctl next"
    ];
  };
}
