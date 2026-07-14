{pkgs, ...}: let
  editorSettings = import ./editor-settings.nix;
  catppuccinTheme = pkgs.vscode-extensions.catppuccin.catppuccin-vsc;
  catppuccinIcons = pkgs.vscode-extensions.catppuccin.catppuccin-vsc-icons;
in {
  home.packages = [pkgs.code-cursor];

  # Keep Cursor's extension directory mutable while making the selected theme
  # available declaratively.
  home.file = {
    ".cursor/extensions/catppuccin-theme-nix".source = "${catppuccinTheme}/share/vscode/extensions/catppuccin.catppuccin-vsc";
    ".cursor/extensions/catppuccin-icons-nix".source = "${catppuccinIcons}/share/vscode/extensions/catppuccin.catppuccin-vsc-icons";
  };

  xdg.configFile."Cursor/User/settings.json".text = builtins.toJSON editorSettings;
}
