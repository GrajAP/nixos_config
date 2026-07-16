{pkgs, ...}: {
  home.packages = [
    (pkgs.callPackage ../../apps/spark-corrector/package.nix {})
    (pkgs.callPackage ../../apps/whisprflow/package.nix {})
  ];
}
