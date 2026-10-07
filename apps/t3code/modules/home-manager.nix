# T3 Code for desktop hosts.
#
# Desktop profile of the flake: the wrapped AppImage launcher, the notify
# wrapper the shell aliases to `t3code`, and the timer that keeps the AppImage
# on the newest preview release. Everything the app needs at runtime is inside
# the wrapper; this module only decides what lands in the profile and which
# timers run.
#
# The session autostart lives with the compositor, in home/rice/hyprland, so
# there is one owner for it.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.t3code;
  t3code = pkgs.callPackage ../package.nix {};
in {
  options.t3code = {
    enable = lib.mkEnableOption "T3 Code desktop app, CLI and update timers";

    # Published into ~/.t3/userdata/themes, where `t3 theme` looks for it.
    # Applies to every client that follows this environment.
    theme = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Theme JSON to publish for this environment's T3 Code clients.";
    };

    updateInterval = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "30min";
      description = "How often to re-check for a newer AppImage. Null disables the timer.";
    };
  };

  config = lib.mkIf cfg.enable {
    home = {
      packages = [
        t3code.desktop
        t3code.notify
        t3code.theme
        t3code.connect
      ];

      # The AppImage runs inside appimage-run's FHS container, which does not
      # see /etc/ssl. Antigravity's ACP then fails every Gemini request with
      # SSL: CERTIFICATE_VERIFY_FAILED. The wrapper sets these too, but the shell
      # and the update timer do not go through the wrapper.
      sessionVariables = {
        SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        NIX_SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      };

      activation = lib.mkIf (cfg.theme != null) {
        t3codeTheme = lib.hm.dag.entryAfter ["writeBoundary"] ''
          mkdir -p "$HOME/.t3/userdata/themes"
          install -m 644 "${cfg.theme}" \
            "$HOME/.t3/userdata/themes/$(basename ${cfg.theme} .json).json"
        '';
      };
    };

    systemd.user = {
      services.t3code-update = {
        Unit.Description = "Download the newest preview T3 Code desktop build";
        Service = {
          Type = "oneshot";
          ExecStart = lib.getExe t3code.update;
        };
      };

      timers.t3code-update = lib.mkIf (cfg.updateInterval != null) {
        Unit.Description = "Keep T3 Code on the latest preview release";
        Timer = {
          OnStartupSec = "2min";
          OnUnitActiveSec = cfg.updateInterval;
          Persistent = true;
        };
        Install.WantedBy = ["timers.target"];
      };
    };
  };
}
