{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    vesktop
  ];
  imports = [
    ./wayland
    ./core
    ./sync
    ./backup
    ./monitoring
  ];
}
