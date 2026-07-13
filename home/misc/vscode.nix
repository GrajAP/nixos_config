{
  lib,
  pkgs,
  ...
}: let
  editorSettings = import ./editor-settings.nix;
in {
  programs.vscode = {
    enable = true;
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        bradlc.vscode-tailwindcss
        catppuccin.catppuccin-vsc-icons
        dbaeumer.vscode-eslint
        hars.cppsnippets
        jnoortheen.nix-ide
        ms-ceintl.vscode-language-pack-pl
        ms-vscode.live-server
        ms-vsliveshare.vsliveshare
        naumovs.color-highlight
        prettier.prettier-vscode
        redhat.vscode-yaml
        vscodevim.vim
      ];
      userSettings =
        editorSettings
        // {
          "editor.fontFamily" = lib.mkForce editorSettings."editor.fontFamily";
          "terminal.integrated.fontFamily" = lib.mkForce editorSettings."terminal.integrated.fontFamily";
        };
    };
  };
}
