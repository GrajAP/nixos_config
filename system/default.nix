{...}: {
  environment.systemPackages = [];
  imports = [
    ./wayland
    ./core
    ./maintenance
    ./mobile/adb.nix
  ];
}
