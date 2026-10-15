# Desktop side of T3 Gate: the local HTTP gate the browser extension polls.
#
# It listens on 127.0.0.1 only, answers with whether this host or any configured
# remote host has a T3 run in progress, and is what lets the extension block
# YouTube, X and friends while nothing is running anywhere in the fleet.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.t3Gate;
  packages = pkgs.callPackage ../packages.nix {};
  inherit (packages) gate;
in {
  options.t3Gate = {
    enable = lib.mkEnableOption "local T3 busy gate for the browser blocker";

    port = lib.mkOption {
      type = lib.types.port;
      default = 4599;
      description = "Loopback port the gate listens on. Must match the extension's host permission.";
    };

    remotes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        SSH targets checked alongside this host with `t3-running-count`.
        Unreachable targets count as not busy.
      '';
    };

    cacheSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 8;
      description = "How long a computed fleet-wide answer is reused before SSH is queried again.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [gate];

    systemd.user.services.t3-gate = {
      Unit.Description = "Answer the T3 Gate extension: is any T3 agent running?";
      Service = {
        ExecStart = lib.getExe gate;
        Environment = [
          "T3_GATE_PORT=${toString cfg.port}"
          "T3_GATE_REMOTES=${lib.concatStringsSep " " cfg.remotes}"
          "T3_GATE_CACHE=${toString cfg.cacheSeconds}"
        ];
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = ["default.target"];
    };
  };
}
