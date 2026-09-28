{pkgs, ...}: let
  # writeShellScriptBin, not writeShellScript: the latter puts the script at
  # the root of its store path, so "${x}/bin/name" would not resolve.
  nixStoreGc = pkgs.writeShellScriptBin "nix-store-gc" ''
    set -eu
    # Refuse to run while anything is actually building. Losing a race with an
    # in-flight build means deleting paths that build depends on.
    if ${pkgs.procps}/bin/pgrep -f 'nix build|nix-shell|nix develop|nix-build' >/dev/null 2>&1; then
      echo "nix-store-gc: build activity detected, skipping this run"
      exit 0
    fi

    ${pkgs.nix}/bin/nix-collect-garbage \
      --delete-older-than 14d \
      --max-free-space 10G
  '';

  nixUpdateCheck = pkgs.writeShellScriptBin "nix-update-check" ''
    set -eu
    cd /etc/nixos

    if [ -n "$(git status --porcelain 2>/dev/null || true)" ]; then
      echo "nix-update-check: /etc/nixos has uncommitted changes, skipping"
      exit 0
    fi

    before=$(git rev-parse HEAD)

    if ! ${pkgs.nix}/bin/nix flake update --commit-lockfile 2>&1; then
      echo "nix-update-check: flake update failed, lockfile untouched"
      exit 0
    fi

    after=$(git rev-parse HEAD)

    if [ "$before" = "$after" ]; then
      echo "nix-update-check: already current ($(git rev-parse --short HEAD))"
      exit 0
    fi

    echo "nix-update-check: lockfile updated $before -> $after"
    git --no-pager log --oneline "$before".."$after" || true
    echo "nix-update-check: run rebuild (or nh os switch /etc/nixos) to apply"
  '';
in {
  # ===========================================================================
  # ROUTINE MAINTENANCE
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # Nix store garbage collection
  #
  # Nix's own auto-GC is keyed on the machine being idle, which a 24/7 server
  # never is, so /nix/store only ever grows here. A timer does the work
  # instead, keeping two weeks of history for manual rollback.
  # ---------------------------------------------------------------------------
  systemd = {
    # ---------------------------------------------------------------------------
    # Nix store garbage collection
    #
    # Nix's own auto-GC is keyed on the machine being idle, which a 24/7 server
    # never is, so /nix/store only ever grows here. A timer does the work
    # instead, keeping two weeks of history for manual rollback.
    # ---------------------------------------------------------------------------
    services = {
      nix-store-gc = {
        description = "Collect Nix store garbage and old boot generations";
        after = ["local-fs.target"];
        path = [
          pkgs.coreutils
          pkgs.nix
          pkgs.procps
        ];
        serviceConfig = {
          Type = "oneshot";
          # Deleting a store path is not reversible, so if the box is busy this
          # gives up rather than fighting a running build.
          ExecStart = "${nixStoreGc}/bin/nix-store-gc";
        };
      };

      # ---------------------------------------------------------------------------
      # Patch awareness
      #
      # Deliberately NOT an unattended `nixos-rebuild switch`. This box is headless
      # with no console and no IPMI: if an automated switch produced an
      # unbootable system at 04:00 the only recovery is physical access to the
      # keyboard. So the timer updates the lockfile and *builds* the result, and
      # reports that a switch is pending. Nothing changes on the running system
      # until a human runs `rebuild`.
      #
      # To go fully unattended, add `nixos-rebuild switch` to the script below and
      # keep systemd-boot.configurationLimit high enough to roll back from the
      # console. Do not do that on a machine you cannot reach.
      # ---------------------------------------------------------------------------
      nix-update-check = {
        description = "Update the flake lockfile and report pending system changes";
        after = ["network-online.target"];
        wants = ["network-online.target"];
        path = [
          pkgs.coreutils
          pkgs.git
          pkgs.nix
        ];
        serviceConfig = {
          Type = "oneshot";
          WorkingDirectory = "/etc/nixos";
          ExecStart = "${nixUpdateCheck}/bin/nix-update-check";
        };
      };
    };

    timers = {
      nix-store-gc = {
        description = "Weekly Nix store garbage collection";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "Sun *-*-* 04:00:00";
          RandomizedDelaySec = "45m";
          Persistent = true;
        };
      };

      nix-update-check = {
        description = "Weekly check for NixOS security updates";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "Wed *-*-* 05:00:00";
          RandomizedDelaySec = "2h";
          Persistent = true;
        };
      };
    };
  };
}
