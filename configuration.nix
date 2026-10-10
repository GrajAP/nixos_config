{
  inputs,
  config,
  lib,
  ...
}: {
  imports = [
    ./system
    ./theme
  ];

  options.fleet = {
    heavy.enable = lib.mkEnableOption "PC-only heavy extras (gaming, Android Studio, hosting)";

    breaks = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether the quickshell break timer runs and is offered in the shutdown
        widget.

        On by default: the timer arms itself on every shell start and rings a
        notification every 30 minutes. That is fine on a gaming PC and nagging on
        a laptop, so dell turns it off.
      '';
    };

    calendarHeader = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether the quickshell calendar page keeps its title bar and date line.

        On by default. dell's panel is 864 logical px tall, where those two rows
        come straight out of the month grid's height and the sixth week row ends
        up below the panel edge.
      '';
    };

    autostart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether the session autostarts any application.

        The applications (signal, ferdium, helium, kdeconnect, t3code, the
        NetworkManager applet) are delayed systemd user units wanted by
        graphical-session.target. dell turns them all off and boots to a bare
        session, where each app is started by hand.
      '';
    };

    wifiRandomMac = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether NetworkManager sets a random MAC on wifi scans.

        Fine for home wifi, fatal for eduroam: EAP-TTLS authenticates the
        station's hardware address, and a randomized one is rejected before
        any credential is even looked at. dell carries the `eduroam` script
        (home/scripts/eduroam), so it turns this off.
      '';
    };

    displayScale = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 100;
      description = ''
        Hyprland scale for outputs not matched by an explicit monitor rule,
        as a percentage.

        The PC keeps its two 2560x1440 panels at scale 100 and names them
        explicitly, so this only governs the catch-all fallback. A 14" 1920x1080
        laptop panel is about 141 PPI at scale 100, which is far too dense to
        read, so dell sets a higher value.
      '';
    };
  };

  config = {
    stylix.enableReleaseChecks = false;

    home-manager = {
      backupFileExtension = "hm-backup";
      extraSpecialArgs = {
        inherit inputs;
        heavy = config.fleet.heavy.enable;
        # home-manager modules cannot read NixOS options directly, so the
        # per-host fallback scale, break-timer switch, calendar chrome and
        # autostart switch are passed in the same way `heavy` is.
        inherit (config.fleet) displayScale breaks calendarHeader autostart;
      };
      useGlobalPkgs = true;
      useUserPackages = true;
      users.grajpap = {
        home.stateVersion = "24.11";
        home.enableNixpkgsReleaseCheck = false;
        imports = [
          ./home
        ];
      };
    };
  };
}
