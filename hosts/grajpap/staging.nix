{
  lib,
  pkgs,
  ...
}: {
  # Staging preview profile for dependency updates.
  # Kept out of default system output so it can be built/tested safely.
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_zen;

  # Optional follow-up for this profile:
  # replace this with a tracked Hyprland source package once you add a dedicated input.
  home-manager.users.grajpap.wayland.windowManager.hyprland.package = pkgs.hyprland;
  # Optional follow-up for a Lua trackable bump:
  # home-manager.users.grajpap.wayland.windowManager.hyprland.package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
}
