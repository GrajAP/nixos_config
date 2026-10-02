{...}: {
  environment.systemPackages = [];
  imports = [
    ./wayland
    ./core
    ./maintenance
  ];
}
