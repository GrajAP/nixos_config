{pkgs, ...}: let
  editorSettings = import ./editor-settings.nix;
in {
  home.packages = [pkgs.code-cursor];
  xdg.configFile."Cursor/User/settings.json".text = builtins.toJSON editorSettings;
}
