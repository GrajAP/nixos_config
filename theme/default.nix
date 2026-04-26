{
  pkgs,
  lib,
  ...
}: let
  wall = ./nix-black-4k.png;
  mkService = lib.recursiveUpdate {
    Unit.PartOf = ["graphical-session.target"];
    Unit.After = ["graphical-session.target"];
    Install.WantedBy = ["graphical-session.target"];
  };
in {
  home-manager.users.grajpap.systemd.user.services = {
    swaybg = mkService {
      Unit.Description = "Wallpaper chooser";
      Service = {
        ExecStart = "${lib.getExe pkgs.swaybg} -i ${wall}";
        Restart = "always";
      };
    };
  };

  stylix = {
    enable = true;
    autoEnable = true;
    #base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    base16Scheme = ./theme.yaml;
    polarity = "dark";
    cursor = {
      package = pkgs.catppuccin-cursors.mochaBlue;
      name = "catppuccin-mocha-blue-cursors";
      size = 24;
    };
    image = wall;

    opacity = {
      applications = 1.0;
      terminal = 0.8;
      desktop = 1.0;
      popups = 0.8;
    };
  };
}
