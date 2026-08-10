{pkgs, ...}: let
  memoryPython = pkgs.python3.withPackages (ps: [
    ps.chromadb
    ps.sqlite-utils
    ps.requests
  ]);
in {
  environment.systemPackages = with pkgs; [
    memoryPython
    sqlite
  ];
}
