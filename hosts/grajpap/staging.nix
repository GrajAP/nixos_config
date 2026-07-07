{
  lib,
  pkgs,
  ...
}: {
  # Staging preview profile for dependency updates.
  # Kept out of default system output so it can be built/tested safely.
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_zen;

  # Optional follow-up for this profile:
  # override Hyprland with lib.mkForce only when staging intentionally tests
  # a different package than home/rice/hyprland/default.nix.
  # home-manager.users.grajpap.wayland.windowManager.hyprland.package = lib.mkForce pkgs.hyprland;
}
