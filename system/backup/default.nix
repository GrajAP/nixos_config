{
  config,
  lib,
  pkgs,
  ...
}: let
  backupState = "/var/lib/restic-nextcloud";
  passwordFile = "${backupState}/password";
  stagingDir = "${backupState}/staging";
  repository = "/mnt/HDD/Backups/restic/grajpap-nextcloud";
in {
  systemd = {
    tmpfiles.rules = [
      "d ${backupState} 0700 root root - -"
      "d ${stagingDir} 0700 root root - -"
    ];
    services = {
      restic-nextcloud-password = {
        description = "Create the local Restic repository password";
        before = ["restic-backups-nextcloud.service"];
        requiredBy = ["restic-backups-nextcloud.service"];
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
        after = [
          "mnt-HDD.mount"
          "mnt-Storage.mount"
          "nextcloud-setup.service"
          "postgresql.service"
        ];
        requires = ["mnt-HDD.mount" "mnt-Storage.mount"];
        serviceConfig.ExecStopPost = lib.mkAfter [
          "+${config.services.nextcloud.occ}/bin/nextcloud-occ maintenance:mode --off"
        ];
      };
      restic-nextcloud-restore-test = {
        description = "Quarterly restore test for the Nextcloud backup";
        after = ["mnt-HDD.mount" "restic-nextcloud-password.service"];
        requires = ["mnt-HDD.mount" "restic-nextcloud-password.service"];
        path = [pkgs.coreutils pkgs.postgresql pkgs.restic];
        serviceConfig.Type = "oneshot";
        script = ''
          set -euo pipefail

          target=${backupState}/restore-test
          rm -rf "$target"
          install -d -m 0700 "$target"
          RESTIC_PASSWORD_FILE=${passwordFile} \
            restic -r ${repository} restore latest \
            --include ${stagingDir}/nextcloud.pgdump \
            --target "$target"
          pg_restore --list "$target${stagingDir}/nextcloud.pgdump" >/dev/null
          rm -rf "$target"
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

  services.restic.backups.nextcloud = {
    inherit repository passwordFile;
    initialize = true;
    inhibitsSleep = true;
    paths = [
      "/var/lib/nextcloud"
      "/mnt/Storage"
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
      ${config.services.nextcloud.occ}/bin/nextcloud-occ maintenance:mode --on
      ${pkgs.util-linux}/bin/runuser -u postgres -- \
        ${lib.getExe' config.services.postgresql.package "pg_dump"} \
        --format=custom \
        --file=${stagingDir}/nextcloud.pgdump \
        nextcloud
      chmod 0600 ${stagingDir}/nextcloud.pgdump
    '';
    backupCleanupCommand = ''
      ${config.services.nextcloud.occ}/bin/nextcloud-occ maintenance:mode --off
    '';
    timerConfig = {
      OnCalendar = "*-*-* 03:15:00";
      Persistent = true;
      RandomizedDelaySec = "20min";
    };
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 5"
      "--keep-monthly 12"
      "--keep-yearly 3"
    ];
    checkOpts = ["--read-data-subset=1%"];
  };
}
