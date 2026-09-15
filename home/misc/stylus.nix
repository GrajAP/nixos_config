{
  inputs,
  pkgs,
  ...
}: let
  upstreamUserstyles = pkgs.fetchurl {
    url = "https://github.com/catppuccin/userstyles/releases/download/all-userstyles-export/import.json";
    hash = "sha256-kPWI8G5P0CsT6rI/MB6GzpoPTw9rTOAgmj1ASLcjhd4=";
  };

  stylusArchive = pkgs.fetchurl {
    url = "https://github.com/openstyles/stylus/releases/download/v2.4.5/stylus-chrome-mv3-v2.4.5-id.zip";
    hash = "sha256-j1A1Vz2DhLzZraay8N7A0fSRYWiWxEFMFumHaM/tk18=";
  };

  gmailProtonComplement = ./gmail-catppuccin.user.less;
  ferdiumCatppuccin = ./ferdium-catppuccin.user.less;

  discordCss = pkgs.fetchurl {
    url = "https://catppuccin.github.io/discord/dist/catppuccin-mocha-blue.theme.css";
    hash = "sha256-KVv9vfqI+WADn3w4yE1eNsmtm7PQq9ugKiSL3EOLheI=";
  };

  catppuccinMochaBlue =
    pkgs.runCommand "catppuccin-mocha-blue-stylus.json" {
      nativeBuildInputs = [pkgs.jq];
    } ''
      jq '
        .[0].settings.updateInterval = 24
        | .[0].settings.updateOnlyEnabled = false
        | .[0].settings.patchCsp = true
        | map(
            if .usercssData.vars? then
              if .usercssData.vars.lightFlavor? then
                .usercssData.vars.lightFlavor.value = "mocha"
              else . end
              | if .usercssData.vars.darkFlavor? then
                .usercssData.vars.darkFlavor.value = "mocha"
              else . end
              | if .usercssData.vars.accentColor? then
                .usercssData.vars.accentColor.value = "blue"
              else . end
            else . end
          )
      ' ${upstreamUserstyles} > "$out"
    '';

  customUserstyles = pkgs.runCommand "custom-catppuccin-userstyles.json" {nativeBuildInputs = [pkgs.jq];} ''
        # Wrap Discord CSS in a UserCSS shell via file ops (avoids ARG_MAX overflow)
        discord_usercss=$(mktemp)
        cat > "$discord_usercss" <<'HEADER'
    /* ==UserStyle==
    @name           Discord Catppuccin (Mocha Blue)
    @namespace      github.com/catppuccin/discord
    @version        2026.09.15
    @description    Soothing pastel theme for Discord
    @author         Catppuccin
    @license        MIT
    @preprocessor   stylus
    ==/UserStyle== */

    @-moz-document regexp("https?://(canary\\.|ptb\\.|)discord.com/.*") {
    HEADER
        cat ${discordCss} >> "$discord_usercss"
        echo "}" >> "$discord_usercss"

        jq -n \
          --rawfile gmail ${gmailProtonComplement} \
          --rawfile ferdium ${ferdiumCatppuccin} \
          --rawfile discord "$discord_usercss" \
          '[
            {
              "name": "Gmail Catppuccin Proton Complement",
              "enabled": true,
              "updateUrl": "nix://gmail-catppuccin-proton-complement",
              "usercssData": {
                "vars": {
                  "lightFlavor": { "default": "latte", "value": "mocha" },
                  "darkFlavor": { "default": "mocha", "value": "mocha" },
                  "accentColor": { "default": "mauve", "value": "blue" }
                }
              },
              "sections": [{
                "code": $gmail,
                "default": true,
                "domains": ["mail.google.com"],
                "exclusionRules": [],
                "include": ["https://mail.google.com/*"],
                "name": "Gmail Catppuccin Proton Complement"
              }]
            },
            {
              "name": "Ferdium Catppuccin",
              "enabled": true,
              "updateUrl": "nix://ferdium-catppuccin",
              "usercssData": {
                "vars": {
                  "lightFlavor": { "default": "latte", "value": "mocha" },
                  "darkFlavor": { "default": "mocha", "value": "mocha" },
                  "accentColor": { "default": "mauve", "value": "blue" }
                }
              },
              "sections": [{
                "code": $ferdium,
                "default": true,
                "domains": [],
                "exclusionRules": [],
                "include": ["ferdium://*", "https://app.ferdium.org/*"],
                "name": "Ferdium Catppuccin"
              }]
            },
            {
              "name": "Discord Catppuccin (Mocha Blue)",
              "enabled": true,
              "updateUrl": "nix://discord-catppuccin-mocha-blue",
              "usercssData": {
                "vars": {
                  "theme": { "default": "mocha", "value": "mocha" },
                  "accent": { "default": "blue", "value": "blue" }
                }
              },
              "sections": [{
                "code": $discord,
                "default": true,
                "domains": [],
                "exclusionRules": [],
                "include": ["https://discord.com/*", "https://canary.discord.com/*", "https://ptb.discord.com/*"],
                "name": "Discord Catppuccin (Mocha Blue)"
              }]
            }
          ]' > "$out"
  '';

  stylusSeed = pkgs.replaceVars ./stylus-seed.js {
    seedVersion = "catppuccin-all-userstyles-2026-v3-discord";
  };

  stylusExtension =
    pkgs.runCommand "stylus-2.4.5-catppuccin-mocha-blue" {
      nativeBuildInputs = [pkgs.unzip];
    } ''
      mkdir -p "$out"
      unzip -q ${stylusArchive} -d "$out"
      install -m 0444 ${catppuccinMochaBlue} "$out/catppuccin-mocha-blue.json"
      install -m 0444 ${customUserstyles} "$out/custom-userstyles.json"
      install -m 0444 ${stylusSeed} "$out/nix-seed.js"
      chmod u+w "$out/sw.js" "$out/js/worker.js"
      sed -i 's/then(code)/then(() => code)/g' "$out/js/worker.js"
      sed -i '$a importScripts("nix-seed.js");' "$out/sw.js"
    '';

  helium = inputs.helium-browser.packages."${pkgs.stdenv.hostPlatform.system}".helium;
  heliumWithStylus = pkgs.symlinkJoin {
    name = "helium-with-stylus-catppuccin";
    paths = [helium];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram "$out/bin/helium" \
        --add-flags "--disable-gtk-ime" \
        --add-flags "--load-extension=${stylusExtension}"
    '';
  };
in {
  home.packages = [heliumWithStylus];

  xdg.dataFile."stylus/catppuccin-mocha-blue.json".source = catppuccinMochaBlue;
  xdg.dataFile."stylus/custom-catppuccin-userstyles.json".source = customUserstyles;
}
