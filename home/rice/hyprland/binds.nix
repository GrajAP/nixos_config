{
  config,
  lib,
  ...
}: let
  mod = "SUPER";
  modshift = "${mod}SHIFT";
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

        "${mod},SPACE,exec,launcher"
        "${mod},F,exec,helium"
        "${mod},D,exec,discord"
        "${mod},C,killactive"

        ",XF86Bluetooth, exec, bcn"
        "${mod},T,togglegroup,"
        "${modshift},G,changegroupactive,"
        "${mod},V,togglefloating,"
        "${mod},F10,exec,toggle-notifications"
        "${mod},F11,fullscreen,"

        # workspace controls

        "${modshift},h,movewindow, l"
        "${modshift},j,movetoworkspace,+1"
        "${modshift},k,movetoworkspace,-1"
        "${modshift},l,movewindow, r"

        "${mod},mouse_down,workspace,e+1"
        "${mod},mouse_up,workspace,e-1"

        ",Print,exec, pauseshot"
        ",Print,exec, grim - | wl-copy"
        "${modshift},O,exec,move-special-dp2 obs"
        "${mod},Q,exec,katana-switch"

        "${mod},Period,exec, emote"
        ",PAUSE,exec,whisper-record-v2 start"

        "${mod},Semicolon,exec,wlogout"
        "${modshift},slash,exec,hypr-cheatsheet"

        # new keybindings
        "${mod},B,exec,pkill -SIGUSR1 waybar"
        "${mod},E,exec,nemo"

        "${mod},G,exec,hyprctl dispatch lockactivegroup toggle"
        "${mod},M,exec,hyprctl dispatch toggleorientation"
        "${mod},N,exec,makoctl restore"
        "${modshift},N,exec,makoctl dismiss -a"
        "${mod},O,exec,toggle-obs-special"
        "${mod},S,exec,grimblast copy area"
        "${modshift},S,exec,grimblast save area ~/pics/$(date +'screenshot-%F-%H%M%S').png"
        "${mod},U,exec,hyprctl dispatch focusurgentorlast"

        "${mod},X,exec,wlogout"

        #special workspaces
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
      ",PAUSE,exec,whisper-record-v2 stop"
    ];

    binde = [
      "${mod},H,movefocus,l"
      "${mod},J,movefocus,d"
      "${mod},K,movefocus,u"
      "${mod},L,movefocus,r"

      #/ volume controls
      ",XF86AudioRaiseVolume, exec, pamixer -i 5"
      ",XF86AudioLowerVolume, exec, pamixer -d 5"
      ",XF86AudioMute, exec, pamixer -t"
      ",XF86AudioMicMute, exec, micmute"

      ",XF86MonBrightnessUp, exec, brightnessctl set 10%+"
      ",XF86MonBrightnessDown, exec, brightnessctl set 10%-"

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
