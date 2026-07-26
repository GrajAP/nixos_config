{pkgs, ...}: {
  security.pam.services.greetd = {
    enableGnomeKeyring = true;
    # Fingerprint and automatic login do not provide the password that
    # pam_gnome_keyring needs to unlock login.keyring.
    fprintAuth = false;
  };

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
      useTextGreeter = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --asterisks --cmd '${pkgs.uwsm}/bin/uwsm start -e -D Hyprland hyprland.desktop'";
          user = "greeter";
        };
      };
    };

    gnome.glib-networking.enable = true;
    # Nextcloud uses Secret Service to persist its app password between logins.
    gnome.gnome-keyring.enable = true;
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
