{
  lib,
  config,
  ...
}: {
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "hyprlang";
    settings = {
      exec-once =
        [
          "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
          "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
          "brightnessctl set 100%"
        ]
        ++ lib.optional config.programs.foot.server.enable "foot --server";
      env = [
        "XCURSOR_THEME,catppuccin-mocha-blue-cursors"
        "XCURSOR_SIZE,24"
        "HYPRCURSOR_THEME,catppuccin-mocha-blue-cursors"
        "HYPRCURSOR_SIZE,24"
      ];
      gestures.workspace_swipe_forever = true;

      xwayland.force_zero_scaling = true;

      general = {
        gaps_in = 3;
        gaps_out = 3;
        border_size = 2;
        layout = "scrolling";
      };

      decoration = {
        rounding = 12;
        blur = {
          enabled = true;
          size = 3;
          passes = 3;
          ignore_opacity = false;
          new_optimizations = true;
          xray = true;
          contrast = 0.78;
          brightness = 0.86;
        };
      };
      input = {
        kb_layout = "pl";
      };

      plugin = [
        {
          settings = {
            mode_modifier = "row";
            scroll_amount = 1;
            scroll_wrap = true;
            focus_follows_scroll = true;
            scroll_speed = 0.1;
          };
        }
      ];

      # Hyprspace provides a draggable workspace overview. Keep it pinned to
      # the top-left edge, matching Niri's overview placement.
      "plugin:overview" = {
        panelHeight = 250;
        centerAligned = false;
        onBottom = false;
        workspaceMargin = 12;
        workspaceBorderSize = 2;
        showNewWorkspace = true;
        showEmptyWorkspace = true;
        autoDrag = true;
        exitOnClick = true;
        exitOnSwitch = true;
      };

      cursor = {
        zoom_rigid = false;
      };

      misc = {
        disable_splash_rendering = true;
        force_default_wallpaper = 0;
        disable_hyprland_logo = true;
        mouse_move_enables_dpms = true;
        key_press_enables_dpms = true;
        disable_autoreload = true;
      };

      animations = {
        enabled = true;
        bezier = [
          "nativeOut,0.16,1,0.3,1"
          "nativeIn,0.32,0,0.67,0"
          "nativePanel,0.22,1,0.36,1"
          "softOvershoot,0.34,1.18,0.64,1"
        ];
        animation = [
          "windows,1,4,nativePanel,popin 88%"
          "windowsOut,1,3,nativeIn,popin 92%"
          "border,1,8,nativeOut"
          "fade,1,7,nativeOut"
          "fadeDim,1,7,nativeOut"
          "workspaces,1,4,nativePanel,slidevert"
          "specialWorkspace,1,4,softOvershoot,slidevert"
        ];
      };

      workspace = [
        "1, monitor:DP-1, default:true"
        "2, monitor:DP-1"
        "3, monitor:DP-1"
        "4, monitor:DP-1"
        "5, monitor:DP-1"
        "m[DP-2], layoutopt:direction:down"
        "m[HDMI-A-1], layoutopt:direction:down"
        "m[DP-1], layoutopt:direction:right"
      ];
      windowgroup = [
        "social,class:signal"
        "social,class:Ferdium"
        "tools,class:Spotify"
        "tools,class:spotify"
        "tools,class:obsidian"
        "tools,class:Obsidian"
      ];
      windowrule = [
        "workspace special:social,match:class signal"
        "workspace special:social,match:class Ferdium"
        "workspace 1,match:class t3code"
        "workspace 2,match:class helium"
        "workspace special:obs,match:class obs"
        "workspace special:obs,match:class OBS"
        "workspace special:obs,match:class com.obsproject.Studio"
        "workspace special:tools,match:class Spotify"
        "workspace special:tools,match:class spotify"
        "workspace special:tools,match:class obsidian"
        "workspace special:tools,match:class Obsidian"
        "fullscreen 1,match:class guitarix"
        "fullscreen 1,match:class Guitarix"
      ];
      # Monitor config for dual displays
      monitor = [
        "DP-1,2560x1440@144,0x0,1"
        "DP-2,2560x1440@144,-1440x0,1,transform,1"
        "DP-2,addreserved,0,955,0,0"
      ];
    };
  };
}
