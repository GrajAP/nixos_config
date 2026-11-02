# Backups for the PC.
#
# This used to cover three things: the Nextcloud database and datadir, a second
# copy of the same on the SSD, and /mnt/Storage. Only /mnt/Storage is left.
#
# Nextcloud moved to lenovo (hosts/lenovo/modules/nextcloud.nix), which is
# always on and now owns calendar, tasks and notes. There is nothing at
# /var/lib/nextcloud here to back up, and the pg_dump dance went with it.
#
# The state directory and the repository path keep their old names on purpose.
# The restic password that opens the existing repository lives in the state
# directory, and renaming either would leave this machine unable to open
# /mnt/HDD/Backups/restic/grajpap-nextcloud, which holds the history of every
# snapshot so far. The names are stale; the data behind them is not.
{
  lib,
  pkgs,
  ...
}: let
  backupState = "/var/lib/restic-nextcloud";
  passwordFile = "${backupState}/password";
  storageStamp = "${backupState}/storage-backup.last-success";
  storageRepository = "/mnt/HDD/Backups/restic/grajpap-nextcloud";
  lenovoMirror = "/mnt/SSD2/backups/lenovo-restic";
  retention = [
    "--keep-daily 7"
    "--keep-weekly 5"
    "--keep-monthly 12"
    "--keep-yearly 3"
  ];

  recordStorageBackupSuccess = pkgs.writeShellApplication {
    name = "record-storage-backup-success";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      set -euo pipefail

      if [[ "''${SERVICE_RESULT:-}" != "success" ]]; then
        exit 0
      fi

      stamp_tmp="$(mktemp ${backupState}/.storage-backup.last-success.XXXXXX)"
      trap 'rm -f "$stamp_tmp"' EXIT
      date --iso-8601=seconds > "$stamp_tmp"
      chmod 0600 "$stamp_tmp"
      mv "$stamp_tmp" ${storageStamp}
    '';
  };
in {
  systemd = {
    timers.lenovo-backup-mirror = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "*-*-* 05:00:00";
        Persistent = true;
        RandomizedDelaySec = "20min";
      };
    };
    tmpfiles.rules = [
      "d ${backupState} 0700 root root - -"
      "d /mnt/SSD2/backups 0700 grajpap users - -"
    ];
    services = {
      # Kept under its old name for the same reason as the state directory: the
      # password it manages is the one that opens the existing repository.
      restic-nextcloud-password = {
        description = "Create the local Restic repository password";
        before = ["restic-backups-storage.service"];
        requiredBy = ["restic-backups-storage.service"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          UMask = "0077";
        };
        path = [pkgs.coreutils pkgs.openssl];
        script = ''
          install -d -m 0700 ${backupState}
          if [ ! -s ${passwordFile} ]; then
            openssl rand -base64 48 > ${passwordFile}
          fi
          chmod 0600 ${passwordFile}
        '';
      };

      # Off-site copy of lenovo's restic repository (Bespotted production and
      # HomeNest), including its password so a dead lenovo can be restored.
      # No --delete: the mirror only grows, so a wiped or corrupted repository
      # on lenovo cannot propagate here. Runs as grajpap for the
      # lenovo-user-ts key that T3 Gate already uses.
      lenovo-backup-mirror = {
        description = "Mirror lenovo's restic repository to SSD2";
        after = [
          "mnt-SSD2.mount"
          "network-online.target"
        ];
        requires = ["mnt-SSD2.mount"];
        wants = ["network-online.target"];
        path = [
          pkgs.openssh
          pkgs.rsync
        ];
        serviceConfig = {
          Type = "oneshot";
          User = "grajpap";
          Group = "users";
          UMask = "0077";
          ExecStart = pkgs.writeShellScript "lenovo-backup-mirror" ''
            exec rsync -a --exclude locks/ \
              --rsync-path="sudo rsync" \
              -e "ssh -o BatchMode=yes -o ConnectTimeout=20" \
              lenovo-user-ts:/var/lib/restic/ ${lenovoMirror}/
          '';
        };
      };

      restic-backups-storage = {
        restartIfChanged = lib.mkForce true;
        after = [
          "mnt-HDD.mount"
          "mnt-Storage.mount"
        ];
        requires = [
          "mnt-HDD.mount"
          "mnt-Storage.mount"
        ];
        serviceConfig.ExecStopPost = lib.mkAfter [
          "+${lib.getExe recordStorageBackupSuccess}"
        ];
      };
    };
  };

  services.restic.backups.storage = {
    repository = storageRepository;
    inherit passwordFile;
    initialize = true;
    inhibitsSleep = true;
    paths = ["/mnt/Storage"];
    timerConfig = {
      OnCalendar = "*-*-* 04:15:00";
      Persistent = true;
      RandomizedDelaySec = "20min";
    };
    pruneOpts = retention;
    checkOpts = ["--read-data-subset=1%"];
  };
}
