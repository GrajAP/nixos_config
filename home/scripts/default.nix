{pkgs, ...}: let
  hyprctlBin = "${pkgs.hyprland}/bin/hyprctl";
  makoctlBin = "${pkgs.mako}/bin/makoctl";
  notifySendBin = "${pkgs.libnotify}/bin/notify-send";
  procpsBin = "${pkgs.procps}/bin";
  coreutilsBin = "${pkgs.coreutils}/bin";
  notificationStateScript = ''
    NOTIFY_DIR="$HOME/.cache/mako"
    MANUAL_STATE="$NOTIFY_DIR/dnd-manual"
    AUTO_STATE="$NOTIFY_DIR/dnd-auto"

    mkdir_cmd="${coreutilsBin}/mkdir"
    touch_cmd="${coreutilsBin}/touch"
    rm_cmd="${coreutilsBin}/rm"
    sleep_cmd="${coreutilsBin}/sleep"
    pgrep_cmd="${procpsBin}/pgrep"

    "$mkdir_cmd" -p "$NOTIFY_DIR"

    apply_mode() {
      ${makoctlBin} mode -a dnd 2>/dev/null || true
      if [ -f "$MANUAL_STATE" ] || [ -f "$AUTO_STATE" ]; then
        ${makoctlBin} mode -s dnd 2>/dev/null || true
      else
        ${makoctlBin} mode -s default 2>/dev/null || true
      fi
    }

    hypr_notify() {
      local icon="$1"
      local color="$2"
      shift 2
      ${notifySendBin} -u low -t 1800 "$*" 2>/dev/null || true
    }
  '';
  autoDnd = pkgs.writeShellScriptBin "auto-dnd" ''
    ${notificationStateScript}

    monitor_screen_share() {
      while true; do
        # Check for OBS
        if "$pgrep_cmd" -x "obs" >/dev/null 2>&1; then
          if [ ! -f "$AUTO_STATE" ]; then
            hypr_notify 1 "rgb(89b4fa)" "Auto DND enabled for streaming"
            "$touch_cmd" "$AUTO_STATE"
            apply_mode
          fi
        else
          # Check for wf-recorder (wayland screen recorder)
          if "$pgrep_cmd" -f "wf-recorder" >/dev/null 2>&1; then
            if [ ! -f "$AUTO_STATE" ]; then
              hypr_notify 1 "rgb(89b4fa)" "Auto DND enabled for recording"
              "$touch_cmd" "$AUTO_STATE"
              apply_mode
            fi
          else
            # No recording/streaming, clear only the automatic DND state.
            if [ -f "$AUTO_STATE" ]; then
              "$rm_cmd" -f "$AUTO_STATE"
              apply_mode
              hypr_notify 5 "rgb(a6e3a1)" "Auto DND disabled"
            fi
          fi
        fi
        "$sleep_cmd" 2
      done
    }

    monitor_screen_share
  '';
in {
  home.packages = [
    (pkgs.writeShellScriptBin "bcn" (builtins.readFile ./bcn))
    (pkgs.writeShellScriptBin "katana-switch" (builtins.readFile ./katana-switch))
    (pkgs.writeShellScriptBin "toggle-notifications" ''
      ${notificationStateScript}
      if [ -f "$MANUAL_STATE" ]; then
        "$rm_cmd" -f "$MANUAL_STATE"
        apply_mode
        hypr_notify 5 "rgb(a6e3a1)" "Manual DND disabled"
      else
        hypr_notify 1 "rgb(89b4fa)" "Manual DND enabled"
        "$touch_cmd" "$MANUAL_STATE"
        apply_mode
      fi
    '')
    autoDnd
  ];
}
