{pkgs, ...}: let
  heartbeatPython = pkgs.python3.withPackages (ps: [
    ps.psutil
    ps.requests
  ]);
in {
  environment.systemPackages = with pkgs; [
    heartbeatPython
    libnotify
    inotify-tools
  ];
}
