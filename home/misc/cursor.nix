{
  lib,
  pkgs,
  ...
}: let
  editorSettings = import ./editor-settings.nix;
  catppuccinTheme = pkgs.vscode-extensions.catppuccin.catppuccin-vsc;
  catppuccinIcons = pkgs.vscode-extensions.catppuccin.catppuccin-vsc-icons;
in {
  home.packages = [pkgs.code-cursor];

  # Catppuccin generates theme files when Cursor starts, so these extensions
  # must be writable rather than symlinked directly into the Nix store.
  home.activation.cursorCatppuccinExtensions = lib.hm.dag.entryAfter ["writeBoundary"] ''
    extension_dir="$HOME/.cursor/extensions"
    mkdir -p "$extension_dir"

    install_cursor_extension() {
      source="$1"
      target="$extension_dir/$2"
      temporary="$target.tmp"

      rm -rf "$temporary"
      mkdir -p "$temporary"
      cp -R "$source"/. "$temporary"/
      chmod -R u+w "$temporary"
      rm -rf "$target"
      mv "$temporary" "$target"
    }

    install_cursor_extension \
      "${catppuccinTheme}/share/vscode/extensions/catppuccin.catppuccin-vsc" \
      "catppuccin-theme-nix"
    install_cursor_extension \
      "${catppuccinIcons}/share/vscode/extensions/catppuccin.catppuccin-vsc-icons" \
      "catppuccin-icons-nix"
  '';

  xdg.configFile."Cursor/User/settings.json".text = builtins.toJSON editorSettings;
}
