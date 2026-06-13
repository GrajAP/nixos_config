{
  pkgs,
  lib,
  ...
}: {
  programs.vscode = {
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        jnoortheen.nix-ide
        catppuccin.catppuccin-vsc-icons
        bradlc.vscode-tailwindcss
        prettier.prettier-vscode
        dbaeumer.vscode-eslint
        naumovs.color-highlight
        ms-vsliveshare.vsliveshare
        ms-vscode.live-server
        ms-ceintl.vscode-language-pack-pl
        vscodevim.vim
        hars.cppsnippets
        redhat.vscode-yaml
      ];

      userSettings = {
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

        "editor.formatOnSave" = true;
        "workbench.sideBar.location" = "right";
        "editor.codeActionsOnSave" = {
          "source.fixAll.eslint" = true;
        };
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
        "editor.tabSize" = 2;
        "editor.insertSpaces" = true;

        "typescript.updateImportsOnFileMove.enabled" = "always";
        "typescript.preferences.importModuleSpecifier" = "relative";

        "eslint.validate" = [
          "javascript"
          "javascriptreact"
          "typescript"
          "typescriptreact"
        ];

        "prettier.requireConfig" = true;
        "[javascript]" = {"editor.defaultFormatter" = "esbenp.prettier-vscode";};
        "[javascriptreact]" = {"editor.defaultFormatter" = "esbenp.prettier-vscode";};
        "[typescript]" = {"editor.defaultFormatter" = "esbenp.prettier-vscode";};
        "[typescriptreact]" = {"editor.defaultFormatter" = "esbenp.prettier-vscode";};

        "react-native.showUserTips" = false;
        "react-native.packager.port" = 8081;

        "workbench.iconTheme" = "catppuccin-vsc-icons";
        "editor.fontFamily" = lib.mkForce "JetBrainsMono Nerd Font, monospace";
        "editor.fontLigatures" = true;
        "terminal.integrated.fontFamily" = lib.mkForce "JetBrainsMono Nerd Font, monospace";
      };
    };
  };

  home.packages = [pkgs.code-cursor];
}
