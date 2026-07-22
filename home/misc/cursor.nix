{
  lib,
  pkgs,
  ...
}: let
  editorSettings = import ./editor-settings.nix;
  editorExtensions = import ./editor-extensions.nix {inherit pkgs;};
  cursorSettings = pkgs.writeText "cursor-settings.json" (builtins.toJSON editorSettings);
in {
  # Keep Cursor's application files untouched so its integrity check passes.
  # Catppuccin is applied through the extension and editor settings below.
  home.packages = [pkgs.code-cursor];

  # Cursor and Catppuccin write extension-local state, so install writable
  # copies instead of pointing Cursor directly at the Nix store.
  home.activation.cursorConfiguration = lib.hm.dag.entryAfter ["writeBoundary"] ''
    extension_dir="$HOME/.cursor/extensions"
    temporary_dir="$HOME/.cache/nix-cursor-extensions"
    mkdir -p "$extension_dir"
    rm -rf "$temporary_dir"
    mkdir -p "$temporary_dir"

    install_cursor_extension_package() {
      source="$1"
      extension_id="$(basename "$source")"
      target="$extension_dir/$extension_id-nix"
      temporary="$temporary_dir/$extension_id-nix"

      shopt -s nocaseglob
      for existing in \
        "$extension_dir/$extension_id" \
        "$extension_dir/$extension_id"-*; do
        if [[ -e "$existing" || -L "$existing" ]]; then
          rm -rf "$existing"
        fi
      done
      shopt -u nocaseglob

      mkdir -p "$temporary"
      cp -R "$source"/. "$temporary"/
      chmod -R u+w "$temporary"
      rm -rf "$target"
      mv "$temporary" "$target"
    }

    # Remove the two names used by the previous Catppuccin-only activation.
    rm -rf \
      "$extension_dir/catppuccin-theme-nix" \
      "$extension_dir/catppuccin-icons-nix"

    for package in ${lib.escapeShellArgs editorExtensions}; do
      for source in "$package"/share/vscode/extensions/*; do
        if [[ -d "$source" ]]; then
          install_cursor_extension_package "$source"
        fi
      done
    done

    settings_dir="$HOME/.config/Cursor/User"
    settings_target="$settings_dir/settings.json"
    settings_temporary="$temporary_dir/settings.json"
    mkdir -p "$settings_dir"
    cp ${cursorSettings} "$settings_temporary"
    chmod u+w "$settings_temporary"
    rm -f "$settings_target"
    mv "$settings_temporary" "$settings_target"

    rmdir "$temporary_dir"
  '';
}
