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
  gtk.gtk4.theme.name = config.gtk.theme.name;
  imports = [
    ./packages.nix
    ./cli
    ./features
    ./scripts
    ./rice
    ./misc
  ];
}
