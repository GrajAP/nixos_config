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
      backup_state="$(systemctl show restic-backups-nextcloud.service --property=ActiveState --value 2>/dev/null || echo unknown)"
      backup_result="$(systemctl show restic-backups-nextcloud.service --property=Result --value 2>/dev/null || echo unknown)"

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
        --argjson disks "$disks" \
        '{generatedAt: $generatedAt, root: {usedPercent: $rootUsedPercent}, backup: {state: $backupState, result: $backupResult}, kernel: {errors24h: $kernelErrors24h}, disks: $disks}' \
        > "$tmp"
      install -m 0644 "$tmp" "$output"

      if ((root_used >= 90)); then
        logger --tag system-health --priority user.err "Root filesystem usage is ''${root_used}%"
      fi
      if [[ "$backup_result" == "failed" ]]; then
        logger --tag system-health --priority user.err "The latest Nextcloud backup failed"
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
