{
  pkgs,
  config,
  ...
}: {
  stylix = {
    enable = true;
    icons = {
      enable = true;
      package = pkgs.catppuccin-papirus-folders;
      dark = "Papirus-Dark";
      light = "Papirus-Dark";
    };
  };
  gtk.gtk4.theme = config.gtk.theme;
  home.stateVersion = "24.11";
  imports = [
    ./packages.nix
    ./cli
    ./features
    ./scripts
    ./rice
    ./misc
  ];
}
