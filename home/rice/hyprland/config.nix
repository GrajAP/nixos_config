{
  lib,
  config,
  ...
}: {
  wayland.windowManager.hyprland = {
    enable = true;
    # Hyprland 0.56 requires hyprland.lua: `hyprctl reload` records
    # "cannot open hyprland.lua" when only legacy hyprland.conf exists.
    configType = "lua";
    settings = {
      # Autostart (was exec-once). The module adds no startup hook because
      # systemd.enable is false (see default.nix), so include everything here.
      on = {
        _args = [
          "hyprland.start"
          (lib.generators.mkLuaInline ''
            function()
              hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
              hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
              hl.exec_cmd("brightnessctl set 100%")
              ${lib.optionalString config.programs.foot.server.enable ''hl.exec_cmd("foot --server")''}
            end
          '')
        ];
      };
      env = [
        {
          _args = [
            "XCURSOR_THEME"
            "catppuccin-mocha-blue-cursors"
          ];
        }
        {
          _args = [
            "XCURSOR_SIZE"
            "24"
          ];
        }
        {
          _args = [
            "HYPRCURSOR_THEME"
            "catppuccin-mocha-blue-cursors"
          ];
        }
        {
          _args = [
            "HYPRCURSOR_SIZE"
            "24"
          ];
        }
      ];
      # Plain config values live under `config` and render as hl.config({...}).
      # (Stylix appends its own colors there automatically.)
      config = {
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
        gestures = {
          workspace_swipe_forever = true;
        };
        xwayland = {
          force_zero_scaling = true;
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
        };
      };
      curve = [
        {
          _args = [
            "nativeOut"
            {
              type = "bezier";
              points = [
                [
                  0.16
                  1
                ]
                [
                  0.3
                  1
                ]
              ];
            }
          ];
        }
        {
          _args = [
            "nativeIn"
            {
              type = "bezier";
              points = [
                [
                  0.32
                  0
                ]
                [
                  0.67
                  0
                ]
              ];
            }
          ];
        }
        {
          _args = [
            "nativePanel"
            {
              type = "bezier";
              points = [
                [
                  0.22
                  1
                ]
                [
                  0.36
                  1
                ]
              ];
            }
          ];
        }
        {
          _args = [
            "softOvershoot"
            {
              type = "bezier";
              points = [
                [
                  0.34
                  1.18
                ]
                [
                  0.64
                  1
                ]
              ];
            }
          ];
        }
      ];
      animation = [
        {
          leaf = "windows";
          enabled = true;
          speed = 4;
          bezier = "nativePanel";
          style = "popin 88%";
        }
        {
          leaf = "windowsOut";
          enabled = true;
          speed = 3;
          bezier = "nativeIn";
          style = "popin 92%";
        }
        {
          leaf = "border";
          enabled = true;
          speed = 8;
          bezier = "nativeOut";
        }
        {
          leaf = "fade";
          enabled = true;
          speed = 7;
          bezier = "nativeOut";
        }
        {
          leaf = "fadeDim";
          enabled = true;
          speed = 7;
          bezier = "nativeOut";
        }
        {
          leaf = "workspaces";
          enabled = true;
          speed = 4;
          bezier = "nativePanel";
          style = "slidevert";
        }
        {
          leaf = "specialWorkspace";
          enabled = true;
          speed = 4;
          bezier = "softOvershoot";
          style = "slidevert";
        }
      ];
      monitor = [
        {
          output = "DP-1";
          mode = "2560x1440@144";
          position = "0x0";
          scale = 1;
        }
        {
          output = "DP-2";
          mode = "2560x1440@144";
          position = "-1440x0";
          scale = 1;
          transform = 1;
        }
        {
          output = "DP-2";
          reserved = {
            top = 0;
            bottom = 955;
            left = 0;
            right = 0;
          };
        }
      ];
      workspace_rule = [
        {
          workspace = "1";
          monitor = "DP-1";
          default = true;
        }
        {
          workspace = "2";
          monitor = "DP-1";
        }
        {
          workspace = "3";
          monitor = "DP-1";
        }
        {
          workspace = "4";
          monitor = "DP-1";
        }
        {
          workspace = "5";
          monitor = "DP-1";
        }
        {
          workspace = "m[DP-2]";
          layout_opts = {
            direction = "down";
          };
        }
        {
          workspace = "m[HDMI-A-1]";
          layout_opts = {
            direction = "down";
          };
        }
        {
          workspace = "m[DP-1]";
          layout_opts = {
            direction = "right";
          };
        }
      ];
      # NOTE: hyprlang `windowgroup` lines have no Lua equivalent for named
      # auto-groups. Windows still auto-move to the special workspaces via
      # the rules below; only tab-grouping was dropped.
      # NOTE: the old `plugin { settings ... }` block is dropped: no plugin
      # is loaded (plugins = []), so those scrolling keys were inert.
      window_rule = [
        {
          match = {
            class = "signal";
          };
          workspace = "special:social";
        }
        {
          match = {
            class = "Ferdium";
          };
          workspace = "special:social";
        }
        {
          match = {
            class = "t3code";
          };
          workspace = "1";
        }
        {
          match = {
            class = "helium";
          };
          workspace = "2";
        }
        {
          match = {
            class = "obs";
          };
          workspace = "special:obs";
        }
        {
          match = {
            class = "OBS";
          };
          workspace = "special:obs";
        }
        {
          match = {
            class = "com.obsproject.Studio";
          };
          workspace = "special:obs";
        }
        {
          match = {
            class = "Spotify";
          };
          workspace = "special:tools";
        }
        {
          match = {
            class = "spotify";
          };
          workspace = "special:tools";
        }
        {
          match = {
            class = "obsidian";
          };
          workspace = "special:tools";
        }
        {
          match = {
            class = "Obsidian";
          };
          workspace = "special:tools";
        }
        {
          match = {
            class = "guitarix";
          };
          fullscreen = true;
        }
        {
          match = {
            class = "Guitarix";
          };
          fullscreen = true;
        }
        {
          match = {
            title = "^deadlocked_overlay$";
          };
          no_blur = true;
        }
      ];
      # Monitor config for dual displays
    };
  };
}
