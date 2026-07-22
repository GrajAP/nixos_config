{
  lib,
  pkgs,
  ...
}: let
  editorSettings = import ./editor-settings.nix;
  editorExtensions = import ./editor-extensions.nix {inherit pkgs;};
in {
  programs.vscode = {
    # Keep the configuration available, but prefer Cursor as the active editor.
    enable = false;
    profiles.default = {
      extensions = editorExtensions;
      userSettings =
        editorSettings
        // {
          "editor.fontFamily" = lib.mkForce editorSettings."editor.fontFamily";
          "terminal.integrated.fontFamily" = lib.mkForce editorSettings."terminal.integrated.fontFamily";
        };
    };
  };
}
