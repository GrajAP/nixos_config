{
  config,
  pkgs,
  ...
}: let
  obsidianWrapped = pkgs.symlinkJoin {
    name = "obsidian-wrapped";
    paths = [pkgs.obsidian];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/obsidian \
        --set ELECTRON_OVERRIDE_DIST_PATH ${pkgs.obsidian}/lib/obsidian/resources
    '';
  };

  catppuccin = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "obsidian";
    rev = "7ebbd577464d6ef8a18cb02811983bee623f30d6";
    hash = "sha256-9IwQsXFf63/R27xazFKzkVhPSgTnlYtNzb9uUY3WRa8=";
  };

  vault = "Nextcloud/Notes/.obsidian";
in {
  home.packages = [obsidianWrapped];

  home.file = {
    # Nextcloud skips .obsidian (see nextcloud-sync-exclude.lst), so these
    # links stay on each device and never reach the server or the phone.
    ".config/Nextcloud/sync-exclude.lst" = {
      source = ./nextcloud-sync-exclude.lst;
      force = true;
    };

    "${vault}/themes/Catppuccin/theme.css" = {
      source = "${catppuccin}/theme.css";
      force = true;
    };
    "${vault}/themes/Catppuccin/manifest.json" = {
      source = "${catppuccin}/manifest.json";
      force = true;
    };

    # The theme only picks an accent through the Style Settings plugin.
    "${vault}/snippets/catppuccin-blue.css".text = ''
      body.theme-dark,
      body.theme-light {
        --ctp-accent: var(--ctp-blue);
        --accent-h: 217;
        --accent-s: 92%;
        --accent-l: 76%;
      }
    '';

    "${vault}/appearance.json" = {
      text = builtins.toJSON {
        theme = "obsidian";
        cssTheme = "Catppuccin";
        enabledCssSnippets = ["catppuccin-blue"];
        accentColor = "#89b4fa";
        interfaceFontFamily = "Lexend";
        textFontFamily = "Lexend";
        monospaceFontFamily = "Maple Mono NF";
      };
      force = true;
    };

    ".config/obsidian/obsidian.json" = {
      text = builtins.toJSON {
        vaults = {
          "a1dd4927315f80b0" = {
            path = "${config.home.homeDirectory}/Nextcloud/Notes";
            ts = 1769436944861;
            open = true;
          };
        };
      };
      force = true;
    };

    ".config/obsidian/Preferences" = {
      text = builtins.toJSON {
        browser = {
          enable_spellchecking = true;
        };
        migrated_user_scripts_toggle = true;
        partition = {
          per_host_zoom_levels = {
            "15446275347784660674" = {};
          };
        };
        spellcheck = {
          dictionaries = ["en-US" "pl"];
          dictionary = "";
        };
      };
      force = true;
    };
  };
}
