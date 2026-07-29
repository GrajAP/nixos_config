{
  lib,
  pkgs,
  ...
}: let
  collectHealth = pkgs.writeShellApplication {
    name = "collect-system-health";
    runtimeInputs = with pkgs; [coreutils gawk jq smartmontools systemd util-linux];
    text = ''
      set -euo pipefail

      output=/var/lib/system-health/status.json
      tmp="$(mktemp)"
      trap 'rm -f "$tmp"' EXIT

      root_used="$(df -P /nix | awk 'NR == 2 { gsub(/%/, "", $5); print $5 }')"
      kernel_errors="$(journalctl --dmesg --priority=err --since='24 hours ago' --output=json 2>/dev/null | jq -s 'length')"
      backup_state="$(systemctl show restic-backups-nextcloud.service --property=ActiveState --value 2>/dev/null || echo unknown)"
      backup_result="$(systemctl show restic-backups-nextcloud.service --property=Result --value 2>/dev/null || echo unknown)"
      backup_stamp=/var/lib/restic-nextcloud/backup.last-success
      backup_last_success=""
      backup_age_hours=null
      if [[ -s "$backup_stamp" ]]; then
        backup_last_success="$(head -n1 "$backup_stamp")"
        backup_epoch="$(date --date="$backup_last_success" +%s 2>/dev/null || true)"
        if [[ "$backup_epoch" =~ ^[0-9]+$ ]]; then
          backup_age_hours="$(( ($(date +%s) - backup_epoch) / 3600 ))"
        fi
      fi
      storage_backup_state="$(systemctl show restic-backups-nextcloud-storage.service --property=ActiveState --value 2>/dev/null || echo unknown)"
      storage_backup_result="$(systemctl show restic-backups-nextcloud-storage.service --property=Result --value 2>/dev/null || echo unknown)"
      storage_backup_stamp=/var/lib/restic-nextcloud/storage-backup.last-success
      storage_backup_last_success=""
      storage_backup_age_hours=null
      if [[ -s "$storage_backup_stamp" ]]; then
        storage_backup_last_success="$(head -n1 "$storage_backup_stamp")"
        storage_backup_epoch="$(date --date="$storage_backup_last_success" +%s 2>/dev/null || true)"
        if [[ "$storage_backup_epoch" =~ ^[0-9]+$ ]]; then
          storage_backup_age_hours="$(( ($(date +%s) - storage_backup_epoch) / 3600 ))"
        fi
      fi
      restore_test_stamp=/var/lib/restic-nextcloud/restore-test.last-success
      restore_test_last_success=""
      restore_test_age_hours=null
      if [[ -s "$restore_test_stamp" ]]; then
        restore_test_last_success="$(head -n1 "$restore_test_stamp")"
        restore_test_epoch="$(date --date="$restore_test_last_success" +%s 2>/dev/null || true)"
        if [[ "$restore_test_epoch" =~ ^[0-9]+$ ]]; then
          restore_test_age_hours="$(( ($(date +%s) - restore_test_epoch) / 3600 ))"
        fi
      fi

      disks='[]'
      while read -r name; do
        [[ -n "$name" ]] || continue
        report="$(smartctl --json=c --health --attributes "/dev/$name" 2>/dev/null || true)"
        if [[ -z "$report" ]]; then
          report="$(jq -n --arg device "/dev/$name" '{device: {name: $device}, available: false}')"
        fi
        disks="$(jq --argjson report "$report" '. + [$report]' <<<"$disks")"
      done < <(lsblk --json --nodeps --output NAME,TYPE | jq -r '.blockdevices[] | select(.type == "disk") | .name')

      jq -n \
        --arg generatedAt "$(date --iso-8601=seconds)" \
        --argjson rootUsedPercent "$root_used" \
        --argjson kernelErrors24h "$kernel_errors" \
        --arg backupState "$backup_state" \
        --arg backupResult "$backup_result" \
        --arg backupLastSuccess "$backup_last_success" \
        --argjson backupAgeHours "$backup_age_hours" \
        --arg storageBackupState "$storage_backup_state" \
        --arg storageBackupResult "$storage_backup_result" \
        --arg storageBackupLastSuccess "$storage_backup_last_success" \
        --argjson storageBackupAgeHours "$storage_backup_age_hours" \
        --arg restoreTestLastSuccess "$restore_test_last_success" \
        --argjson restoreTestAgeHours "$restore_test_age_hours" \
        --argjson disks "$disks" \
        '{
          generatedAt: $generatedAt,
          root: {usedPercent: $rootUsedPercent},
          backup: {
            state: $backupState,
            result: $backupResult,
            lastSuccess: (if $backupLastSuccess == "" then null else $backupLastSuccess end),
            ageHours: $backupAgeHours,
            storage: {
              state: $storageBackupState,
              result: $storageBackupResult,
              lastSuccess: (if $storageBackupLastSuccess == "" then null else $storageBackupLastSuccess end),
              ageHours: $storageBackupAgeHours
            },
            restoreTest: {
              lastSuccess: (if $restoreTestLastSuccess == "" then null else $restoreTestLastSuccess end),
              ageHours: $restoreTestAgeHours
            }
          },
          kernel: {errors24h: $kernelErrors24h},
          disks: $disks
        }' \
        > "$tmp"
      install -m 0644 "$tmp" "$output"

      if ((root_used >= 90)); then
        logger --tag system-health --priority user.err "Root filesystem usage is ''${root_used}%"
      fi
      if [[ "$backup_result" == "failed" || "$backup_age_hours" == "null" ]]; then
        logger --tag system-health --priority user.err "The Nextcloud backup is missing or failed"
      elif ((backup_age_hours >= 36)); then
        logger --tag system-health --priority user.err "The latest Nextcloud backup is ''${backup_age_hours} hours old"
      fi
      if [[ "$storage_backup_result" == "failed" || "$storage_backup_age_hours" == "null" ]]; then
        logger --tag system-health --priority user.err "The Nextcloud storage backup is missing or failed"
      elif ((storage_backup_age_hours >= 36)); then
        logger --tag system-health --priority user.err "The latest Nextcloud storage backup is ''${storage_backup_age_hours} hours old"
      fi
    '';
  };
  systemHealth = pkgs.writeShellApplication {
    name = "system-health";
    runtimeInputs = [pkgs.jq];
    text = ''
      set -euo pipefail
      file=/var/lib/system-health/status.json
      if [[ ! -r "$file" ]]; then
        jq -n '{error: "health status has not been collected yet"}'
        exit 1
      fi
      jq . "$file"
    '';
  };
in {
  environment.systemPackages = with pkgs; [nvme-cli smartmontools systemHealth];

  services = {
    fwupd.enable = true;
    smartd = {
      enable = true;
      autodetect = true;
      # smartd 7.5 aborts while copying autodetected devices when a test
      # schedule is present. Keep health monitoring enabled without the
      # optional self-test schedule until the upstream regression is fixed.
      defaults.monitored = "-a -o on";
      notifications = {
        systembus-notify.enable = true;
        wall.enable = true;
      };
    };
  };

  systemd = {
    tmpfiles.rules = ["d /var/lib/system-health 0755 root root - -"];
    services.collect-system-health = {
      description = "Collect machine-readable disk, backup and system health";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe collectHealth;
      };
    };
    timers.collect-system-health = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitInactiveSec = "15min";
        Persistent = true;
        RandomizedDelaySec = "2min";
      };
    };
  };
}
