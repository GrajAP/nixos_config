{...}: {
  environment.systemPackages = [];
  imports = [
    ./wayland
    ./core
    ./mobile
    ./sync
    ./backup
    ./monitoring
  ];
}
