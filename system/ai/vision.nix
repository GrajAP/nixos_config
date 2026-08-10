{pkgs, ...}: let
  visionPython = pkgs.python3.withPackages (ps: [
    ps.opencv4
    ps.pillow
    ps.numpy
    ps.requests
  ]);
in {
  environment.systemPackages = with pkgs; [
    visionPython
    v4l-utils
  ];
}
