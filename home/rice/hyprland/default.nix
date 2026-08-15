{
  config,
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
      jq
      libnotify
      pipewire
      ripgrep
      sqlite
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
      agent_wait_file="$runtime_dir/agent-waiting"
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

      shutdown_blocked() {
        systemd-inhibit --list --json=short \
          | jq -e 'any(.[]; (.mode == "block") and ((.what | split(":")) | index("shutdown")))' >/dev/null
      }

      ${builtins.readFile ../quickshell/scripts/agent-status-functions.sh}

      play_shutdown_alert() {
        pw-play --volume=0.55 \
          "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/message.oga" \
          >/dev/null 2>&1 &
      }

      notify_shutdown() {
        notify-send --app-name="Auto shutdown" --icon=system-shutdown "$@"
      }

      guard_deadline_for_agents() {
        local deadline="$1"
        local now="$2"
        local minimum_deadline

        agent_guard_deadline="$deadline"
        if ai_agent_working; then
          minimum_deadline=$((now + watch_seconds))
          (( agent_guard_deadline <= minimum_deadline )) || return 1
          agent_guard_deadline="$minimum_deadline"
          printf '%s\n' "waiting for AI agents" > "$pending_file"
          printf '%s\n' "$agent_guard_deadline" > "$pending_deadline_file"
          if [[ ! -e "$agent_wait_file" ]]; then
            touch "$agent_wait_file"
            notify_shutdown -u critical -t 5000 \
              "Auto shutdown paused" \
              "Codex or T3 Code is working. The five-minute countdown will start after all agents finish."
          fi
          return 0
        fi

        if [[ -e "$agent_wait_file" ]]; then
          rm -f "$agent_wait_file"
          printf '%s\n' "in 5 min" > "$pending_file"
          printf '%s\n' "$agent_guard_deadline" > "$pending_deadline_file"
          notify_shutdown -u normal -t 5000 \
            "Auto shutdown resumed" \
            "All AI agents finished. Power off is scheduled in five minutes."
        fi
        return 1
      }

      power_off() {
        if shutdown_blocked; then
          notify_shutdown -u critical -t 5000 "Auto shutdown" "A system inhibitor is blocking shutdown."
          return 1
        fi
        systemctl poweroff
      }

      handle_custom_deadline() {
        local deadline now remaining label
        deadline="$(read_deadline)"
        if [[ -z "$deadline" ]]; then
          return 1
        fi

        now="$(date +%s)"
        if [ -f "$cancel_file" ]; then
          rm -f "$cancel_file" "$custom_deadline_file" "$pending_file" "$pending_deadline_file" "$agent_wait_file"
          notify_shutdown -u normal -t 2500 "Auto shutdown" "Shutdown timer cancelled."
          return 0
        fi

        if guard_deadline_for_agents "$deadline" "$now"; then
          deadline="$agent_guard_deadline"
          printf '%s\n' "$deadline" > "$custom_deadline_file"
        fi

        if (( now < deadline )); then
          remaining=$((deadline - now))
          if [[ -e "$agent_wait_file" ]]; then
            label="waiting for AI agents"
          else
            label="in $(( (remaining + 59) / 60 )) min"
          fi
          printf '%s\n' "$label" > "$pending_file"
          printf '%s\n' "$deadline" > "$pending_deadline_file"
          return 0
        fi

        rm -f "$custom_deadline_file" "$pending_file" "$pending_deadline_file"
        notify_shutdown -u critical -t 3000 "Auto shutdown" "Powering off now."
        power_off || true
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
          rm -f "$cancel_file" "$agent_wait_file"
          notify_shutdown -u critical -t $((watch_seconds * 1000)) \
            "Auto shutdown" \
            "System will power off in 5 minutes. Open the shutdown widget to cancel."
          play_shutdown_alert

          cancel=0
          while true; do
            if [ -f "$cancel_file" ]; then
              cancel=1
              rm -f "$cancel_file"
              break
            fi
            now="$(date +%s)"
            if guard_deadline_for_agents "$deadline" "$now"; then
              deadline="$agent_guard_deadline"
            fi
            if (( now >= deadline )); then
              break
            fi
            sleep 1
          done

          rm -f "$pending_file" "$pending_deadline_file" "$agent_wait_file"

          if (( cancel == 0 )); then
            notify_shutdown -u critical -t 3000 "Auto shutdown" "Powering off now."
            power_off || true
            exit 0
          fi

          notify_shutdown -u normal -t 2500 "Auto shutdown" "Shutdown cancelled."
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
  suspendAtNight = pkgs.writeShellApplication {
    name = "suspend-at-night";
    runtimeInputs = with pkgs; [coreutils systemd];
    text = ''
      set -euo pipefail

      hour="$(date +%H)"
      if (( 10#$hour < 7 || 10#$hour >= 22 )); then
        systemctl suspend
      fi
    '';
  };
  secureSessionLock = pkgs.writeShellApplication {
    name = "secure-session-lock";
    runtimeInputs = with pkgs; [cliphist hyprlock procps wl-clipboard];
    text = ''
      set -euo pipefail

      wl-copy --clear || true
      cliphist wipe || true
      pgrep -x hyprlock >/dev/null || exec hyprlock
    '';
  };
  clipboardHistoryStore = pkgs.writeShellApplication {
    name = "clipboard-history-store";
    runtimeInputs = with pkgs; [cliphist ripgrep wl-clipboard];
    text = ''
      set -euo pipefail

      types="$(wl-paste --list-types 2>/dev/null || true)"
      if printf '%s\n' "$types" | rg -qi 'password|secret|sensitive|x-kde-passwordManagerHint'; then
        exit 0
      fi
      exec cliphist store
    '';
  };
  graphicalAutostartService = command: {
    Unit = {
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      ExecStart = command;
      Restart = "on-abnormal";
      RestartSec = 5;
      TimeoutStopSec = 10;
    };
  };
  graphicalAutostartTimer = unit: delay: {
    Unit = {
      Description = "Delay ${unit} until the graphical session is ready";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Timer = {
      OnActiveSec = "${toString delay}s";
      AccuracySec = "1s";
      Unit = "${unit}.service";
    };
    Install.WantedBy = ["graphical-session.target"];
  };
in {
  imports = [./config.nix ./binds.nix];
  home.packages = with pkgs;
  with inputs.hyprcontrib.packages.${pkgs.stdenv.hostPlatform.system}; [
    libnotify
    emote
    wireplumber
    nwg-look

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
    clipboardHistoryStore
    secureSessionLock
    specialWorkspaceMonitor
    syncSpecialWorkspacesMonitor
    (writeShellApplication {
      name = "launch-obsidian-tools";
      runtimeInputs = with pkgs; [
        bash
        coreutils
        hyprland
        jq
        procps
        specialWorkspaceMonitor
      ];
      text = ''
        set -euo pipefail

        if ! pgrep -fi '(^|/)(obsidian)( |$)' >/dev/null 2>&1; then
          env -u ELECTRON_RUN_AS_NODE -u ELECTRON_NO_ATTACH_CONSOLE obsidian >/dev/null 2>&1 &
        fi

        for _ in $(seq 1 30); do
          if hyprctl clients -j | jq -e 'any(.[]; (.class | ascii_downcase) == "obsidian")' >/dev/null; then
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
      writeShellApplication {
        name = "micmute";
        runtimeInputs = [libnotify pamixer];
        text = ''
          set -euo pipefail

          if [ "$(pamixer --default-source --get-mute)" = "true" ]; then
            pamixer --default-source --unmute
            notify-send -t 1500 "Microphone" "Unmuted"
          else
            pamixer --default-source --mute
            notify-send -u critical -t 1500 "Microphone" "Muted"
          fi
        '';
      }
    )
    (
      writeShellApplication {
        name = "toggle-special-workspace";
        runtimeInputs = with pkgs; [hyprland jq specialWorkspaceMonitor];
        text = ''
          set -eu

          if [ "$#" -ne 1 ]; then
            exit 2
          fi

          ws="$1"
          monitor="$(special-workspace-monitor)"
          current_monitor="$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')"

          if [ "''${current_monitor:-}" != "$monitor" ]; then
            hyprctl dispatch focusmonitor "$monitor"
          fi
          hyprctl dispatch moveworkspacetomonitor "special:$ws" "$monitor" >/dev/null 2>&1 || true
          hyprctl dispatch togglespecialworkspace "$ws"
          hyprctl dispatch moveworkspacetomonitor "special:$ws" "$monitor" >/dev/null 2>&1 || true
        '';
      }
    )
    (
      writeShellApplication {
        name = "move-special-workspace";
        runtimeInputs = with pkgs; [hyprland specialWorkspaceMonitor];
        text = ''
          set -eu

          if [ "$#" -ne 1 ]; then
            exit 2
          fi

          ws="$1"
          monitor="$(special-workspace-monitor)"
          hyprctl dispatch movetoworkspacesilent "special:$ws"
          hyprctl dispatch moveworkspacetomonitor "special:$ws" "$monitor" >/dev/null 2>&1 || true
        '';
      }
    )
    (
      writeShellApplication {
        name = "toggle-obs-special";
        runtimeInputs = with pkgs; [hyprland jq specialWorkspaceMonitor];
        text = ''
          set -eu

          monitor="$(special-workspace-monitor)"
          current_monitor="$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')"
          if [ "''${current_monitor:-}" != "$monitor" ]; then
            hyprctl dispatch focusmonitor "$monitor"
          fi

          if hyprctl clients -j | jq -e 'any(.[]; (.class | ascii_downcase) == "obs" or .class == "com.obsproject.Studio")' >/dev/null; then
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

        '';
      }
    )
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    # Keep the compositor package in one place: the NixOS Hyprland module.
    package = pkgs.hyprland;
    plugins = [];
    systemd = {
      enable = false;
    };
  };
  xdg.configFile."uwsm/env".source = "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
  services = {
    hypridle = {
      # Keep the idle policy available, but do not auto-lock or suspend while
      # long-running AI agents may still be working unattended.
      enable = false;
      systemdTarget = "graphical-session.target";
      settings = {
        general = {
          lock_cmd = lib.getExe secureSessionLock;
          before_sleep_cmd = lib.getExe secureSessionLock;
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
            on-timeout = lib.getExe suspendAtNight;
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
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading_bar = true;
        hide_cursor = true;
        ignore_empty_input = true;
      };
      background = [
        {
          monitor = "";
          path = "screenshot";
          blur_passes = 3;
          blur_size = 8;
        }
      ];
      label = [
        {
          monitor = "";
          text = "cmd[update:1000] date +'%H:%M'";
          color = "rgb(${config.lib.stylix.colors.base05})";
          font_family = "Lexend";
          font_size = 68;
          position = "0, 120";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = "cmd[update:60000] date +'%A, %d %B'";
          color = "rgb(${config.lib.stylix.colors.base04})";
          font_family = "Lexend";
          font_size = 18;
          position = "0, 62";
          halign = "center";
          valign = "center";
        }
      ];
      input-field = [
        {
          monitor = "";
          size = "360, 54";
          position = "0, -35";
          dots_center = true;
          fade_on_empty = false;
          font_color = "rgb(${config.lib.stylix.colors.base05})";
          inner_color = "rgb(${config.lib.stylix.colors.base02})";
          outer_color = "rgb(${config.lib.stylix.colors.base0D})";
          check_color = "rgb(${config.lib.stylix.colors.base0A})";
          fail_color = "rgb(${config.lib.stylix.colors.base08})";
          outline_thickness = 2;
          placeholder_text = "Password";
          fail_text = "Authentication failed";
        }
      ];
    };
  };
  stylix.targets.hyprlock.enable = false;
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
      cliphist-store = {
        Unit = {
          Description = "Store Wayland clipboard history";
          After = ["graphical-session.target"];
          PartOf = ["graphical-session.target"];
        };
        Service = {
          ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${lib.getExe clipboardHistoryStore}";
          Restart = "always";
          RestartSec = 2;
        };
        Install.WantedBy = ["graphical-session.target"];
      };
      auto-shutdown = {
        Unit = {
          Description = "Power off overnight after AI agents become idle";
          After = ["graphical-session.target"];
          PartOf = ["graphical-session.target"];
        };
        Service = {
          ExecStart = lib.getExe autoShutdown;
          Restart = "always";
          RestartSec = 10;
        };
        Install.WantedBy = ["graphical-session.target"];
      };
      autostart-kdeconnect = graphicalAutostartService "${lib.getExe' pkgs.kdePackages.kdeconnect-kde "kdeconnect-indicator"}";
      autostart-signal = graphicalAutostartService (lib.getExe pkgs.signal-desktop);
      autostart-ferdium = graphicalAutostartService (lib.getExe' pkgs.ferdium "ferdium");
      autostart-t3code = graphicalAutostartService "${config.home.profileDirectory}/bin/t3code-desktop";
      autostart-helium = graphicalAutostartService "${config.home.profileDirectory}/bin/helium";
    };
    timers = {
      autostart-kdeconnect = graphicalAutostartTimer "autostart-kdeconnect" 2;
      autostart-signal = graphicalAutostartTimer "autostart-signal" 4;
      autostart-ferdium = graphicalAutostartTimer "autostart-ferdium" 6;
      autostart-t3code = graphicalAutostartTimer "autostart-t3code" 8;
      autostart-helium = graphicalAutostartTimer "autostart-helium" 10;
    };
    # Some tray applications still wait for this compatibility target.
    targets.tray.Unit = {
      Description = "Home Manager System Tray";
      Requires = ["graphical-session-pre.target"];
    };
  };
}
