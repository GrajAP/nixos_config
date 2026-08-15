{
  inputs,
  pkgs,
  ...
}: let
  upstreamUserstyles = pkgs.fetchurl {
    url = "https://github.com/catppuccin/userstyles/releases/download/all-userstyles-export/import.json";
    hash = "sha256-+eqOt92dkNcnFK7L1jMrsMyOocxZXdbz1UdAOjZGsvw=";
  };

  stylusArchive = pkgs.fetchurl {
    url = "https://github.com/openstyles/stylus/releases/download/v2.4.5/stylus-chrome-mv3-v2.4.5-id.zip";
    hash = "sha256-j1A1Vz2DhLzZraay8N7A0fSRYWiWxEFMFumHaM/tk18=";
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

  stylusSeed = pkgs.replaceVars ./stylus-seed.js {
    seedVersion = "catppuccin-all-userstyles-p8sAd6BfPUtLicti";
  };

  stylusExtension =
    pkgs.runCommand "stylus-2.4.5-catppuccin-mocha-blue" {
      nativeBuildInputs = [pkgs.unzip];
    } ''
      mkdir -p "$out"
      unzip -q ${stylusArchive} -d "$out"
      install -m 0444 ${catppuccinMochaBlue} "$out/catppuccin-mocha-blue.json"
      install -m 0444 ${stylusSeed} "$out/nix-seed.js"
      chmod u+w "$out/sw.js"
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

  # Keep the generated export inspectable and available for recovery.
  xdg.dataFile."stylus/catppuccin-mocha-blue.json".source = catppuccinMochaBlue;
}
