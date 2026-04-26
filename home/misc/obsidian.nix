{...}: {
  home.file = {
    ".config/obsidian/obsidian.json" = {
      text = builtins.toJSON {
        vaults = {
          "a1dd4927315f80b0" = {
            path = "/home/grajpap/other/Obsidian Vault";
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
