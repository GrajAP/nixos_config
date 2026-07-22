{pkgs, ...}: let
  voiceSuite = pkgs.callPackage ../../apps/voice-suite/package.nix {};
in {
  home.packages = [
    voiceSuite.sparkCorrector
    voiceSuite.whisprflow
  ];
}
