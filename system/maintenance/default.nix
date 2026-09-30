{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.fleet.autoRebuild;
  # The repo is this configuration. Hardcoded rather than derived from the flake
  # source, because the script has to survive `git pull` replacing the tree and
  # because fleet/status.sh and rebuild.sh already assume the same path.
  repo = "/etc/nixos";
in {
  # ===========================================================================
  # UNATTENDED FLEET UPDATE
  #
  # One timer per host, same script: pull the fleet repo, lint it, switch this
  # host to whatever the pull brought, and publish only what this host authored.
  # See fleet/auto-rebuild for the ordering and the reasoning; the short version
  # is that a host which only received changes must not push them back, or every
  # machine in the fleet would re-push the same commits at each other.
  #
  # Imported by both hosts on purpose. `system/` is otherwise the desktop stack
  # and lenovo does not use it, but this file is a leaf module with no wayland or
  # core dependencies, and one copy of the logic is worth more than the tidiness
  # of the directory split.
  # ===========================================================================
  options.fleet.autoRebuild = {
    enable = lib.mkEnableOption "daily unattended git pull, rebuild, switch and conditional push";

    onCalendar = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 04:40:00";
      example = "*-*-* 05:20:00";
      description = ''
        When the unattended run starts. RandomizedDelaySec is added on top, so
        a fleet does not hit GitHub at the same minute from every machine.
      '';
    };

    randomizedDelaySec = lib.mkOption {
      type = lib.types.str;
      default = "30min";
      description = "Spread the fleet's GitHub traffic over a window after onCalendar.";
    };

    mode = lib.mkOption {
      type = lib.types.enum [
        "switch"
        "boot"
        "build"
      ];
      default = "switch";
      description = ''
        What nixos-rebuild does with the built configuration.

        `switch` activates it now. `boot` only writes it to the profile, so it
        lands on the next boot -- the right choice for a machine that must never
        change its running system unattended. `build` only builds, which is
        useful to keep the binary cache warm for the other hosts.
      '';
    };

    pull = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Fetch and fast-forward the repo before rebuilding. A host with an
        unfinished local edit skips the pull rather than risk a conflict, and
        still rebuilds and publishes what it has.
      '';
    };

    skipWhenUserSessionActive = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Skip the run while a graphical session is logged in.

        Worth it on a desktop: switching the system under a running compositor
        restarts user services it depends on. Headless hosts have no such
        session, so the check costs two loginctl calls and never fires.
      '';
    };

    criticalUnits = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "tailscaled"
      ];
      description = ''
        Units that must be active after the switch. If one is not, the run rolls
        the system back by itself, which is the only self-healing available on a
        host whose owner is 2000 km away.

        tailscaled is the floor for every host: lose it and the tailnet, and with
        it remote access to the machine, is gone.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "grajpap";
      description = ''
        Who runs the update. Deliberately not root: the push needs the user's
        GitHub credential helper, and a commit made by root would leave
        root-owned objects that the user cannot write over next time.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.auto-rebuild = {
      description = "Unattended fleet update: pull, lint, rebuild, switch, publish";
      documentation = [
        "man:systemd.service(5)"
        "file:/etc/nixos/fleet/auto-rebuild"
      ];
      after = [
        "network-online.target"
        "nixos-activation.service"
      ];
      wants = ["network-online.target"];

      serviceConfig = {
        Type = "oneshot";
        # A rebuild is slow by nature; a timeout would kill it mid-build.
        TimeoutStartSec = 0;
        User = cfg.user;
        # The script locks in here, and rebuild.sh looks for its own lock in the
        # same place. A system service has no XDG_RUNTIME_DIR of its own.
        RuntimeDirectory = "auto-rebuild";
        RuntimeDirectoryMode = "0700";
        Environment = [
          # A system service's PATH has no bash on NixOS, so
          # `#!/usr/bin/env bash` alone is not enough, and the script's
          # dependencies have to be spelled out: that is also the list of things
          # it is allowed to call. Built by hand rather than with
          # systemd.services.<name>.path, because that option appends /bin to
          # every entry and cannot express a plain directory.
          "PATH=${
            lib.makeBinPath (
              with pkgs; [
                bash
                coreutils
                gawk
                git
                inetutils
                systemd
                util-linux
              ]
            )
          }:/run/wrappers/bin:/run/current-system/sw/bin"
          "XDG_RUNTIME_DIR=/run/auto-rebuild"
          "AUTO_REBUILD_PULL=${lib.boolToString cfg.pull}"
          "AUTO_REBUILD_MODE=${cfg.mode}"
          "AUTO_REBUILD_SKIP_WHEN_USER_SESSION=${lib.boolToString cfg.skipWhenUserSessionActive}"
          # Quoted, or systemd splits the list of units into separate (invalid)
          # environment assignments.
          "AUTO_REBUILD_CRITICAL_UNITS=\"${lib.concatStringsSep " " cfg.criticalUnits}\""
        ];
        # sudo has to be the setuid wrapper and nixos-rebuild only exists in the
        # running system profile, hence the two absolute PATH entries above.
        ExecStart = "${pkgs.bash}/bin/bash ${repo}/fleet/auto-rebuild";
        WorkingDirectory = repo;
        # Updating is maintenance, not the machine's actual job.
        Nice = 10;
      };
    };

    systemd.timers.auto-rebuild = {
      description = "Daily unattended fleet update";
      wantedBy = [
        "timers.target"
      ];
      timerConfig = {
        OnCalendar = cfg.onCalendar;
        RandomizedDelaySec = cfg.randomizedDelaySec;
        # A machine that was asleep or off at the appointed hour runs the
        # update on its next boot instead of skipping the day.
        Persistent = true;
        Unit = "auto-rebuild.service";
      };
    };
  };
}
