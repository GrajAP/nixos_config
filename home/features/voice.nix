{pkgs, ...}: let
  whisprflow = pkgs.callPackage ../../apps/whisprflow/package.nix {};
in {
  home.packages = [
    whisprflow
  ];
}
