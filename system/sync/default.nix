{
  config,
  lib,
  pkgs,
  ...
}: let
  nextcloudHost = "grajpap.tail138448.ts.net";
  nextcloudBackendPort = 18080;
  nextcloudPackage = pkgs.nextcloud33;
  nextcloudApps = pkgs.nextcloud33Packages.apps;
  tailnetInterface = config.services.tailscale.interfaceName;
in {
  environment.systemPackages = with pkgs; [
    kdePackages.kdeconnect-kde
  ];

  networking.firewall.interfaces.${tailnetInterface} = {
    allowedTCPPorts = [443];
    allowedTCPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ];
    allowedUDPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ];
  };

  services = {
    tailscale = {
      openFirewall = true;
      # Tailscale SSH is the recovery path before an OpenSSH authorized key is installed.
      extraSetFlags = ["--ssh"];
    };

    nextcloud = {
      enable = true;
      package = nextcloudPackage;
      hostName = nextcloudHost;
      https = true;
      maxUploadSize = "2G";

      database.createLocally = true;
      configureRedis = true;

      config = {
        dbtype = "pgsql";
        adminuser = "grajpap";
        adminpassFile = "/var/lib/nextcloud/secrets/admin-pass";
      };

      settings = {
        default_phone_region = "PL";
        log_type = "systemd";
        maintenance_window_start = 2;
        "overwrite.cli.url" = "https://${nextcloudHost}";
        overwritehost = nextcloudHost;
        overwriteprotocol = "https";
        trusted_domains = [
          "127.0.0.1"
          "localhost"
        ];
        trusted_proxies = [
          "127.0.0.1"
          "::1"
        ];
      };

      appstoreEnable = false;
      extraApps = {
        inherit
          (nextcloudApps)
          calendar
          contacts
          notes
          tasks
          ;
      };

      notify_push = {
        enable = true;
        nextcloudUrl = "https://${nextcloudHost}";
      };
    };

    nginx.virtualHosts.${nextcloudHost}.listen = [
      {
        addr = "127.0.0.1";
        port = nextcloudBackendPort;
        ssl = false;
      }
    ];
  };

  systemd.services = {
    nextcloud-admin-pass = {
      description = "Create the initial Nextcloud admin password";
      before = ["nextcloud-setup.service"];
      requiredBy = ["nextcloud-setup.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "2min";
      };
      path = with pkgs; [
        coreutils
        openssl
      ];
      script = ''
        install -d -m 0750 -o nextcloud -g nextcloud /var/lib/nextcloud/secrets

        if [ ! -s /var/lib/nextcloud/secrets/admin-pass ]; then
          umask 077
          openssl rand -base64 32 > /var/lib/nextcloud/secrets/admin-pass
        fi

        chown nextcloud:nextcloud /var/lib/nextcloud/secrets/admin-pass
        chmod 0400 /var/lib/nextcloud/secrets/admin-pass
      '';
    };

    nextcloud-notify_push = {
      environment.NEXTCLOUD_URL = lib.mkForce "http://127.0.0.1:${toString nextcloudBackendPort}";
      wantedBy = lib.mkForce [];
    };
    nextcloud-setup.serviceConfig.RemainAfterExit = true;

    nextcloud-notify_push_setup = {
      after = [
        "nginx.service"
        "tailscale-serve-nextcloud.service"
      ];
      wants = [
        "nginx.service"
        "tailscale-serve-nextcloud.service"
      ];
      environment.NEXTCLOUD_URL = "http://127.0.0.1:${toString nextcloudBackendPort}";
      requiredBy = lib.mkForce [];
      wantedBy = lib.mkForce [];
    };

    nextcloud-quickshell-token = {
      description = "Create the Nextcloud app password used by the desktop calendar widget";
      after = ["nextcloud-setup.service"];
      wantedBy = [];
      path = [
        config.services.nextcloud.occ
        pkgs.coreutils
        pkgs.jq
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "2min";
      };
      script = ''
        token_file=/home/grajpap/.config/quickshell/nextcloud-app-password
        token_dir="$(dirname "$token_file")"

        install -d -m 0700 -o grajpap -g users "$token_dir"

        if [ ! -s "$token_file" ]; then
          umask 077
          tmp="$(mktemp)"
          nextcloud-occ user:auth-tokens:add --no-interaction --name quickshell-calendar grajpap > "$tmp"
          tail -n 1 "$tmp" > "$token_file"
          rm -f "$tmp"
        fi

        chown grajpap:users "$token_file"
        chmod 0600 "$token_file"
      '';
    };

    nextcloud-quickshell-token-rotate = {
      description = "Rotate the Nextcloud app password used by Quickshell";
      after = ["nextcloud-setup.service"];
      path = [config.services.nextcloud.occ pkgs.coreutils pkgs.jq];
      serviceConfig.Type = "oneshot";
      script = ''
        set -euo pipefail

        token_file=/home/grajpap/.config/quickshell/nextcloud-app-password
        token_dir="$(dirname "$token_file")"
        old_ids="$(nextcloud-occ user:auth-tokens:list grajpap --output=json | jq -r '.[] | select(.name == "quickshell-calendar") | .id')"
        tmp="$(mktemp)"
        trap 'rm -f "$tmp"' EXIT

        nextcloud-occ user:auth-tokens:add --no-interaction --name quickshell-calendar grajpap > "$tmp"
        install -d -m 0700 -o grajpap -g users "$token_dir"
        tail -n 1 "$tmp" | install -m 0600 -o grajpap -g users /dev/stdin "$token_file"

        for token_id in $old_ids; do
          nextcloud-occ user:auth-tokens:delete --no-interaction grajpap "$token_id"
        done
      '';
    };

    nextcloud-storage-mounts = {
      description = "Configure local external storage mounts for Nextcloud";
      after = [
        "nextcloud-setup.service"
        "mnt-Storage.automount"
      ];
      wants = ["mnt-Storage.automount"];
      wantedBy = [];
      path = [
        config.services.nextcloud.occ
        pkgs.coreutils
        pkgs.jq
        pkgs.util-linux
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "2min";
      };
      script = ''
        if ! nextcloud-occ app:list --output=json | jq -e '.enabled.files_external' >/dev/null; then
          nextcloud-occ app:enable files_external
        fi

        # Trigger the automount before asking Nextcloud to verify the local backend.
        ls /mnt/Storage >/dev/null

        if ! mountpoint -q /mnt/Storage; then
          echo "/mnt/Storage is not mounted"
          exit 1
        fi

        if ! test -w /mnt/Storage; then
          echo "nextcloud cannot write to /mnt/Storage"
          exit 1
        fi

        mount_id="$(
          nextcloud-occ files_external:list --output=json \
            | jq -r '.[] | select(.mount_point == "Storage" or .mount_point == "/Storage") | .mount_id' \
            | head -n 1
        )"

        if [ -z "$mount_id" ]; then
          nextcloud-occ files_external:create Storage local null::null -c datadir=/mnt/Storage
          mount_id="$(
            nextcloud-occ files_external:list --output=json \
              | jq -r '.[] | select(.mount_point == "Storage" or .mount_point == "/Storage") | .mount_id' \
              | head -n 1
          )"
        else
          nextcloud-occ files_external:config "$mount_id" datadir /mnt/Storage
        fi

        nextcloud-occ files_external:applicable "$mount_id" --add-user grajpap
        nextcloud-occ files_external:verify "$mount_id"
      '';
    };

    tailscale-serve-nextcloud = {
      description = "Expose Nextcloud through Tailscale Serve";
      after = [
        "nginx.service"
        "tailscaled.service"
      ];
      wants = [
        "nginx.service"
        "tailscaled.service"
      ];
      wantedBy = [];
      path = [config.services.tailscale.package];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "2min";
      };
      # This command owns only the default HTTPS handler. It intentionally does
      # not reset other Tailscale Serve handlers, including the project on 8443.
      script = "tailscale serve --bg --yes http://127.0.0.1:${toString nextcloudBackendPort}";
    };
  };

  systemd.timers = {
    nextcloud-notify_push = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "30s";
        Unit = "nextcloud-notify_push.service";
      };
    };

    nextcloud-notify_push_setup = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "45s";
        Unit = "nextcloud-notify_push_setup.service";
      };
    };

    nextcloud-quickshell-token = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "60s";
        Unit = "nextcloud-quickshell-token.service";
      };
    };

    nextcloud-storage-mounts = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "75s";
        Unit = "nextcloud-storage-mounts.service";
      };
    };

    nextcloud-quickshell-token-rotate = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "monthly";
        Persistent = true;
        RandomizedDelaySec = "6h";
      };
    };

    tailscale-serve-nextcloud = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "20s";
        Unit = "tailscale-serve-nextcloud.service";
      };
    };
  };
}
