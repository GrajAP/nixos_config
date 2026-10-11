{
  config,
  lib,
  pkgs,
  ...
}: let
  # writeShellScriptBin, not writeShellScript: the latter emits the script at
  # the root of its store path, so "${x}/bin/name" would not resolve.
  # Warn at 85%, but *act* at 92%.
  #
  # Notifying alone is not enough on a headless box: the 2026-10-11 audit found
  # / at 92% with only 18G free, and the nightly Nix GC that should have been
  # reclaiming that space had been failing for days. By the time a human reads
  # the alert, a single large build can already have taken the root filesystem
  # (and with it the journal) to zero.
  #
  # So above the critical line this runs the same two reclaim jobs the timers
  # run, and reports what they managed to free.
  diskSpaceCheck = pkgs.writeShellScriptBin "disk-space-check" ''
    set -eu
    warn=85
    critical=92

    used=$(df --output=pcent / | tail -n1 | tr -dc '0-9')
    avail=$(df -h --output=avail / | tail -n1 | tr -d ' ')

    if [ "$used" -lt "$warn" ]; then
      echo "disk-space-check: ''${used}% used, ''${avail} available"
      exit 0
    fi

    reclaimed="nothing reclaimed"

    if [ "$used" -ge "$critical" ]; then
      before=$(df --output=avail -B1 / | tail -n1 | tr -dc '0-9')
      systemctl start --no-block agent-scratch-prune.service
      systemctl start --no-block nix-store-gc.service
      # Neither job is instant; give them room before measuring the result.
      for _ in $(seq 1 60); do
        [ -z "$(systemctl list-jobs --no-legend agent-scratch-prune.service nix-store-gc.service 2>/dev/null)" ] && break
        sleep 10
      done
      after=$(df --output=avail -B1 / | tail -n1 | tr -dc '0-9')
      reclaimed=$(( (after - before) / 1048576 ))" MiB reclaimed by prune+GC"
    fi

    ${notify}/bin/server-notify "root filesystem at ''${used}% (''${avail} free, reclaimed: ''${reclaimed})" \\
      "$(df -h /; echo; echo 'journalctl -u agent-scratch-prune -u nix-store-gc -n 50')"
  '';

  # systemd does not run ExecStart through a shell, so the `systemctl status`
  # capture has to live in a script rather than inline in the unit.
  serverAlert = pkgs.writeShellScriptBin "server-alert" ''
    set -eu
    unit="''${1:?usage: server-alert <unit>}"
    ${notify}/bin/server-notify "unit failed: $unit" \\
      "$(systemctl status "$unit" --no-pager -n 20 2>&1 || true)"
  '';

  notify = pkgs.writeShellScriptBin "server-notify" ''
        set -eu
        # Alert sink. Appends to the journal (so `journalctl -u server-alert`
        # answers "what happened while I was away") and to a file on disk, and
        # POSTs to ntfy when a topic is configured.
        #
        # NOTE: quoting and ''${...} expansion happen here in shell, not in Nix,
        # so that lib.escapeShellArg is not needed and cannot mangle the string.
        subject="''${1:?usage: server-notify <subject> [body]}"
        body="''${2:-}"

        {
          echo "=== $(date -Is) ==="
          echo "$subject"
          [ -n "$body" ] && echo "$body"
        } | tee -a /var/log/server-alert.log >&2

        if [ -n "''${SERVER_ALERT_NTFY_TOPIC:-}" ]; then
          ${pkgs.curl}/bin/curl -fsS -m 10 \
            -H "Title: lenovo" \
            -H "Tags: warning" \
            -d "$subject
    $body" \
            "http://$SERVER_ALERT_NTFY_HOST''${SERVER_ALERT_NTFY_PORT:+:$SERVER_ALERT_NTFY_PORT}/$SERVER_ALERT_NTFY_TOPIC" \
            >/dev/null 2>&1 || true
        fi
  '';
in {
  # ===========================================================================
  # MONITORING AND ALERTING
  #
  # Previously the box had no health monitoring of any kind. A failing disk, a
  # full filesystem, a container crash-looping or a service that had been down
  # for six hours were all invisible until somebody noticed.
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # ntfy push
  #
  # Empty by default: with no topic set the notify script only writes to the
  # journal and /var/log/server-alert.log, which still works with zero setup.
  # To turn on phone notifications:
  #   1. create a topic at https://ntfy.sh/your-topic  (or run your own ntfy)
  #   2. set the three values below
  #   3. add a token via `options.serverAlerts.ntfyToken`, or set
  #      NTFY_TOKEN in /etc/server-alerts.env
  # ---------------------------------------------------------------------------
  options.serverAlerts = {
    enable =
      lib.mkEnableOption "failure notifications for critical services"
      // {
        default = true;
      };
    ntfyHost = lib.mkOption {
      type = lib.types.str;
      default = "ntfy.sh";
      description = "ntfy server hostname.";
    };
    ntfyTopic = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "ntfy topic to publish to. Empty disables push; alerts are still logged.";
    };
  };

  config = {
    # A full disk takes the journal down with it, which takes the evidence of
    # why the disk filled up with it. Hence the daily check below.
    #
    # A generic failure handler; any unit can opt in with `onFailure`.
    systemd.services =
      {
        # The trailing @ is load-bearing: it makes NixOS emit
        # /etc/systemd/system/server-alert@.service, a *template* unit. A plain
        # "server-alert" attr would only produce server-alert.service, and then
        # every OnFailure=server-alert@<unit>.service would fail with
        # "Unit not found".
        #
        # Deliberately NOT wantedBy anything: a template must only be started as
        # server-alert@<unit>.service by an OnFailure= directive.
        "server-alert@" = {
          description = "Notify on failure of a watched unit";
          path = [
            notify
            pkgs.coreutils
            pkgs.systemd
          ];
          environment = {
            SERVER_ALERT_NTFY_HOST = config.serverAlerts.ntfyHost;
            SERVER_ALERT_NTFY_TOPIC = config.serverAlerts.ntfyTopic;
          };
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${serverAlert}/bin/server-alert %i";
          };
        };
      }
      // (
        # NB: `//` binds tighter than function application in Nix, so this needs
        # its own parentheses or it parses as `({...} // lib.genAttrs)(...)`.
        #
        # sshd and docker are in this list because their failure means "the box
        # is gone" rather than "one thing is wrong".
        lib.genAttrs
        [
          "sshd"
          "docker"
          "caddy"
          "homenest"
          "homenest-backup"
          "smartd"
        ]
        (name: {
          onFailure = ["server-alert@${name}.service"];
        })
      )
      // {
        "disk-space-check" = {
          description = "Warn when the root filesystem gets full, reclaim when critical";
          after = ["local-fs.target"];
          path = [
            notify
            pkgs.coreutils
            pkgs.systemd
          ];
          environment = {
            SERVER_ALERT_NTFY_HOST = config.serverAlerts.ntfyHost;
            SERVER_ALERT_NTFY_TOPIC = config.serverAlerts.ntfyTopic;
          };
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${diskSpaceCheck}/bin/disk-space-check";
          };
        };
      };

    # ---------------------------------------------------------------------------
    # smartd: disk health
    #
    # Was not installed at all -- no smartd, and not even smartctl on PATH. One
    # SSD carrying /, /nix/store, the container graph and the production database.
    # ---------------------------------------------------------------------------
    services.smartd = {
      enable = true;
      autodetect = true;

      # -a monitors everything, and adds a short self-test daily and a long one
      # weekly, so a drive that is degrading *before* it fails is caught.
      defaults.monitored = "-a -o on -s (S/../.././02|L/../../7/04)";

      # No MTA on this box, so mail alerts are off. Everything still lands in the
      # journal; the smartd failure alert above fires if the daemon itself dies.
      notifications = {
        wall.enable = false;
        mail.enable = false;
        x11.enable = false;
      };
    };

    environment.systemPackages = [pkgs.smartmontools];

    systemd.timers.disk-space-check = {
      description = "Disk space check every 4 hours";
      wantedBy = ["timers.target"];
      timerConfig = {
        # Every 4h, not daily: the check is a df() plus, above the critical
        # line, a reclaim. At the observed growth rate (34G of worktrees in a
        # fortnight on a 219G disk) a daily cadence leaves very little room.
        OnCalendar = "*-*-* 00/4:15:00";
        RandomizedDelaySec = "15m";
        Persistent = true;
      };
    };
  };
}
