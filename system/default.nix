{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    vesktop
  ];
  imports = [
    ./wayland
    ./core
    ./mobile
  ];
}
