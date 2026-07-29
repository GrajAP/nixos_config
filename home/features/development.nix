{
  pkgs,
  config,
  lib,
  ...
}: let
  t3code = pkgs.callPackage ../../apps/t3code/package.nix {};
  nextcloudSyncGuard = pkgs.writeShellApplication {
    name = "nextcloud-sync-guard";
    runtimeInputs = with pkgs; [coreutils gawk sqlite];
    text = ''
      set -euo pipefail

      client_config="$HOME/.config/Nextcloud/nextcloud.cfg"
      if [[ ! -f "$client_config" ]]; then
        echo "Nextcloud is not configured yet; nothing to guard"
        exit 0
      fi

      folder_index() {
        local target="$1"
        awk -F= -v target="$target" '
          {
            split($1, key, /\\/)
            value = substr($0, index($0, "=") + 1)
            if (key[1] == "0" && key[2] == "Folders" && key[3] ~ /^[0-9]+$/ && key[4] == "targetPath" && value == target) {
              print key[3]
              exit
            }
          }
        ' "$client_config"
      }

      read_setting() {
        local folder_index="$1"
        local setting_name="$2"
        awk -F= -v folder_index="$folder_index" -v setting_name="$setting_name" '
          {
            split($1, key, /\\/)
          }
          (key[1] == "0" && key[2] == "Folders" && key[3] == folder_index && key[4] == setting_name) {
            print substr($0, index($0, "=") + 1)
            exit
          }
        ' "$client_config"
      }

      root_index="$(folder_index /)"
      storage_index="$(folder_index /Storage)"
      if [[ -z "$root_index" || -z "$storage_index" ]]; then
        echo "No overlapping Nextcloud Storage sync jobs found"
        exit 0
      fi

      storage_local="$(read_setting "$storage_index" localPath)"
      if [[ "$storage_local" != "/mnt/Storage/" ]]; then
        echo "Remote /Storage is not synced from /mnt/Storage; nothing to guard"
        exit 0
      fi

      root_local="$(read_setting "$root_index" localPath)"
      root_journal="$(read_setting "$root_index" journalPath)"
      case "$root_local" in
        /*/) ;;
        *)
          echo "Invalid Nextcloud root sync path: $root_local" >&2
          exit 1
          ;;
      esac
      case "$root_journal" in
        .sync_*.db) ;;
        *)
          echo "Invalid Nextcloud root sync journal: $root_journal" >&2
          exit 1
          ;;
      esac

      storage_paused="$(read_setting "$storage_index" paused)"
      if [[ "$storage_paused" != "true" ]]; then
        backup="$client_config.pre-storage-loop-fix"
        if [[ ! -e "$backup" ]]; then
          cp --preserve=mode,timestamps "$client_config" "$backup"
        fi

        config_dir="$(dirname "$client_config")"
        tmp="$(mktemp --tmpdir="$config_dir" nextcloud.cfg.XXXXXX)"
        trap 'rm -f "$tmp"' EXIT
        awk -F= -v folder_index="$storage_index" '
          {
            split($1, key, /\\/)
          }
          (key[1] == "0" && key[2] == "Folders" && key[3] == folder_index && key[4] == "paused") {
            print $1 "=true"
            found = 1
            next
          }
          { print }
          END {
            if (!found) {
              exit 1
            }
          }
        ' "$client_config" > "$tmp"
        chmod --reference="$client_config" "$tmp"
        mv "$tmp" "$client_config"
        trap - EXIT
        echo "Paused the self-referential /mnt/Storage Nextcloud sync"
      fi

      root_db="$root_local$root_journal"
      if [[ ! -f "$root_db" ]]; then
        echo "Cannot exclude /Storage because the Nextcloud root sync journal is missing: $root_db" >&2
        exit 1
      fi

      sqlite3 "$root_db" <<'SQL'
      PRAGMA busy_timeout = 5000;
      BEGIN IMMEDIATE;
      INSERT INTO selectivesync (path, type)
      SELECT 'Storage/', 1
      WHERE NOT EXISTS (
        SELECT 1
        FROM selectivesync
        WHERE type = 1
          AND trim(path, '/') = 'Storage'
      );
      COMMIT;
      SQL

      echo "Ensured /Storage is excluded from the Nextcloud root sync"
    '';
  };
in {
  xdg.configFile."systemd/user/app-Nextcloud@autostart.service.d/10-storage-loop-guard.conf".text = ''
    [Unit]
    Requires=nextcloud-sync-guard.service
    After=nextcloud-sync-guard.service
  '';

  home = {
    packages = with pkgs; [
      electron
      postman
      antigravity
      github-desktop
      libreoffice-fresh
      nextcloud-client
      rnote
      pnpm
      bun
      t3code.desktop
      t3code.notify
      (pkgs.writeShellApplication {
        name = "install-js-clis";
        runtimeInputs = [pkgs.bun];
        text = ''
          set -euo pipefail

          mkdir -p "$HOME/.bun-global"
          bun install -g --prefix "$HOME/.bun-global" \
            @angular/cli \
            @expo/cli \
            vite \
            @react-native-community/cli \
            concurrently
        '';
      })
    ];

    sessionVariables.PATH = "${config.home.homeDirectory}/.bun-global/bin:$PATH";

    sessionPath = ["${config.home.homeDirectory}/.bun-global/bin"];
  };

  systemd.user = {
    services.nextcloud-sync-guard = {
      Unit.Description = "Prevent self-referential Nextcloud Storage syncs";
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe nextcloudSyncGuard;
      };
    };
    services.t3code-update = {
      Unit.Description = "Download the newest T3 Code desktop release";
      Service = {
        Type = "oneshot";
        ExecStart = "${t3code.update}/bin/t3code-update";
      };
    };
    timers.t3code-update = {
      Unit.Description = "Keep T3 Code desktop current";
      Timer = {
        OnStartupSec = "2min";
        OnUnitActiveSec = "30min";
        Persistent = true;
      };
      Install.WantedBy = ["timers.target"];
    };
  };
}
