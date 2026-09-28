{
  lib,
  pkgs,
  unstablePkgs,
  ...
}: let
  nextcloudHost = "lenovo.tail138448.ts.net";
  backendPort = 18080;
  nextcloudPackage = unstablePkgs.nextcloud34;
  nextcloudApps = unstablePkgs.nextcloud34Packages.apps;
in {
  # ===========================================================================
  # CALENDAR, TASKS AND NOTES
  #
  # Moved off grajpap, where it shared a machine with a desktop that is
  # expected to sleep. The phone could only sync while that machine was awake.
  # This instance exists so the tailnet always has somewhere to sync to.
  #
  # SCOPE: calendar, tasks and notes only. No file sync.
  #
  # The 214 GiB external mount at grajpap:/mnt/Storage stays where it is and is
  # not part of this move. Nothing here stores user files, so the datadir is a
  # few MB of DAV data rather than tens of GB.
  #
  # ---------------------------------------------------------------------------
  # SQLite vs postgres
  #
  # Measured on grajpap: postgres is ~270 MiB RSS across two backends, out of
  # ~6.2 GiB free here. Saving it was not worth losing notify_push (which
  # requires redis) or the pg_dump path the old config already used. Postgres
  # and redis it is, matching what is being replaced.
  #
  # ---------------------------------------------------------------------------
  # URL LAYOUT
  #
  # `tailscale serve` already owns https://lenovo.tail138448.ts.net/ for the
  # whole hostname and forwards it to Caddy, which proxies `/` to HomeNest on
  # :3001. Nextcloud therefore cannot have the root path without breaking
  # HomeNest, so it lives under a /nextcloud prefix.
  #
  # Caddy's `handle_path` strips the prefix before proxying, so the backend
  # serves Nextcloud from `/` while `overwritewebroot` makes Nextcloud emit
  # `/nextcloud/...` in every URL it hands to clients.
  # ---------------------------------------------------------------------------
  services = {
    nextcloud = {
      enable = true;
      package = nextcloudPackage;
      hostName = nextcloudHost;
      https = true;

      # Sets client_max_body_size. Declaring it in the vhost extraConfig instead
      # is a duplicate-directive emerg, because the module emits its own.
      maxUploadSize = "512M";

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
        overwritehost = nextcloudHost;
        overwriteprotocol = "https";
        overwritewebroot = "/nextcloud";
        "overwrite.cli.url" = "https://${nextcloudHost}/nextcloud";
        trusted_domains = [
          "127.0.0.1"
          "localhost"
          nextcloudHost
        ];
        trusted_proxies = [
          "127.0.0.1"
          "::1"
        ];
      };

      appstoreEnable = false;

      # Only what was migrated. `contacts` stays off until it is actually wanted.
      extraApps = {
        inherit
          (nextcloudApps)
          calendar
          tasks
          notes
          ;
      };

      notify_push = {
        enable = true;
        nextcloudUrl = "https://${nextcloudHost}/nextcloud";

        # 25.11 stable ships 1.3.0, whose config parser aborts with
        # "invalid database configuration: no data directory" on a perfectly valid
        # config.php. 1.4.1 (unstable) parses it. The Nextcloud module itself is
        # still stable; only this daemon moves channel.
        package = unstablePkgs.nextcloud-notify_push;
      };
    };

    # Nextcloud is served by its own nginx on loopback. Caddy stays the single
    # public entrypoint on :80 and nothing else has to bind a second webserver.
    nginx.virtualHosts.${nextcloudHost} = {
      listen = [
        {
          addr = "127.0.0.1";
          port = backendPort;
          ssl = false;
        }
      ];
      # No extraConfig here on purpose. The module already emits
      # client_max_body_size and fastcgi_buffers, so restating either is an
      # nginx [emerg] "directive is duplicate" and the unit never starts.
    };

    # ---------------------------------------------------------------------------
    # Caddy: publish Nextcloud under /nextcloud, leave HomeNest on /
    #
    # A site block keyed on the exact hostname outranks the `http://` catch-all
    # that already exists in modules/network.nix, so HomeNest is untouched.
    # ---------------------------------------------------------------------------
    caddy.virtualHosts."http://${nextcloudHost}".extraConfig = ''
      handle_path /nextcloud* {
        reverse_proxy 127.0.0.1:${toString backendPort}
      }

      handle {
        reverse_proxy localhost:3001
      }
    '';
  };

  systemd = {
    services = {
      # The generated admin password is local to this machine; it is not carried
      # over from grajpap, where the same file held a different value.
      nextcloud-admin-pass = {
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

      # notify_push talks to the loopback nginx, not to the public URL, so a DNS
      # or TLS problem cannot wedge it into a retry loop.
      nextcloud-notify_push = {
        environment.NEXTCLOUD_URL = lib.mkForce "http://127.0.0.1:${toString backendPort}";
        wantedBy = lib.mkForce [];
      };
      nextcloud-notify_push_setup = {
        environment.NEXTCLOUD_URL = "http://127.0.0.1:${toString backendPort}";
        requiredBy = lib.mkForce [];
        wantedBy = lib.mkForce [];
      };
    };

    timers = {
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
    };
  };
}
