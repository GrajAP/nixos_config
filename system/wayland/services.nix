{pkgs, ...}: let
  autoShutdownScript = pkgs.writeShellScriptBin "auto-shutdown" ''
    cancel_file="/tmp/cancel_auto_shutdown"

    check_active() {
      for session in $(loginctl list-sessions --no-legend | awk '{print $1}'); do
        if loginctl show-session "$session" 2>/dev/null | grep -q '^Active=yes$'; then
          return 0
        fi
      done
      if w | grep -q 'tty\|:0\|pts'; then
        return 0
      fi
      return 1
    }

    shutdown_at_midnight() {
      local session_id
      session_id=$(loginctl list-sessions --no-legend 2>/dev/null | awk 'NR==1 {print $1}' | head -1)

      if [[ -z "$session_id" ]]; then
        systemctl poweroff
        return
      fi

      notify-send -u critical -t 10000 \
        "Auto shutdown" "System will shut down in 30 seconds. Enter password to cancel."

      local deadline=$(( $(date +%s) + 30 ))
      local canceled=0

      while (( $(date +%s) < deadline )); do
        if [[ -f "$cancel_file" ]]; then
          rm -f "$cancel_file"
          canceled=1
          break
        fi
        sleep 1
      done

      if (( canceled == 0 )); then
        notify-send -u critical -t 5000 "Auto shutdown" "Shutting down now."
        systemctl poweroff
      fi
    }

    check_idle() {
      local session_id=$1
      local idle_hint idle_since_usec now_usec

      idle_hint="$(loginctl show-session "$session_id" -p IdleHint --value 2>/dev/null || true)"
      if [[ "$idle_hint" != "yes" ]]; then
        return 1
      fi

      idle_since_usec="$(loginctl show-session "$session_id" -p IdleSinceHintUSec --value 2>/dev/null || echo 0)"
      if [[ ! "$idle_since_usec" =~ ^[0-9]+$ ]] || (( idle_since_usec <= 0 )); then
        return 1
      fi

      now_usec=$(( $(date +%s) * 1000000 ))
      if (( now_usec <= idle_since_usec )); then
        return 1
      fi

      local idle_seconds=$(( (now_usec - idle_since_usec) / 1000000 ))
      if (( idle_seconds >= 300 )); then
        return 0
      fi
      return 1
    }

    current_time=$(date +%H%M)
    if [[ "$current_time" == "00:00" ]]; then
      shutdown_at_midnight
    elif [[ "$current_time" < "06:00" ]]; then
      if ! check_active; then
        for session in $(loginctl list-sessions --no-legend | awk '{print $1}'); do
          if check_idle "$session"; then
            shutdown_at_midnight
            break
          fi
        done
      fi
    fi
  '';
in {
  systemd.services = {
    seatd = {
      enable = true;
      description = "Seat management daemon";
      script = "${pkgs.seatd}/bin/seatd -g wheel";
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "1";
      };
      wantedBy = ["multi-user.target"];
    };
    auto-shutdown = {
      description = "Auto shutdown after midnight if system is idle";
      serviceConfig = {
        Type = "oneshot";
        Nice = 19;
        IOSchedulingClass = "best-effort";
      };
      script = "${autoShutdownScript}/bin/auto-shutdown";
    };
  };
  systemd.timers."auto-shutdown" = {
    description = "Run auto-shutdown check every 5 minutes after midnight";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "00:00/5";
      Persistent = true;
    };
  };

  services = {
    pulseaudio.enable = false;
    xserver.enable = true;
    openssh.enable = true;
    greetd = {
      enable = true;
      settings = rec {
        initial_session = {
          command = "start-hyprland";
          user = "grajpap";
        };
        default_session = initial_session;
      };
    };

    gnome = {
      glib-networking.enable = true;
      gnome-keyring.enable = true;
    };
    logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "lock";
    };

    udisks2.enable = true;
    printing.enable = true;
    fstrim.enable = true;
  };
}
