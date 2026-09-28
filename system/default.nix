{...}: {
  environment.systemPackages = [];
  imports = [
    ./wayland
    ./core
  ];
}
