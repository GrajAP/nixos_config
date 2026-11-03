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

      root_used="$(df -P / | awk 'NR == 2 { gsub(/%/, "", $5); print $5 }')"
      kernel_errors="$(journalctl --dmesg --priority=err --since='24 hours ago' --output=json 2>/dev/null | jq -s 'length')"
      backup_state="$(systemctl show restic-backups-storage.service --property=ActiveState --value 2>/dev/null || echo unknown)"
      backup_result="$(systemctl show restic-backups-storage.service --property=Result --value 2>/dev/null || echo unknown)"
      backup_exit_status="$(systemctl show restic-backups-storage.service --property=ExecMainStatus --value 2>/dev/null || echo 0)"
      [[ "$backup_exit_status" =~ ^[0-9]+$ ]] || backup_exit_status=0
      backup_stamp=/var/lib/restic-nextcloud/storage-backup.last-success
      backup_last_success=""
      backup_age_hours=null
      if [[ -s "$backup_stamp" ]]; then
        backup_last_success="$(head -n1 "$backup_stamp")"
        backup_epoch="$(date --date="$backup_last_success" +%s 2>/dev/null || true)"
        if [[ "$backup_epoch" =~ ^[0-9]+$ ]]; then
          backup_age_hours="$(( ($(date +%s) - backup_epoch) / 3600 ))"
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
        --argjson backupExitStatus "$backup_exit_status" \
        --arg backupLastSuccess "$backup_last_success" \
        --argjson backupAgeHours "$backup_age_hours" \
        --argjson disks "$disks" \
        '{
          generatedAt: $generatedAt,
          root: {usedPercent: $rootUsedPercent},
          backup: {
            state: $backupState,
            result: $backupResult,
            exitStatus: $backupExitStatus,
            lastSuccess: (if $backupLastSuccess == "" then null else $backupLastSuccess end),
            ageHours: $backupAgeHours
          },
          kernel: {errors24h: $kernelErrors24h},
          disks: $disks
        }' \
        > "$tmp"
      install -m 0644 "$tmp" "$output"

      if ((root_used >= 90)); then
        logger --tag system-health --priority user.err "Root filesystem usage is ''${root_used}%"
      fi
      # A rebuild can reset Result to success after a failed run, ExecMainStatus
      # keeps the real exit code.
      if [[ "$backup_result" == "failed" || "$backup_exit_status" != "0" || "$backup_age_hours" == "null" ]]; then
        logger --tag system-health --priority user.err "The /mnt/Storage backup is missing or failed"
      elif ((backup_age_hours >= 36)); then
        logger --tag system-health --priority user.err "The latest /mnt/Storage backup is ''${backup_age_hours} hours old"
      fi
    '';
  };
  backupHealthNotify = pkgs.writeShellApplication {
    name = "backup-health-notify";
    runtimeInputs = with pkgs; [jq libnotify];
    text = ''
      set -euo pipefail

      status=/var/lib/system-health/status.json
      [[ -r "$status" ]] || exit 0

      message="$(jq -r '
        .backup
        | if .ageHours == null then "No successful /mnt/Storage backup is recorded."
          elif .exitStatus != 0 then "The last /mnt/Storage backup failed. The last good one is \(.ageHours) hours old. See: journalctl -u restic-backups-storage"
          elif .ageHours >= 36 then "The latest /mnt/Storage backup is \(.ageHours) hours old."
          else empty
          end
      ' "$status")"
      [[ -n "$message" ]] || exit 0

      notify-send --app-name="Backup" --icon=dialog-warning -u critical "Backup problem" "$message"
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
    user = {
      services.backup-health-notify = {
        description = "Warn on the desktop when the /mnt/Storage backup is failing";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe backupHealthNotify;
        };
      };
      timers.backup-health-notify = {
        wantedBy = ["graphical-session.target"];
        partOf = ["graphical-session.target"];
        timerConfig = {
          OnActiveSec = "10min";
          OnUnitActiveSec = "6h";
        };
      };
    };
  };
}
