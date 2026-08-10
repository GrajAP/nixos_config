{
  pkgs,
  config,
  lib,
  ...
}: let
  jarvis-autostart = pkgs.writeShellApplication {
    name = "jarvis-autostart";
    runtimeInputs = with pkgs; [systemd libnotify];
    text = ''
      # Wait for PipeWire to be ready
      sleep 5

      # Start JARVIS service
      systemctl --user start jarvis.service

      notify-send -a "JARVIS" -i "dialog-information" "JARVIS" "Starting AI assistant..."
    '';
  };
in {
  options.services.jarvis-autostart = {
    enable = lib.mkEnableOption "JARVIS autostart";
  };

  config = lib.mkIf config.services.jarvis-autostart.enable {
    systemd.user.services.jarvis-autostart = {
      description = "JARVIS Autostart";
      wantedBy = ["graphical-session.target"];
      after = ["graphical-session.target"];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${jarvis-autostart}/bin/jarvis-autostart";
        RemainAfterExit = true;
      };
    };

    # JARVIS desktop entry
    xdg.desktopEntries.jarvis = {
      name = "JARVIS AI Assistant";
      comment = "Always-on AI assistant";
      exec = "systemctl --user start jarvis.service";
      icon = "dialog-information";
      terminal = false;
      categories = ["System" "Utility"];
    };
  };
}
