{
  lib,
  pkgs,
  ...
}: let
  editorSettings = import ./editor-settings.nix;
  editorExtensions = import ./editor-extensions.nix {inherit pkgs;};
  catppuccinTheme = pkgs.vscode-extensions.catppuccin.catppuccin-vsc;
  cursorSettings = pkgs.writeText "cursor-settings.json" (builtins.toJSON editorSettings);

  catppuccinWorkbenchCss =
    pkgs.runCommand "cursor-catppuccin-mocha-blue.css" {
      nativeBuildInputs = [pkgs.jq];
    } ''
      {
        printf ':root, body, .monaco-workbench, .monaco-workbench.vs, .monaco-workbench.vs-dark {\n'
        printf '  color-scheme: dark !important;\n'
        sed 's/#cba6f7/#89b4fa/g' \
          ${catppuccinTheme}/share/vscode/extensions/catppuccin.catppuccin-vsc/themes/mocha.json \
          | jq -r '.colors | to_entries[] | "  --vscode-\(.key | gsub("\\."; "-")): \(.value) !important;"'
        printf '}\n'
        printf 'html, body, .monaco-workbench { background-color: #1e1e2e !important; color: #cdd6f4 !important; }\n'
      } > "$out"
    '';

  cursorCatppuccin =
    pkgs.runCommand "${pkgs.code-cursor.pname}-${pkgs.code-cursor.version}-catppuccin-mocha-blue" {
      meta = pkgs.code-cursor.meta;
    } ''
      mkdir -p "$out"
      cp -a ${pkgs.code-cursor}/. "$out"/

      chmod u+w "$out/bin/cursor"
      substituteInPlace "$out/bin/cursor" \
        --replace-fail "${pkgs.code-cursor}" "$out"

      for stylesheet in \
        "$out/lib/cursor/resources/app/out/vs/workbench/workbench.desktop.main.css" \
        "$out/lib/cursor/resources/app/out/vs/workbench/workbench.glass.main.css"; do
        chmod u+w "$stylesheet"
        printf '\n' >> "$stylesheet"
        cat ${catppuccinWorkbenchCss} >> "$stylesheet"
      done
    '';
in {
  home.packages = [cursorCatppuccin];

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
