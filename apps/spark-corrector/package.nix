{
  lib,
  pkgs,
}: let
  reviewOutputSchema = pkgs.writeText "spark-corrector-response-schema.json" (
    builtins.readFile ./schema.json
  );
  compactOutputSchema = pkgs.writeText "spark-corrector-compact-schema.json" (
    builtins.readFile ./compact-schema.json
  );
  whisprflowContext = pkgs.writeText "spark-corrector-whisprflow-context.md" (
    builtins.readFile ./whisprflow-context.md
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
      inherit compactOutputSchema reviewOutputSchema whisprflowContext;
    });
    meta = {
      description = "Polish and English proofreader powered exclusively by GPT-5.3-Codex-Spark";
      homepage = "https://github.com/grajpap/nixos_config";
      license = lib.licenses.mit;
      mainProgram = "spark-corrector";
      platforms = lib.platforms.linux;
    };
  }
