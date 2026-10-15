{pkgs}: {
  helper = pkgs.writeShellApplication {
    name = "t3-running-count";
    runtimeInputs = [pkgs.python3];
    text = ''
      exec python3 ${./running-count.py} "$@"
    '';
  };

  gate = pkgs.writeShellApplication {
    name = "t3-gate";
    runtimeInputs = [pkgs.python3 pkgs.openssh];
    text = ''
      exec python3 ${./gate.py} "$@"
    '';
  };

  extension = pkgs.callPackage ./extension.nix {};
}
