{pkgs}: let
  sparkCorrector = pkgs.callPackage ../spark-corrector/package.nix {};
  whisprflow = pkgs.callPackage ../whisprflow/package.nix {
    inherit sparkCorrector;
  };
in {
  inherit sparkCorrector whisprflow;
}
