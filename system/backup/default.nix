{
  config,
  lib,
  pkgs,
  ...
}: let
  backupState = "/var/lib/restic-nextcloud";
  passwordFile = "${backupState}/password";
  stagingDir = "${backupState}/staging";
  backupStamp = "${backupState}/backup.last-success";
  storageBackupStamp = "${backupState}/storage-backup.last-success";
  restoreStamp = "${backupState}/restore-test.last-success";
  coreRepository = "/mnt/HDD/Backups/restic/grajpap-nextcloud-core";
  storageRepository = "/mnt/HDD/Backups/restic/grajpap-nextcloud";
  retention = [
    "--keep-daily 7"
    "--keep-weekly 5"
    "--keep-monthly 12"
    "--keep-yearly 3"
  ];
  recordSuccess = {
    name,
    stamp,
    temporary,
  }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [pkgs.coreutils];
      text = ''
        set -euo pipefail

        if [[ "''${SERVICE_RESULT:-}" != "success" ]]; then
          exit 0
        fi

        stamp_tmp="$(mktemp ${backupState}/.${temporary}.XXXXXX)"
        trap 'rm -f "$stamp_tmp"' EXIT
        date --iso-8601=seconds > "$stamp_tmp"
        chmod 0600 "$stamp_tmp"
        mv "$stamp_tmp" ${stamp}
      '';
    };
  recordBackupSuccess = recordSuccess {
    name = "record-nextcloud-backup-success";
    stamp = backupStamp;
    temporary = "backup.last-success";
  };
  recordStorageBackupSuccess = recordSuccess {
    name = "record-nextcloud-storage-backup-success";
    stamp = storageBackupStamp;
    temporary = "storage-backup.last-success";
  };
in {
  systemd = {
    tmpfiles.rules = [
      "d ${backupState} 0700 root root - -"
      "d ${stagingDir} 0700 root root - -"
    ];
    services = {
      restic-nextcloud-password = {
        description = "Create the local Restic repository password";
        before = [
          "restic-backups-nextcloud.service"
          "restic-backups-nextcloud-storage.service"
        ];
        requiredBy = [
          "restic-backups-nextcloud.service"
          "restic-backups-nextcloud-storage.service"
        ];
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

      restic-backups-nextcloud = {
        restartIfChanged = lib.mkForce true;
        after = [
          "mnt-HDD.mount"
          "nextcloud-setup.service"
          "postgresql.service"
        ];
        requires = ["mnt-HDD.mount"];
        serviceConfig.ExecStopPost = lib.mkAfter [
          "+${config.services.nextcloud.occ}/bin/nextcloud-occ maintenance:mode --off"
          "+${lib.getExe recordBackupSuccess}"
        ];
      };
      restic-backups-nextcloud-storage = {
        restartIfChanged = lib.mkForce true;
        after = ["mnt-HDD.mount" "mnt-Storage.mount"];
        requires = ["mnt-HDD.mount" "mnt-Storage.mount"];
        serviceConfig.ExecStopPost = lib.mkAfter [
          "+${lib.getExe recordStorageBackupSuccess}"
        ];
      };
      restic-nextcloud-restore-test = {
        description = "Quarterly restore test for the Nextcloud backup";
        after = ["mnt-HDD.mount" "restic-nextcloud-password.service"];
        requires = ["mnt-HDD.mount" "restic-nextcloud-password.service"];
        path = [pkgs.coreutils pkgs.postgresql pkgs.restic];
        serviceConfig = {
          Type = "oneshot";
          UMask = "0077";
        };
        script = ''
          set -euo pipefail

          target=${backupState}/restore-test
          dump="$target${stagingDir}/nextcloud.pgdump"
          stamp_tmp=""

          cleanup() {
            rm -rf "$target"
            if [[ -n "$stamp_tmp" ]]; then
              rm -f "$stamp_tmp"
            fi
          }
          trap cleanup EXIT

          rm -rf "$target"
          install -d -m 0700 "$target"
          RESTIC_PASSWORD_FILE=${passwordFile} \
            restic -r ${coreRepository} restore latest \
            --include ${stagingDir}/nextcloud.pgdump \
            --target "$target"
          test -s "$dump"
          pg_restore --list "$dump" >/dev/null

          stamp_tmp="$(mktemp ${backupState}/.restore-test.last-success.XXXXXX)"
          date --iso-8601=seconds > "$stamp_tmp"
          chmod 0600 "$stamp_tmp"
          mv "$stamp_tmp" ${restoreStamp}
          stamp_tmp=""
        '';
      };
    };
    timers.restic-nextcloud-restore-test = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "*-01,04,07,10-01 05:00:00";
        Persistent = true;
        RandomizedDelaySec = "2h";
      };
    };
  };

  services.restic.backups = {
    nextcloud = {
      repository = coreRepository;
      inherit passwordFile;
      initialize = true;
      inhibitsSleep = true;
      paths = [
        "/var/lib/nextcloud"
        stagingDir
        "/home/grajpap/.config/quickshell/nextcloud-app-password"
      ];
      exclude = [
        "/var/lib/nextcloud/data/*/cache"
        "/var/lib/nextcloud/data/appdata_*/preview"
      ];
      backupPrepareCommand = ''
        set -euo pipefail
        install -d -m 0700 ${stagingDir}

        maintenance_enabled=false
        leave_maintenance() {
          if [[ "$maintenance_enabled" == true ]]; then
            ${config.services.nextcloud.occ}/bin/nextcloud-occ maintenance:mode --off
            maintenance_enabled=false
          fi
        }
        trap leave_maintenance EXIT

        ${config.services.nextcloud.occ}/bin/nextcloud-occ maintenance:mode --on
        maintenance_enabled=true
        ${pkgs.util-linux}/bin/runuser -u postgres -- \
          ${lib.getExe' config.services.postgresql.package "pg_dump"} \
          --format=custom \
          nextcloud \
          > ${stagingDir}/nextcloud.pgdump
        chmod 0600 ${stagingDir}/nextcloud.pgdump
        leave_maintenance
        trap - EXIT
      '';
      backupCleanupCommand = ''
        ${config.services.nextcloud.occ}/bin/nextcloud-occ maintenance:mode --off
      '';
      timerConfig = {
        OnCalendar = "*-*-* 03:15:00";
        Persistent = true;
        RandomizedDelaySec = "20min";
      };
      pruneOpts = retention;
      checkOpts = ["--read-data-subset=1%"];
    };
    nextcloud-storage = {
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
  };
}
