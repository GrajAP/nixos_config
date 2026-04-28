{
  pkgs,
  lib,
  ...
}: {
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
    profiles.default = {
      # ------------------------------------------------------------------
      # Extensions you need for Expo / React-Native development
      # ------------------------------------------------------------------
      extensions = with pkgs.vscode-extensions; [
        # Nix support (your original extension)
        jnoortheen.nix-ide
        catppuccin.catppuccin-vsc-icons
        # JavaScript / TypeScript / React-Native
        #ms-vscode.vscode-typescript-next
        bradlc.vscode-tailwindcss
        prettier.prettier-vscode
        dbaeumer.vscode-eslint
        naumovs.color-highlight

        ms-vsliveshare.vsliveshare
        ms-vscode.live-server
        ms-ceintl.vscode-language-pack-pl
        vscodevim.vim
        hars.cppsnippets
        # JSON / workspace
        redhat.vscode-yaml
        #ms-vscode.vscode-json
      ];

      # ------------------------------------------------------------------
      # User-level VS Code settings
      # ------------------------------------------------------------------
      userSettings = {
        # --- Nix IDE (your original block) ------------------------------
        "nix.serverPath" = "nixd";
        "nix.enableLanguageServer" = true;
        "nix.serverSettings" = {
          nixd = {
            formatting.command = ["alejandra"];

            options = {
              nixos.expr = "import <nixpkgs> { }";
              home_manager.expr = "import <nixpkgs> { }";
            };
          };
        };

        # --- Editor basics ---------------------------------------------
        "editor.formatOnSave" = true;
        "workbench.sideBar.location" = "right";
        "editor.codeActionsOnSave" = {
          "source.fixAll.eslint" = true;
        };
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
        "editor.tabSize" = 2;
        "editor.insertSpaces" = true;

        # --- TypeScript -------------------------------------------------
        "typescript.updateImportsOnFileMove.enabled" = "always";
        "typescript.preferences.importModuleSpecifier" = "relative";

        # --- ESLint ----------------------------------------------------
        "eslint.validate" = [
          "javascript"
          "javascriptreact"
          "typescript"
          "typescriptreact"
        ];

        # --- Prettier ---------------------------------------------------
        "prettier.requireConfig" = true; # only format if config file exists
        "[javascript]" = {"editor.defaultFormatter" = "esbenp.prettier-vscode";};
        "[javascriptreact]" = {"editor.defaultFormatter" = "esbenp.prettier-vscode";};
        "[typescript]" = {"editor.defaultFormatter" = "esbenp.prettier-vscode";};
        "[typescriptreact]" = {"editor.defaultFormatter" = "esbenp.prettier-vscode";};

        # --- React-Native tools ----------------------------------------
        "react-native.showUserTips" = false;
        "react-native.packager.port" = 8081;

        "workbench.iconTheme" = "catppuccin-vsc-icons";
        "editor.fontFamily" = lib.mkForce "JetBrainsMono Nerd Font, monospace";
        "editor.fontLigatures" = true;
        "terminal.integrated.fontFamily" = lib.mkForce "JetBrainsMono Nerd Font, monospace";
      };
    };
  };
}
