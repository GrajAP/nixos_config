{
  config,
  pkgs,
  lib,
  inputs,
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
  autoShutdown = pkgs.writeShellApplication {
    name = "auto-shutdown";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      libnotify
      systemd
    ];
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      default_targets="00:00 01:00 02:00 03:00 04:00 05:00 06:00"
      watch_seconds=$((5 * 60))
      poll_seconds=60

      runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$UID}/auto-shutdown"
      cancel_file="$runtime_dir/cancel"
      custom_deadline_file="$runtime_dir/custom-deadline"
      last_trigger_file="$runtime_dir/last-trigger"
      pending_file="$runtime_dir/pending"
      pending_deadline_file="$runtime_dir/pending-deadline"
      mkdir -p "$runtime_dir"
      rm -f "$runtime_dir/custom-target"

      should_trigger() {
        local now_minute="$1"
        local target
        for target in $default_targets; do
          if [[ "$now_minute" == "$target" ]]; then
            return 0
          fi
        done
        return 1
      }

      read_deadline() {
        if [[ -r "$custom_deadline_file" ]]; then
          head -n1 "$custom_deadline_file" | awk '/^[0-9]+$/ { print; exit }'
        fi
      }

      handle_custom_deadline() {
        local deadline now remaining label
        deadline="$(read_deadline)"
        if [[ -z "$deadline" ]]; then
          return 1
        fi

        now="$(date +%s)"
        if [ -f "$cancel_file" ]; then
          rm -f "$cancel_file" "$custom_deadline_file" "$pending_file" "$pending_deadline_file"
          notify-send -u normal -t 2500 "Auto shutdown" "Shutdown timer cancelled."
          return 0
        fi

        if (( now < deadline )); then
          remaining=$((deadline - now))
          label="in $(( (remaining + 59) / 60 )) min"
          printf '%s\n' "$label" > "$pending_file"
          printf '%s\n' "$deadline" > "$pending_deadline_file"
          return 0
        fi

        rm -f "$custom_deadline_file" "$pending_file" "$pending_deadline_file"
        notify-send -u critical -t 3000 "Auto shutdown" "Powering off now."
        systemctl poweroff
        exit 0
      }

      while true; do
        handle_custom_deadline && { sleep 1; continue; }

        today="$(date +%F)"
        now_minute="$(date +%H:%M)"
        trigger_id="$today $now_minute"

        if should_trigger "$now_minute" && [[ "$(cat "$last_trigger_file" 2>/dev/null || true)" != "$trigger_id" ]]; then
          printf '%s\n' "$trigger_id" > "$last_trigger_file"
          printf '%s\n' "$now_minute" > "$pending_file"
          deadline=$(( $(date +%s) + watch_seconds ))
          printf '%s\n' "$deadline" > "$pending_deadline_file"
          rm -f "$cancel_file"
          notify-send -u critical -t $((watch_seconds * 1000)) \
            "Auto shutdown" \
            "System will power off in 5 minutes. Open the shutdown widget to cancel."

          cancel=0
          while (( $(date +%s) < deadline )); do
            if [ -f "$cancel_file" ]; then
              cancel=1
              rm -f "$cancel_file"
              break
            fi
            sleep 1
          done

          rm -f "$pending_file" "$pending_deadline_file"

          if (( cancel == 0 )); then
            notify-send -u critical -t 3000 "Auto shutdown" "Powering off now."
            systemctl poweroff
            exit 0
          fi

          notify-send -u normal -t 2500 "Auto shutdown" "Shutdown cancelled."
        fi

        sleep "$poll_seconds"
      done
    '';
  };
  ensureDp2Monitor = pkgs.writeShellApplication {
    name = "ensure-dp-2-monitor";
    runtimeInputs = with pkgs; [
      coreutils
      hyprland
      jq
      syncSpecialWorkspacesMonitor
    ];
    text = ''
      set -eu

      # DP-2 is preferred. HDMI-A-1 is the same physical side monitor used as fallback.
      active_monitor() {
        hyprctl monitors -j | jq -e --arg name "$1" '
          any(.[]; .name == $name
            and (((.disabled // false) | not))
            and ((.width // 0) > 0)
            and ((.height // 0) > 0))
        ' >/dev/null
      }

      hyprctl keyword monitor DP-2,2560x1440@144,-1440x0,1,transform,1 >/dev/null || true
      hyprctl keyword monitor DP-2,addreserved,0,955,0,0 >/dev/null || true
      for _ in $(seq 1 8); do
        if active_monitor DP-2; then
          break
        fi
        hyprctl dispatch dpms on || true
        sleep 1
      done

      if active_monitor DP-2; then
        hyprctl keyword monitor DP-2,2560x1440@144,-1440x0,1,transform,1 >/dev/null || true
        hyprctl keyword monitor DP-2,addreserved,0,955,0,0 >/dev/null || true
        hyprctl keyword monitor HDMI-A-1,disable >/dev/null || true
        sync-special-workspaces-monitor || true
        exit 0
      fi

      hyprctl keyword monitor HDMI-A-1,2560x1440@144,-1440x0,1,transform,1 >/dev/null || true
      hyprctl keyword monitor HDMI-A-1,addreserved,0,955,0,0 >/dev/null || true
      if active_monitor HDMI-A-1; then
        sync-special-workspaces-monitor || true
        exit 0
      fi

      sync-special-workspaces-monitor || true
      echo "hyprland-dp2-fix: neither DP-2 nor HDMI-A-1 side monitor detected on login" >&2
      exit 0
    '';
  };
  specialWorkspaceMonitor = pkgs.writeShellApplication {
    name = "special-workspace-monitor";
    runtimeInputs = with pkgs; [
      hyprland
      jq
    ];
    text = ''
      set -euo pipefail

      hyprctl monitors -j | jq -r '
        [ .[]
          | select(
              (.name == "DP-2" or .name == "HDMI-A-1")
              and (((.disabled // false) | not))
              and ((.width // 0) > 0)
              and ((.height // 0) > 0)
            )
        ] | sort_by(if .name == "DP-2" then 0 else 1 end) | .[0].name // "DP-1"
      '
    '';
  };
  syncSpecialWorkspacesMonitor = pkgs.writeShellApplication {
    name = "sync-special-workspaces-monitor";
    runtimeInputs = with pkgs; [
      hyprland
      specialWorkspaceMonitor
    ];
    text = ''
      set -euo pipefail

      monitor="$(special-workspace-monitor)"

      for workspace in 6 7 8 9 10; do
        hyprctl dispatch moveworkspacetomonitor "$workspace" "$monitor" >/dev/null 2>&1 || true
      done

      for workspace in social obs tools scratchpad; do
        hyprctl dispatch moveworkspacetomonitor "special:$workspace" "$monitor" >/dev/null 2>&1 || true
      done
    '';
  };
in {
  imports = [./config.nix ./binds.nix];
  home.packages = with pkgs;
  with inputs.hyprcontrib.packages.${pkgs.stdenv.hostPlatform.system}; [
    libnotify
    emote
    wireplumber
    nwg-look
    wf-recorder
    brightnessctl
    pamixer
    slurp
    grim
    wl-clip-persist
    wl-clipboard
    wtype
    pngquant
    cliphist
    uair
    hypridle
    autoShutdown
    specialWorkspaceMonitor
    syncSpecialWorkspacesMonitor
    (writeShellApplication {
      name = "launch-obsidian-tools";
      runtimeInputs = with pkgs; [
        bash
        coreutils
        hyprland
        procps
        ripgrep
        specialWorkspaceMonitor
      ];
      text = ''
        set -euo pipefail

        if ! pgrep -fi '(^|/)(obsidian)( |$)' >/dev/null 2>&1; then
          env -u ELECTRON_RUN_AS_NODE -u ELECTRON_NO_ATTACH_CONSOLE obsidian >/dev/null 2>&1 &
        fi

        for _ in $(seq 1 30); do
          if hyprctl clients | rg -q 'class: (obsidian|Obsidian)$'; then
            monitor="$(special-workspace-monitor)"
            hyprctl dispatch movetoworkspacesilent 'special:tools,class:^(obsidian|Obsidian)$' >/dev/null 2>&1 || true
            hyprctl dispatch moveworkspacetomonitor 'special:tools' "$monitor" >/dev/null 2>&1 || true
            exit 0
          fi
          sleep 1
        done
      '';
    })
    (
      writeShellScriptBin "micmute"
      ''
        #!/bin/sh

        # shellcheck disable=SC2091
        if $(pamixer --default-source --get-mute); then
          pamixer --default-source --unmute
          sudo mic-light-off
        else
          pamixer --default-source --mute
          sudo mic-light-on
        fi
      ''
    )
    (
      writeShellScriptBin "toggle-special-workspace"
      ''
        set -eu

        if [ "$#" -ne 1 ]; then
          exit 2
        fi

        ws="$1"
        monitor="$(special-workspace-monitor)"
        current_monitor="$(hyprctl monitors | awk '/^Monitor / {m=$2} /focused: yes/ {print m; exit}')"

        if [ "''${current_monitor:-}" != "$monitor" ]; then
          hyprctl dispatch focusmonitor "$monitor"
        fi
        hyprctl dispatch moveworkspacetomonitor "special:$ws" "$monitor" >/dev/null 2>&1 || true
        hyprctl dispatch togglespecialworkspace "$ws"
        hyprctl dispatch moveworkspacetomonitor "special:$ws" "$monitor" >/dev/null 2>&1 || true
      ''
    )
    (
      writeShellScriptBin "move-special-workspace"
      ''
        set -eu

        if [ "$#" -ne 1 ]; then
          exit 2
        fi

        ws="$1"
        monitor="$(special-workspace-monitor)"
        hyprctl dispatch movetoworkspacesilent "special:$ws"
        hyprctl dispatch moveworkspacetomonitor "special:$ws" "$monitor" >/dev/null 2>&1 || true
      ''
    )
    (
      writeShellScriptBin "toggle-obs-special"
      ''
        set -eu

        monitor="$(special-workspace-monitor)"
        current_monitor="$(hyprctl monitors | awk '/^Monitor / {m=$2} /focused: yes/ {print m; exit}')"
        if [ "''${current_monitor:-}" != "$monitor" ]; then
          hyprctl dispatch focusmonitor "$monitor"
        fi

        if hyprctl clients | rg -q 'class: (obs|OBS|com.obsproject.Studio)$'; then
          hyprctl dispatch movetoworkspacesilent "special:obs,class:^(obs|OBS|com\\.obsproject\\.Studio)$"
          hyprctl dispatch moveworkspacetomonitor "special:obs" "$monitor" >/dev/null 2>&1 || true
          hyprctl dispatch togglespecialworkspace obs
          hyprctl dispatch moveworkspacetomonitor "special:obs" "$monitor" >/dev/null 2>&1 || true
        else
          hyprctl dispatch moveworkspacetomonitor "special:obs" "$monitor" >/dev/null 2>&1 || true
          hyprctl dispatch togglespecialworkspace obs
          hyprctl dispatch moveworkspacetomonitor "special:obs" "$monitor" >/dev/null 2>&1 || true
          hyprctl dispatch exec "obs"
        fi

      ''
    )
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    # Keep the compositor package in one place: the NixOS Hyprland module.
    package = pkgs.hyprland;
    systemd = {
      enable = false;
    };
  };
  xdg.configFile."uwsm/env".source = "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
  services = {
    hypridle = {
      enable = true;
      systemdTarget = "graphical-session.target";
      settings = {
        general = {
          lock_cmd = "${quickshellIpc}/bin/quickshell-ipc lock lock";
          before_sleep_cmd = "${quickshellIpc}/bin/quickshell-ipc lock lock";
          after_sleep_cmd = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on";
          ignore_dbus_inhibit = false;
          ignore_systemd_inhibit = false;
        };
        listener = [
          {
            timeout = 150;
            on-timeout = "${pkgs.brightnessctl}/bin/brightnessctl -s set 10";
            on-resume = "${pkgs.brightnessctl}/bin/brightnessctl -r";
          }
          {
            timeout = 300;
            on-timeout = "${pkgs.systemd}/bin/loginctl lock-session";
          }
          {
            timeout = 330;
            on-timeout = "${pkgs.hyprland}/bin/hyprctl dispatch dpms off";
            on-resume = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on";
          }
          {
            timeout = 1800;
            on-timeout = "${pkgs.systemd}/bin/systemctl suspend";
          }
        ];
      };
    };
    wlsunset = {
      enable = true;
      latitude = "52";
      longitude = "21";
      temperature = {
        day = 6200;
        night = 3000;
      };
      systemdTarget = "graphical-session.target";
    };
  };
  systemd.user = {
    services = {
      hyprland-dp2-fix = {
        Unit = {
          Description = "Re-assert DP-2 monitor mode on login.";
          After = ["graphical-session.target"];
          PartOf = ["graphical-session.target"];
        };
        Service = {
          Type = "oneshot";
          ExecStart = lib.getExe ensureDp2Monitor;
        };
        Install = {
          WantedBy = ["graphical-session.target"];
        };
      };
      hypridle.Service.ExecStartPre = "${pkgs.bash}/bin/bash -c 'test \"$(${pkgs.coreutils}/bin/date +%%H)\" -lt 7 -o \"$(${pkgs.coreutils}/bin/date +%%H)\" -ge 22'";
      hypridle-stop-daytime = {
        Unit.Description = "Stop hypridle during daytime";
        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.systemd}/bin/systemctl --user stop hypridle.service";
        };
      };
      hypridle-start-nighttime = {
        Unit.Description = "Start hypridle at night";
        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.systemd}/bin/systemctl --user start hypridle.service";
        };
      };
    };
    timers = {
      hypridle-stop-daytime = {
        Unit.Description = "Stop hypridle at 07:00";
        Timer = {
          OnCalendar = "*-*-* 07:00:00";
          Persistent = true;
        };
        Install.WantedBy = ["timers.target"];
      };
      hypridle-start-nighttime = {
        Unit.Description = "Start hypridle at 22:00";
        Timer = {
          OnCalendar = "*-*-* 22:00:00";
          Persistent = true;
        };
        Install.WantedBy = ["timers.target"];
      };
    };
  };
  # fake a tray to let apps start
  # https://github.com/nix-community/home-manager/issues/2064
  systemd.user.services.ydotoold = {
    Unit = {
      Description = "ydotool daemon";
      PartOf = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "${pkgs.ydotool}/bin/ydotoold --socket-path=%t/.ydotool_socket --socket-own";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };
  systemd.user.services.cliphist-store = {
    Unit = {
      Description = "Store Wayland clipboard history";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "always";
      RestartSec = 2;
    };
    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };
  systemd.user.targets.tray = {
    Unit = {
      Description = "Home Manager System Tray";
      Requires = ["graphical-session-pre.target"];
    };
  };
  systemd.user.services.auto-shutdown = {
    Unit = {
      Description = "Power off overnight unless cancelled from the Quickshell widget";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      ExecStart = lib.getExe autoShutdown;
      Restart = "always";
      RestartSec = 10;
    };
    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };
}
