{
  lib,
  pkgs,
}: let
  outputSchema = pkgs.writeText "spark-corrector-response-schema.json" (
    builtins.readFile ./schema.json
  );
in
  pkgs.writeShellApplication {
    name = "spark-corrector";
    excludeShellChecks = ["SC2016"];
    runtimeInputs = with pkgs; [
      codex
      coreutils
      gtk3
      hyprland
      jq
      libnotify
      util-linux
      wl-clipboard
      wtype
      yad
      ydotool
    ];
    text = builtins.readFile (pkgs.replaceVars ./spark-corrector {
      inherit outputSchema;
    });
    meta = {
      description = "Polish and English proofreader powered exclusively by GPT-5.3-Codex-Spark";
      homepage = "https://github.com/grajpap/nixos_config";
      license = lib.licenses.mit;
      mainProgram = "spark-corrector";
      platforms = lib.platforms.linux;
    };
  }
