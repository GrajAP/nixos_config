{
  "nix.serverPath" = "nixd";
  "nix.enableLanguageServer" = true;
  "nix.serverSettings" = {
    nixd = {
      formatting.command = ["alejandra"];
      options = {
        nixos.expr = ''(builtins.getFlake "/etc/nixos").nixosConfigurations.grajpap.options'';
        "home-manager".expr = ''(builtins.getFlake "/etc/nixos").nixosConfigurations.grajpap.options.home-manager.users.type.getSubOptions []'';
      };
    };
  };

  "editor.formatOnSave" = true;
  "workbench.sideBar.location" = "right";
  "editor.codeActionsOnSave"."source.fixAll.eslint" = "explicit";
  "editor.defaultFormatter" = "esbenp.prettier-vscode";
  "editor.tabSize" = 2;
  "editor.insertSpaces" = true;
  "editor.fontFamily" = "JetBrainsMono Nerd Font, monospace";
  "editor.fontLigatures" = true;
  "terminal.integrated.fontFamily" = "JetBrainsMono Nerd Font, monospace";

  "workbench.colorTheme" = "Catppuccin Mocha";
  "workbench.iconTheme" = "catppuccin-mocha";
  "catppuccin.accentColor" = "blue";

  "typescript.updateImportsOnFileMove.enabled" = "always";
  "typescript.preferences.importModuleSpecifier" = "relative";
  "eslint.validate" = [
    "javascript"
    "javascriptreact"
    "typescript"
    "typescriptreact"
  ];

  "prettier.requireConfig" = true;
  "[javascript]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
  "[javascriptreact]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
  "[typescript]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
  "[typescriptreact]"."editor.defaultFormatter" = "esbenp.prettier-vscode";

  "react-native.showUserTips" = false;
  "react-native.packager.port" = 8081;
}
