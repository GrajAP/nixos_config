{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homenest;

  homenestSecrets = pkgs.writeShellScriptBin "homenest-secrets" ''
    set -eu
    umask 0077
    dir=/var/lib/homenest
    mkdir -p "$dir"

    gen() {
      # $1 = name, $2 = byte count
      f="$dir/$1"
      if [ ! -s "$f" ]; then
        ${pkgs.openssl}/bin/openssl rand -hex "$2" > "$f"
        echo "homenest-secrets: generated $1"
      fi
      chown root:homenest "$f"
      chmod 0640 "$f"
    }

    gen jwt-secret 32
    gen webhook-secret 32

    # Three writers share this directory: the service (as 'homenest'), the APK
    # build scripts (as 'grajpap', via the 'homenest' group) and the container
    # (as root). tmpfiles' `d` only applies mode/ownership when it *creates* the
    # directory, so an existing one keeps whatever mode it had -- which is how it
    # was left group-unwritable. Set it explicitly on every boot.
    install -d -m 0775 -o homenest -g homenest ${cfg.dataDir}
    ${pkgs.coreutils}/bin/chmod 0775 ${cfg.dataDir}

    # EnvironmentFile for the service. Re-rendered every boot from the
    # persisted files, so it is never stale and never at rest on disk.
    install -d -m 0750 -o root -g homenest /run/homenest
    umask 0077
    {
      echo "JWT_SECRET=$(${pkgs.coreutils}/bin/cat "$dir/jwt-secret")"
      echo "UPDATE_WEBHOOK_SECRET=$(${pkgs.coreutils}/bin/cat "$dir/webhook-secret")"
    } > /run/homenest/env
    chown root:homenest /run/homenest/env
    chmod 0640 /run/homenest/env
  '';
in {
  options.services.homenest = {
    enable = lib.mkEnableOption "the HomeNest home-management service";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3001;
      description = "TCP port the Node backend listens on.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/opt/homenest/data";
      description = ''
        Writable state directory: the SQLite database, its WAL, and the built
        APKs. This is the only path the service may write to.
      '';
    };

    workDir = lib.mkOption {
      type = lib.types.path;
      default = "/opt/homenest/backend";
      description = "Directory containing the built `dist/` tree.";
    };

    memoryHigh = lib.mkOption {
      type = lib.types.str;
      default = "2G";
      description = "Soft limit; the cgroup is reclaimed above this.";
    };

    memoryMax = lib.mkOption {
      type = lib.types.str;
      default = "3G";
      description = ''
        Hard limit. A leaking Node heap reaps *itself* here instead of letting
        the kernel OOM killer, or oomd, pick a bystander.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # -------------------------------------------------------------------------
    # Secrets
    #
    # The running service had neither JWT_SECRET nor UPDATE_WEBHOOK_SECRET set.
    # Two consequences, both serious:
    #
    #  * auth.js falls back to the literal 'homenest-super-secret-key-change-in-prod',
    #    which is committed to the public app repository. Every auth token was
    #    forgeable by anyone who could reach the port.
    #
    #  * routes/system.js exposes POST /api/system/webhook-update *before* the
    #    auth middleware, guarded only by
    #        if (secret && signature !== secret)
    #    With the secret unset that condition is always false, so the route was
    #    open: an unauthenticated POST ran scripts/auto-update.sh, which does
    #    `git merge --ff-only origin/main`, `npm install`, `npm run build` and
    #    `sudo systemctl restart homenest`.
    #
    # Both secrets are generated once into /var/lib/homenest (persisted, not
    # regenerated per rebuild, so the GitHub webhook keeps working) and handed
    # to the service through a root-only EnvironmentFile under /run.
    #
    # Setting JWT_SECRET invalidates every issued token: all users must sign in
    # again after the first switch. That is the point.
    # -------------------------------------------------------------------------
    systemd = {
      services = {
        homenest-secrets = {
          description = "Generate HomeNest runtime secrets (once) and publish them to /run";
          wantedBy = ["multi-user.target"];
          before = ["homenest.service"];
          path = [
            pkgs.coreutils
            pkgs.openssl
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${homenestSecrets}/bin/homenest-secrets";
          };
        };

        # -------------------------------------------------------------------------
        # The service
        # -------------------------------------------------------------------------
        homenest = {
          description = "HomeNest - home management system";
          wantedBy = ["multi-user.target"];
          after = [
            "network-online.target"
            "docker.service"
            "homenest-secrets.service"
            "systemd-tmpfiles-setup.service"
          ];
          # network.target only means "a NIC exists". This app answers HTTP the
          # moment it binds, so it must wait for an actual address -- otherwise the
          # first request after a reboot races the network and fails.
          wants = ["network-online.target"];

          # Restart forever. A crash-loop is a loud failure we want alerting on, not
          # a silent one, so do not let systemd give up.
          startLimitIntervalSec = 0;
          startLimitBurst = 0;

          environment = {
            PORT = toString cfg.port;
            DATA_DIR = cfg.dataDir;
            NODE_ENV = "production";
            # `git rev-parse` for the /system/version endpoint.
            GIT_COMMIT = "systemd";
          };

          serviceConfig = {
            Type = "simple";
            User = "homenest";
            Group = "homenest";
            WorkingDirectory = cfg.workDir;
            ExecStart = "${lib.getExe pkgs.nodejs_22} dist/index.js";

            Restart = "always";
            RestartSec = "5s";

            EnvironmentFile = "/run/homenest/env";

            LimitNOFILE = 65536;
            LimitNPROC = 512;

            # Resource containment.
            MemoryHigh = cfg.memoryHigh;
            MemoryMax = cfg.memoryMax;
            TasksMax = 512;
            CPUQuota = 400; # 4 cores, i.e. all of them; the cap that matters is memory

            # --- sandbox -------------------------------------------------------
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "full"; # /usr, /boot, /efi read-only
            ProtectHome = true; # no /home, /root, /run/user
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectKernelLogs = true;
            ProtectControlGroups = true;
            ProtectClock = true;
            ProtectHostname = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            RestrictNamespaces = true;
            LockPersonality = true;
            MemoryDenyWriteExecute = false; # V8 JIT needs writable+executable pages
            SystemCallArchitectures = "native";

            # The app spawns `bash scripts/auto-update.sh` and `git rev-parse`, so it
            # needs a real PATH. The sandbox still denies fork bombs, mounts, module
            # loading and anything else outside this set. EPERM rather than SIGKILL so
            # a denied call surfaces as an error instead of an unexplained death.
            SystemCallFilter = [
              "@system-service"
              "~@privileged"
              "~@mount"
              "~@reboot"
              "~@swap"
            ];
            SystemCallErrorNumber = "EPERM";

            CapabilityBoundingSet = "";
            AmbientCapabilities = "";

            # /opt is writable under ProtectSystem=full; name the one directory
            # that legitimately needs it, so the rest becomes read-only when this
            # is tightened to "strict".
            ReadWritePaths = [cfg.dataDir];

            StandardOutput = "journal";
            StandardError = "journal";
            SyslogIdentifier = "homenest";
            LogRateLimitIntervalSec = "30s";
            LogRateLimitBurst = 2000;
          };
        };

        # The data directory is shared between three writers: the service (as
        # `homenest`), the APK build scripts (as `grajpap`, via the `homenest`
        # group) and the container (as root). tmpfiles keeps ownership and mode
        # correct across boots without a hand-run chown.
      };

      tmpfiles.rules = [
        "d ${cfg.dataDir} 0775 homenest homenest -"
      ];
    };
  };
}
