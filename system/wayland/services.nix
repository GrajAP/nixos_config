{pkgs, ...}: {
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
