{
  lib,
  config,
  ...
}: {
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      exec-once = [
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        "brightnessctl set 100%"
        "${lib.optionalString config.programs.foot.server.enable "foot --server"}"
        "signal-desktop"
        "ferdium"
        "spotify --disable-gpu &"
        "find ~/.config/obsidian -maxdepth 1 -type f -name 'obsidian-*.asar' -delete"
        "launch-obsidian-tools"
        "helium"
        "auto-dnd"
      ];

      gestures.workspace_swipe_forever = true;

      xwayland.force_zero_scaling = true;

      general = {
        gaps_in = 3;
        gaps_out = 6;
        border_size = 2;
        layout = "scrolling";
      };

      master = {
        mfact = "0.6i";
      };

      decoration = {
        rounding = 8;
        blur = {
          enabled = true;
          size = 3;
          passes = 3;
          ignore_opacity = false;
          new_optimizations = true;
          xray = true;
          contrast = 0.7;
          brightness = 0.8;
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

      misc = {
        disable_splash_rendering = true;
        force_default_wallpaper = 0;
        disable_hyprland_logo = true;
        vfr = true;
        mouse_move_enables_dpms = true;
        key_press_enables_dpms = true;
        disable_autoreload = true;
      };

      # Hypridle settings
      # See https://github.com/hyprwm/hypridle

      animations.enabled = true;
      animations.bezier = [
        "smoothOut,0.36,0,0.66,-0.56"
        "smoothIn,0.25,1,0.5,1"
        "overshot,0.4,0.8,0.2,1.2"
      ];
      animations.animation = [
        "windows,1,4,overshot,slide"
        "windowsOut,1,4,smoothOut,slide"
        "border,1,10,default"
        "fade,1,10,smoothIn"
        "fadeDim,1,10,smoothIn"
        "workspaces,1,4,overshot,slidevert"
      ];

      dwindle = {
        pseudotile = false;
        preserve_split = "yes";
      };
      "$kw" = "dwindle:no_gaps_when_only";
      workspace = [
        "1, monitor:DP-1, default:true"
        "2, monitor:DP-1"
        "3, monitor:DP-1"
        "4, monitor:DP-1"
        "5, monitor:DP-1"
        "6, monitor:DP-2, default:true"
        "7, monitor:DP-2"
        "8, monitor:DP-2"
        "9, monitor:DP-2"
        "10, monitor:DP-2"
        "m[DP-2], layoutopt:direction:down"
        "m[DP-2], layoutopt:direction:down"
        "m[DP-1], layoutopt:direction:right"
        "special:social, monitor:DP-2"
        "special:obs, monitor:DP-2"
        "special:tools, monitor:DP-2"
        "special:scratchpad, monitor:DP-2"
      ];
      windowgroup = [
        "social,class:discord"
        "social,class:signal"
        "social,class:Ferdium"
        "tools,class:Spotify"
        "tools,class:spotify"
        "tools,class:obsidian"
        "tools,class:Obsidian"
      ];
      windowrule = [
        "workspace special:social,match:class discord"
        "workspace special:social,match:class signal"
        "workspace special:social,match:class Ferdium"
        "workspace special:obs,match:class obs"
        "workspace special:obs,match:class OBS"
        "workspace special:obs,match:class com.obsproject.Studio"
        "workspace special:tools,match:class Spotify"
        "workspace special:tools,match:class spotify"
        "workspace special:tools,match:class obsidian"
        "workspace special:tools,match:class Obsidian"
      ];
      # windowrulev2 = [
      #   "float,title:^(Whispr Flow)$"
      #   "center,title:^(Whispr Flow)$"
      #   "noborder,title:^(Whispr Flow)$"
      #   "noshadow,title:^(Whispr Flow)$"
      #   "stayfocused,title:^(Whispr Flow)$"
      # ];
      # Monitor config for dual displays
      monitor = [
        "DP-1,2560x1440@144,0x0,1"
        "DP-2,2560x1440@144,-1440x0,1,transform,1"
        "DP-2,addreserved,0,955,0,0"
      ];
    };
  };
}
