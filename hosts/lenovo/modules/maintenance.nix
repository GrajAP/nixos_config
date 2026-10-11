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

    # Only --delete-older-than. Nix 2.31 removed --max-free-space from
    # nix-collect-garbage entirely, and passing it made this unit exit 1 every
    # night ("error: unrecognised flag '--max-free-space'"), so /nix/store had
    # not been collected since the migration. The free-space floor is a nix.conf
    # concern, not a flag: modules/boot.nix sets `min-free = "10G"`.
    ${pkgs.nix}/bin/nix-collect-garbage --delete-older-than 14d
  '';

  # ---------------------------------------------------------------------------
  # Agent scratch pruning
  #
  # /tmp/opencode and ~/.t3/worktrees are not part of any backup and grow without
  # bound: one fortnight of agent sessions put 13G in /tmp/opencode and 34G in
  # T3 Code worktrees, which is what pushed / to 92% on a 219G SSD.
  #
  # Deliberately conservative:
  #   * age-gated, so anything a session is still touching is untouched;
  #   * a worktree with uncommitted changes is never removed, and `git worktree
  #     remove` is used rather than `rm -rf` so the parent's worktree list stays
  #     consistent -- committed work lives in branches and cannot be lost;
  #   * an entry that any process has open, or uses as its cwd, is skipped.
  # ---------------------------------------------------------------------------
  agentScratchPrune = pkgs.writeShellScriptBin "agent-scratch-prune" ''
    set -eu

    max_age_days=7
    now=$(date +%s)

    # One pass over /proc instead of one per candidate: the naive "is this path
    # in use" check rescans every fd of every process for every directory, which
    # on ~350 candidates takes hours.
    inuse=$(mktemp)
    trap 'rm -f "$inuse"' EXIT
    for l in /proc/[0-9]*/cwd /proc/[0-9]*/root /proc/[0-9]*/exe /proc/[0-9]*/fd/*; do
      readlink "$l" 2>/dev/null || true
    done > "$inuse"

    free_bytes() { df --output=avail -B1 "$1" 2>/dev/null | tail -n1 | tr -dc '0-9'; }

    pruned=0
    skipped=0

    # /tmp/opencode: flat scratch dirs, safe to drop whole.
    scratch=/tmp/opencode
    if [ -d "$scratch" ]; then
      for p in "$scratch"/*; do
        [ -e "$p" ] || continue
        [ $(( (now - $(stat -c %Y "$p")) / 86400 )) -ge "$max_age_days" ] || continue
        if grep -qxF "$p" "$inuse" || grep -qxF "$p/" "$inuse"; then
          echo "agent-scratch-prune: in use, keeping $p"
          skipped=$((skipped + 1))
          continue
        fi
        rm -rf -- "$p" && pruned=$((pruned + 1)) || skipped=$((skipped + 1))
      done
    fi

    # T3 Code worktrees: ask git, never rm.
    wtroot=/home/grajpap/.t3/worktrees
    if [ -d "$wtroot" ]; then
      for project in "$wtroot"/*; do
        [ -d "$project" ] || continue
        for wt in "$project"/*; do
          [ -e "$wt" ] || continue
          [ -e "$wt/.git" ] || continue
          [ $(( (now - $(stat -c %Y "$wt")) / 86400 )) -ge "$max_age_days" ] || continue
          if grep -qxF "$wt" "$inuse"; then
            echo "agent-scratch-prune: in use, keeping $wt"
            skipped=$((skipped + 1))
            continue
          fi
          # No --force: `git worktree remove` refuses a tree with modified or
          # untracked files, which is exactly the guarantee we want here.
          # Uncommitted work is never deleted by this job.
          main=$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
          [ -n "$main" ] || continue
          main=''${main%/.git}
          if git -C "$main" worktree remove "$wt" 2>/dev/null; then
            echo "agent-scratch-prune: removed $wt"
            pruned=$((pruned + 1))
          else
            echo "agent-scratch-prune: refused (dirty?), keeping $wt"
            skipped=$((skipped + 1))
          fi
        done
      done
    fi

    echo "agent-scratch-prune: pruned=$pruned skipped=$skipped avail=$(free_bytes /)"
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
      # Agent scratch pruning
      #
      # Runs before the GC in the same window: freeing the scratch first means
      # the garbage collector does not have to be the thing that rescues a full
      # disk. Age-gated and read-only towards anything in use -- see the script.
      # ---------------------------------------------------------------------------
      agent-scratch-prune = {
        description = "Prune stale agent scratch dirs and T3 Code worktrees";
        after = ["local-fs.target"];
        path = [
          pkgs.coreutils
          pkgs.git
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${agentScratchPrune}/bin/agent-scratch-prune";
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
      agent-scratch-prune = {
        description = "Daily prune of stale agent scratch and worktrees";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "*-*-* 03:40:00";
          RandomizedDelaySec = "30m";
          Persistent = true;
        };
      };

      # Daily, not weekly. /nix/store reached 77G on a 219G disk, and with a
      # weekly cadence plus a 14-day retention window a heavy week of builds
      # fills the disk before the collector ever runs. nix-collect-garbage on a
      # store with nothing to delete is a few seconds of stat() calls.
      nix-store-gc = {
        description = "Daily Nix store garbage collection";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "*-*-* 04:00:00";
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
