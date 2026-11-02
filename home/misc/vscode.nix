{
  lib,
  pkgs,
  ...
}: let
  extensions =
    (with pkgs.vscode-extensions; [
      bradlc.vscode-tailwindcss
      catppuccin.catppuccin-vsc
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
    ])
    ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
      {
        name = "vscode-expo-tools";
        publisher = "expo";
        version = "1.6.3";
        sha256 = "sha256-vqT/72pUyHtzl0rmUfDgbr7MO+/2dw3EcDeYTkQY/0Y=";
      }
      {
        name = "vscode-react-native";
        publisher = "msjsdiag";
        version = "1.13.0";
        sha256 = "sha256-zryzoO9sb1+Kszwup5EhnN/YDmAPz7TOQW9I/K28Fmg=";
      }
    ];

  formatter = "prettier.prettier-vscode";
  settings = pkgs.writeText "vscode-settings.json" (builtins.toJSON {
    "nix.serverPath" = "nixd";
    "nix.enableLanguageServer" = true;
    "nix.serverSettings".nixd = {
      formatting.command = ["alejandra"];
      options = {
        nixos.expr = ''(builtins.getFlake "/etc/nixos").nixosConfigurations.grajpap.options'';
        "home-manager".expr = ''(builtins.getFlake "/etc/nixos").nixosConfigurations.grajpap.options.home-manager.users.type.getSubOptions []'';
      };
    };

    "editor.formatOnSave" = true;
    "editor.codeActionsOnSave"."source.fixAll.eslint" = "explicit";
    "editor.defaultFormatter" = formatter;
    "editor.tabSize" = 2;
    "editor.insertSpaces" = true;
    "editor.fontFamily" = "JetBrainsMono Nerd Font, monospace";
    "editor.fontLigatures" = true;
    "terminal.integrated.fontFamily" = "JetBrainsMono Nerd Font, monospace";
    "workbench.sideBar.location" = "right";

    "workbench.colorTheme" = "Catppuccin Mocha";
    "workbench.iconTheme" = "catppuccin-mocha";
    "catppuccin.accentColor" = "blue";

    "typescript.updateImportsOnFileMove.enabled" = "always";
    "typescript.preferences.importModuleSpecifier" = "relative";
    "eslint.validate" = ["javascript" "javascriptreact" "typescript" "typescriptreact"];
    "prettier.requireConfig" = true;

    "react-native.showUserTips" = false;
    "react-native.packager.port" = 8081;
  });
in {
  home.packages = [pkgs.vscode];

  # Catppuccin rewrites its own theme files for a non-default accent, which
  # fails on a read-only store path. So extensions and settings are installed as
  # writable copies instead of through programs.vscode.
  home.activation.vscodeConfiguration = lib.hm.dag.entryAfter ["writeBoundary"] ''
    extension_dir="$HOME/.vscode/extensions"
    settings_file="$HOME/.config/Code/User/settings.json"
    mkdir -p "$extension_dir" "$(dirname "$settings_file")"

    shopt -s nocaseglob
    for package in ${lib.escapeShellArgs extensions}; do
      for source in "$package"/share/vscode/extensions/*; do
        id="$(basename "$source")"
        rm -rf "$extension_dir/$id" "$extension_dir/$id"-*
        cp -R "$source" "$extension_dir/$id"
        chmod -R u+w "$extension_dir/$id"
      done
    done
    shopt -u nocaseglob

    rm -f "$settings_file"
    install -m644 ${settings} "$settings_file"
  '';
}
