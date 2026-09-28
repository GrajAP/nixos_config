{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homenest;
  inherit (pkgs) restic;
  repo = lib.escapeShellArg config.backup.resticRepository;
  stage = config.backup.stageDir;

  # writeShellScriptBin, not writeShellScript: the latter puts the script at
  # the root of its store path, so "${x}/bin/name" would not resolve.
  # restic refuses to run without a password. Generated once, persisted, and
  # referenced by a fixed path so the service can set RESTIC_PASSWORD_FILE
  # statically -- an EnvironmentFile written by ExecStartPre would be read
  # before that script had a chance to create it.
  resticPasswordFile = "/var/lib/restic/password";

  resticEnv = pkgs.writeShellScriptBin "homenest-backup-env" ''
    set -eu
    umask 0077
    mkdir -p /var/lib/restic
    if [ ! -s ${resticPasswordFile} ]; then
      ${pkgs.openssl}/bin/openssl rand -hex 32 > ${resticPasswordFile}
      echo "homenest-backup-env: generated repository password"
    fi
    chmod 0600 ${resticPasswordFile}
  '';

  homenestBackupPre = pkgs.writeShellScriptBin "homenest-backup-pre" ''
    set -eu
    stage=${stage}
    src=${cfg.dataDir}

    install -d -m 0700 "$stage"

    if [ ! -d ${repo} ]; then
      echo "homenest-backup: initialising repository at ${repo}"
      ${lib.getExe restic} -r ${repo} init
    fi

    if [ -f "$src/homenest.db" ]; then
      rm -f "$stage/homenest.db"
      ${lib.getExe pkgs.sqlite} "$src/homenest.db" ".backup '$stage/homenest.db'"
      chmod 0600 "$stage/homenest.db"
      # Prove the copy is a real database, not a truncated file.
      ${lib.getExe pkgs.sqlite} "$stage/homenest.db" "pragma integrity_check;" \
        | grep -qx ok \
        || {
          echo "homenest-backup: integrity check FAILED, aborting" >&2
          exit 1
        }
    fi
  '';

  homenestBackupRun = pkgs.writeShellScriptBin "homenest-backup-run" ''
    set -eu
    ${lib.getExe restic} -r ${repo} backup \
      ${cfg.dataDir} \
      /etc/nixos \
      --tag homenest \
      --tag "$(hostname)" \
      --exclude '*.apk' \
      --exclude 'auto-update.log'
  '';
in {
  # ===========================================================================
  # BACKUP
  #
  # Before this there was no automated backup of anything. The only copies of
  # HomeNest's data were two hand-run tarballs in $HOME.
  #
  # Why the staging step matters: the SQLite database is 4KB on disk with a
  # 572KB write-ahead log. A naive file copy of `homenest.db` captures almost
  # none of the data. `sqlite3 .backup` produces a consistent, fully
  # checkpointed copy through the SQLite API while the app keeps running, and
  # the result is verified with `pragma integrity_check` before it is archived.
  # ===========================================================================

  options.backup = {
    resticRepository = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/restic/homenest";
      description = ''
        restic repository holding HomeNest data and /etc/nixos.

        !! The default is on the SAME disk as the data. That protects against
        accidental deletion, a bad deploy or an `rm -rf`, and nothing more. It
        does not survive disk failure.

        For real off-disk protection, point this somewhere else:

          ":restic:/mnt/backup-disk/restic"           USB drive
          ":restic:user@nas.local:/vol/backups/x"    SFTP to a NAS or another box
          "s3:s3.eu-central-1.amazonaws.com/bucket"  object storage
          "rest:https://user:pass@rest.example.org/"  a rest-server

        then run: sudo restic -r <new-repo> init
      '';
    };

    stageDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/homenest-backup";
      description = "Scratch space for the consistent database snapshot.";
    };
  };

  config = {
    systemd = {
      tmpfiles.rules = [
        "d ${stage} 0700 root root -"
      ];

      services = {
        # -----------------------------------------------------------------------
        # Backup
        # -----------------------------------------------------------------------
        homenest-backup-env = {
          description = "Ensure the restic repository password exists";
          wantedBy = ["multi-user.target"];
          before = ["homenest-backup.service"];
          path = [
            pkgs.coreutils
            pkgs.openssl
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${resticEnv}/bin/homenest-backup-env";
          };
        };

        homenest-backup = {
          description = "restic backup of HomeNest data and /etc/nixos";
          after = [
            "network-online.target"
            "local-fs.target"
            "homenest-backup-env.service"
          ];
          wants = ["network-online.target"];
          path = [
            pkgs.coreutils
            pkgs.inetutils # hostname, for the snapshot host tag
            pkgs.sqlite
            restic
          ];
          environment.RESTIC_PASSWORD_FILE = resticPasswordFile;
          serviceConfig = {
            Type = "oneshot";
            User = "root";

            ExecStartPre = "${homenestBackupPre}/bin/homenest-backup-pre";

            ExecStart = "${homenestBackupRun}/bin/homenest-backup-run";

            # Never leave a database copy lying around in the scratch directory.
            ExecStopPost = "${pkgs.coreutils}/bin/rm -f ${stage}/homenest.db";
          };
        };

        # -----------------------------------------------------------------------
        # Retention
        # -----------------------------------------------------------------------
        homenest-backup-prune = {
          description = "restic forget/prune and repository check";
          after = [
            "homenest-backup.service"
            "homenest-backup-env.service"
          ];
          path = [
            pkgs.coreutils
            restic
          ];
          environment.RESTIC_PASSWORD_FILE = resticPasswordFile;
          serviceConfig = {
            Type = "oneshot";
            User = "root";
            ExecStart = ''
              ${lib.getExe restic} -r ${repo} \
                forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
              ${lib.getExe restic} -r ${repo} check --read-data-subset=5%
            '';
          };
        };
      };

      timers = {
        homenest-backup = {
          description = "Nightly HomeNest backup";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "*-*-* 03:30:00";
            RandomizedDelaySec = "10m";
            Persistent = true; # run after a reboot if the window was missed
            AccuracySec = "1m";
          };
        };

        homenest-backup-prune = {
          description = "Weekly restic retention and verification";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "Sun *-*-* 05:00:00";
            RandomizedDelaySec = "30m";
            Persistent = true;
          };
        };
      };
    };

    # -----------------------------------------------------------------------
    # Restore, for when you need it
    #
    #   sudo systemctl stop homenest.service
    #   sudo restic -r <repo> snapshots
    #   sudo restic -r <repo> restore latest --target /tmp/r \
    #     --include /opt/homenest/data
    #   sudo rsync -a --delete /tmp/r/opt/homenest/data/ /opt/homenest/data/
    #   sudo chown -R homenest:homenest /opt/homenest/data
    #   sudo systemctl start homenest.service
    # -----------------------------------------------------------------------
  };
}
