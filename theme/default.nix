{pkgs, ...}: let
  wall = ./nix-black-4k.png;
in {
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

    targets.kmscon.enable = false;
    # We use tuigreet via greetd, not regreet. Disabling also avoids
    # stylix setting the obsolete programs.regreet options (nixpkgs
    # renamed them to services.displayManager.regreet), which prints
    # a trace on every flake check.
    targets.regreet.enable = false;

    opacity = {
      applications = 1.0;
      terminal = 0.8;
      desktop = 1.0;
      popups = 0.8;
    };
  };
}
