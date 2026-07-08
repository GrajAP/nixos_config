{
  pkgs,
  config,
  lib,
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
  home.pointerCursor = {
    package = lib.mkForce pkgs.catppuccin-cursors.mochaBlue;
    name = lib.mkForce "catppuccin-mocha-blue-cursors";
    size = lib.mkForce 24;
    gtk.enable = true;
    x11.enable = true;
  };
  home.packages = [
    pkgs.catppuccin-cursors.mochaBlue
  ];
  home.sessionVariables = {
    XCURSOR_THEME = "catppuccin-mocha-blue-cursors";
    XCURSOR_SIZE = "24";
    HYPRCURSOR_THEME = "catppuccin-mocha-blue-cursors";
    HYPRCURSOR_SIZE = "24";
  };
  gtk.gtk4.theme.name = config.gtk.theme.name;
  imports = [
    # Core package surfaces shared across app, shell, and desktop config
    ./packages.nix
    # CLI tooling and shell UX
    ./cli
    # App-level feature collections (productivity, dev, media, voice, etc.)
    ./features
    # App-specific desktop config and tools
    ./misc
    # Helper scripts and rice config
    ./scripts
    ./rice
  ];
}
