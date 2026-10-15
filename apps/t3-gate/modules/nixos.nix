# Host side of T3 Gate: make this machine answer "is a T3 agent running?" over
# SSH. The browsers on the desktops ask their local t3-gate, which fans out to
# every other host with `t3-running-count`; this puts that helper everywhere,
# including the headless lenovo that has no home-manager.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.fleet.t3Gate;
in {
  options.fleet.t3Gate = {
    enable = lib.mkEnableOption "t3-running-count helper, so peers can ask this host whether a T3 agent is running";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.callPackage ../packages.nix {}).helper
    ];
  };
}
