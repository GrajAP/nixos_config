{pkgs, ...}: {
  home.packages = [
    (pkgs.callPackage ../../apps/whisprflow/package.nix {})
  ];
}
