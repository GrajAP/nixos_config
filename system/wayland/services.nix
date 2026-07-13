{pkgs, ...}: {
  services = {
    pulseaudio.enable = false;
    openssh = {
      enable = true;
      openFirewall = false;
      settings = {
        AllowUsers = ["grajpap"];
        KbdInteractiveAuthentication = false;
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
    greetd = {
      enable = true;
      settings = rec {
        initial_session = {
          command = "${pkgs.uwsm}/bin/uwsm start -e -D Hyprland hyprland.desktop";
          user = "grajpap";
        };
        default_session = initial_session;
      };
    };

    gnome.glib-networking.enable = true;
    logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "lock";
    };

    udisks2.enable = true;
    gvfs.enable = true;
    printing.enable = true;
    fstrim.enable = true;
  };
}
