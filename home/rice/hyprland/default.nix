{
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
      custom_target_file="$runtime_dir/custom-target"
      last_trigger_file="$runtime_dir/last-trigger"
      pending_file="$runtime_dir/pending"
      mkdir -p "$runtime_dir"

      custom_target() {
        if [[ -r "$custom_target_file" ]]; then
          head -n1 "$custom_target_file" | awk '/^([01][0-9]|2[0-3]):[0-5][0-9]$/ { print; exit }'
        fi
      }

      should_trigger() {
        local now_minute="$1"
        local target
        for target in $default_targets "$(custom_target)"; do
          [[ -n "$target" ]] || continue
          if [[ "$now_minute" == "$target" ]]; then
            return 0
          fi
        done
        return 1
      }

      while true; do
        today="$(date +%F)"
        now_minute="$(date +%H:%M)"
        trigger_id="$today $now_minute"

        if should_trigger "$now_minute" && [[ "$(cat "$last_trigger_file" 2>/dev/null || true)" != "$trigger_id" ]]; then
          printf '%s\n' "$trigger_id" > "$last_trigger_file"
          printf '%s\n' "$now_minute" > "$pending_file"
          rm -f "$cancel_file"
          notify-send -u critical -t $((watch_seconds * 1000)) \
            "Auto shutdown" \
            "System will power off in 5 minutes. Open Tools -> Shutdown timer to cancel."

          deadline=$(( $(date +%s) + watch_seconds ))
          cancel=0

          while (( $(date +%s) < deadline )); do
            if [ -f "$cancel_file" ]; then
              cancel=1
              rm -f "$cancel_file"
              break
            fi
            sleep 1
          done

          rm -f "$pending_file"
          if [[ "$(custom_target)" == "$now_minute" ]]; then
            rm -f "$custom_target_file"
          fi

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
  obsidianCalendarWidget = pkgs.writeShellApplication {
    name = "obsidian-calendar-widget";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      electron
      hyprland
      jq
      procps
      ripgrep
    ];
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      title='Obsidian Calendar Editor'
      app_asar='/home/grajpap/dev/obsidian-calendar/out/Obsidian Calendar Editor-linux-x64/resources/app.asar'
      existing_count="$(hyprctl -j clients | jq '[.[] | select(.title == "'"$title"'")] | length')"

      if [[ ! -f "$app_asar" ]]; then
        echo "Missing $app_asar. Build it with: npm run package" >&2
        exit 1
      fi

      if (( existing_count > 1 )); then
        hyprctl -j clients \
          | jq -r '.[] | select(.title == "'"$title"'") | .pid' \
          | sort -u \
          | while read -r pid; do
              [[ -n "$pid" ]] && kill "$pid" >/dev/null 2>&1 || true
            done
        sleep 1
        existing_count=0
      fi

      if (( existing_count == 0 )); then
        env -u ELECTRON_RUN_AS_NODE -u ELECTRON_NO_ATTACH_CONSOLE electron "$app_asar" >/dev/null 2>&1 &
      fi

      for _ in $(seq 1 40); do
        window_address="$(hyprctl -j clients | jq -r '.[] | select(.title == "'"$title"'") | .address' | head -n1)"
        if [[ -n "''${window_address:-}" && "$window_address" != "null" ]]; then
          hyprctl dispatch movetoworkspacesilent "6,address:$window_address" >/dev/null 2>&1 || true
          is_floating="$(hyprctl -j clients | jq -r '.[] | select(.address == "'"$window_address"'") | .floating' | head -n1)"
          if [[ "''${is_floating:-false}" != "true" && "''${is_floating:-0}" != "1" ]]; then
            hyprctl dispatch setfloating "address:$window_address" >/dev/null 2>&1 || true
            sleep 0.1
          fi
          hyprctl dispatch resizewindowpixel "exact 1416 1581,address:$window_address" >/dev/null 2>&1 || true
          hyprctl dispatch movewindowpixel "exact -1428 12,address:$window_address" >/dev/null 2>&1 || true

          exit 0
        fi
        sleep 0.25
      done

      echo "Obsidian Calendar Editor window did not appear in time" >&2
      exit 1
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
    (writeShellApplication {
      name = "launch-obsidian-tools";
      runtimeInputs = with pkgs; [
        bash
        coreutils
        hyprland
        procps
        ripgrep
      ];
      text = ''
        set -euo pipefail

        for _ in $(seq 1 20); do
          if hyprctl monitors | rg -q '^Monitor DP-2 '; then
            break
          fi
          sleep 1
        done

        if ! pgrep -fi '(^|/)(obsidian)( |$)' >/dev/null 2>&1; then
          env -u ELECTRON_RUN_AS_NODE -u ELECTRON_NO_ATTACH_CONSOLE obsidian >/dev/null 2>&1 &
        fi

        for _ in $(seq 1 30); do
          if hyprctl clients | rg -q 'class: (obsidian|Obsidian)$'; then
            hyprctl dispatch movetoworkspacesilent 'special:tools,class:^(obsidian|Obsidian)$' >/dev/null 2>&1 || true
            hyprctl dispatch moveworkspacetomonitor 'special:tools' DP-2 >/dev/null 2>&1 || true
            exit 0
          fi
          sleep 1
        done
      '';
    })
    obsidianCalendarWidget
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
      writeShellScriptBin "toggle-special-dp2"
      ''
        set -eu

        if [ "$#" -ne 1 ]; then
          exit 2
        fi

        ws="$1"
        current_monitor="$(hyprctl monitors | awk '/^Monitor / {m=$2} /focused: yes/ {print m; exit}')"

        if [ "''${current_monitor:-}" != "DP-2" ]; then
          hyprctl dispatch focusmonitor DP-2
        fi
        hyprctl dispatch moveworkspacetomonitor "special:$ws" DP-2 >/dev/null 2>&1 || true
        hyprctl dispatch togglespecialworkspace "$ws"
        hyprctl dispatch moveworkspacetomonitor "special:$ws" DP-2 >/dev/null 2>&1 || true
      ''
    )
    (
      writeShellScriptBin "move-special-dp2"
      ''
        set -eu

        if [ "$#" -ne 1 ]; then
          exit 2
        fi

        ws="$1"
        hyprctl dispatch movetoworkspacesilent "special:$ws"
        hyprctl dispatch moveworkspacetomonitor "special:$ws" DP-2 >/dev/null 2>&1 || true
      ''
    )
    (
      writeShellScriptBin "toggle-obs-special"
      ''
        set -eu

        current_monitor="$(hyprctl monitors | awk '/^Monitor / {m=$2} /focused: yes/ {print m; exit}')"
        if [ "''${current_monitor:-}" != "DP-2" ]; then
          hyprctl dispatch focusmonitor DP-2
        fi

        if hyprctl clients | rg -q 'class: (obs|OBS|com.obsproject.Studio)$'; then
          hyprctl dispatch movetoworkspacesilent "special:obs,class:^(obs|OBS|com\\.obsproject\\.Studio)$"
          hyprctl dispatch moveworkspacetomonitor "special:obs" DP-2 >/dev/null 2>&1 || true
          hyprctl dispatch togglespecialworkspace obs
          hyprctl dispatch moveworkspacetomonitor "special:obs" DP-2 >/dev/null 2>&1 || true
        else
          hyprctl dispatch moveworkspacetomonitor "special:obs" DP-2 >/dev/null 2>&1 || true
          hyprctl dispatch togglespecialworkspace obs
          hyprctl dispatch moveworkspacetomonitor "special:obs" DP-2 >/dev/null 2>&1 || true
          hyprctl dispatch exec "obs"
        fi

      ''
    )
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    #package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    package = pkgs.hyprland;
    systemd = {
      variables = ["--all"];
      extraCommands = [
        "systemctl --user stop graphical-session.target"
        "systemctl --user start hyprland-session.target"
      ];
    };
  };
  services = {
    hypridle = {
      enable = true;
      systemdTarget = "hyprland-session.target";
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
      systemdTarget = "hyprland-session.target";
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
  systemd.user.services.obsidian-calendar-widget = {
    Unit = {
      Description = "Obsidian Calendar Editor widget";
      After = ["hyprland-session.target"];
      PartOf = ["hyprland-session.target"];
    };
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe obsidianCalendarWidget;
      RemainAfterExit = true;
    };
    Install = {
      WantedBy = ["hyprland-session.target"];
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
      After = ["hyprland-session.target"];
      PartOf = ["hyprland-session.target"];
    };
    Service = {
      ExecStart = lib.getExe autoShutdown;
      Restart = "always";
      RestartSec = 10;
    };
    Install = {
      WantedBy = ["hyprland-session.target"];
    };
  };
}
