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
