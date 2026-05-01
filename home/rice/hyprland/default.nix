{
  pkgs,
  lib,
  inputs,
  ...
}: let
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

      target_minute="00:01"
      watch_seconds=20
      poll_seconds=60
      idle_threshold=0

      mkdir -p "''${XDG_RUNTIME_DIR:-/run/user/$UID}/auto-shutdown"

      get_session_id() {
        if [[ -n "''${XDG_SESSION_ID:-}" ]]; then
          printf '%s\n' "$XDG_SESSION_ID"
          return 0
        fi

        loginctl list-sessions --no-legend 2>/dev/null | awk -v user="$USER" '$3 == user { print $1; exit }'
      }

      idle_seconds() {
        local session_id="$1"
        local idle_hint idle_since_usec now_usec

        idle_hint="$(loginctl show-session "$session_id" -p IdleHint --value 2>/dev/null || true)"
        if [[ "$idle_hint" != "yes" ]]; then
          echo 0
          return 0
        fi

        idle_since_usec="$(loginctl show-session "$session_id" -p IdleSinceHintUSec --value 2>/dev/null || echo 0)"
        if [[ ! "$idle_since_usec" =~ ^[0-9]+$ ]] || (( idle_since_usec <= 0 )); then
          echo 0
          return 0
        fi

        now_usec=$(( $(date +%s) * 1000000 ))
        if (( now_usec <= idle_since_usec )); then
          echo 0
          return 0
        fi

        echo $(( (now_usec - idle_since_usec) / 1000000 ))
      }

      while true; do
        now_minute="$(date +%H:%M)"

        if [[ "$now_minute" == "$target_minute" ]]; then

          session_id="$(get_session_id || true)"
          if [[ -z "''${session_id:-}" ]]; then
            sleep "$poll_seconds"
            continue
          fi

          idle_time=$(idle_seconds "$session_id")
          if (( idle_time < idle_threshold )); then
            sleep "$poll_seconds"
            continue
          fi

          notify-send -u critical -t $((watch_seconds * 1000)) \
            "Auto shutdown" \
            "System will shut down in 20 seconds unless password is provided."

          hyprctl dispatch exec "foot -e sh -c 'read -t 20 -s -p \"Enter password to cancel shutdown: \" password; if [ -n \"\$password\" ]; then touch /tmp/cancel_auto_shutdown; fi'"

          deadline=$(( $(date +%s) + watch_seconds ))
          cancel=0

          while (( $(date +%s) < deadline )); do
            if [ -f /tmp/cancel_auto_shutdown ]; then
              cancel=1
              rm /tmp/cancel_auto_shutdown
              break
            fi
            sleep 1
          done

          if (( cancel == 0 )); then
            notify-send -u critical -t 3000 "Auto shutdown" "No password provided. Logging out and shutting down."
            loginctl terminate-session "$session_id"
            systemctl poweroff
            exit 0
          fi
        fi

        sleep "$poll_seconds"
      done
    '';
  };
in {
  imports = [./config.nix ./binds.nix];
  home.packages = with pkgs;
  with inputs.hyprcontrib.packages.${pkgs.stdenv.hostPlatform.system}; [
    libnotify
    swaybg
    emote
    wireplumber
    nwg-look
    wf-recorder
    brightnessctl
    pamixer
    slurp
    grim
    mako
    swappy
    grimblast
    hyprpicker
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
    (writeShellScriptBin
      "launcher"
      ''
        exec tofi-drun
      '')
    (writeShellScriptBin
      "pauseshot"
      ''
        ${hyprpicker}/bin/hyprpicker -r -z &
        picker_proc=$!

        ${grimblast}/bin/grimblast save area - | tee ~/pics/$(date +'screenshot-%F').png | wl-copy

        kill $picker_proc
      '')
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
          lock_cmd = "${pkgs.procps}/bin/pidof hyprlock || ${pkgs.hyprlock}/bin/hyprlock";
          before_sleep_cmd = "${pkgs.systemd}/bin/loginctl lock-session";
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
  systemd.user.targets.tray = {
    Unit = {
      Description = "Home Manager System Tray";
      Requires = ["graphical-session-pre.target"];
    };
  };
  systemd.user.services.auto-shutdown = {
    Unit = {
      Description = "Power off at 05:00 when the session stays idle";
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
